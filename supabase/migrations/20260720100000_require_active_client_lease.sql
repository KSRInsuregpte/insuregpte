-- Activate strict active-client lease enforcement after the updated frontend
-- from stage 1 has been deployed. Authenticated Data API requests without the
-- x-insuregpte-client-id header are rejected from this point onward.
--
-- Prerequisite:
-- supabase/migrations/20260720090000_add_active_client_lease.sql
--
-- Rollback:
-- supabase/rollbacks/20260720100000_require_active_client_lease.sql

DO $guard$
DECLARE
    v_guard_description text;
BEGIN
    IF to_regclass('public.active_client_leases') IS NULL
       OR to_regprocedure(
           'public.claim_active_client(uuid,boolean)'
       ) IS NULL THEN
        RAISE EXCEPTION
            'Stage 1 active-client lease objects are missing';
    END IF;

    SELECT pg_catalog.obj_description(
        to_regprocedure('public.fn_enforce_active_auth_session()'),
        'pg_proc'
    )
    INTO v_guard_description;

    IF v_guard_description IS NULL
       OR v_guard_description NOT IN (
           'Stage-1 compatibility guard: enforces active-client leases for updated pages and newest Auth session for pages not yet sending a client header.',
           'Rejects authenticated Data API requests unless the JWT session and x-insuregpte-client-id own the current unexpired active-client lease.'
       ) THEN
        RAISE EXCEPTION
            'The expected stage-1 pre-request guard is not active';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_roles AS role_record
        CROSS JOIN LATERAL unnest(
            COALESCE(role_record.rolconfig, ARRAY[]::text[])
        ) AS config(setting)
        WHERE role_record.rolname = 'authenticator'
          AND config.setting =
              'pgrst.db_pre_request=public.fn_enforce_active_auth_session'
    ) THEN
        RAISE EXCEPTION
            'The stage-1 PostgREST pre-request setting is missing';
    END IF;
END;
$guard$;

CREATE OR REPLACE FUNCTION public.fn_enforce_active_auth_session()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_claims jsonb;
    v_headers jsonb;
    v_user_id uuid;
    v_session_id uuid;
    v_client_id uuid;
    v_request_method text;
    v_request_path text;
BEGIN
    BEGIN
        v_claims := COALESCE(
            NULLIF(current_setting('request.jwt.claims', true), ''),
            '{}'
        )::jsonb;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE SQLSTATE 'PT401'
                USING MESSAGE =
                    'This session is no longer active. Please sign in again.';
    END;

    IF COALESCE(v_claims ->> 'role', '') <> 'authenticated' THEN
        RETURN;
    END IF;

    v_request_method := upper(
        COALESCE(current_setting('request.method', true), '')
    );
    v_request_path := ltrim(
        COALESCE(current_setting('request.path', true), ''),
        '/'
    );

    -- The claim RPC performs its own strict session and client-header checks.
    -- It must remain reachable before a lease exists.
    IF v_request_method = 'POST'
       AND v_request_path = 'rpc/claim_active_client' THEN
        RETURN;
    END IF;

    v_user_id := auth.uid();

    BEGIN
        v_session_id := NULLIF(v_claims ->> 'session_id', '')::uuid;
        v_headers := COALESCE(
            NULLIF(current_setting('request.headers', true), ''),
            '{}'
        )::jsonb;
        v_client_id := NULLIF(
            v_headers ->> 'x-insuregpte-client-id',
            ''
        )::uuid;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE SQLSTATE 'PT401'
                USING MESSAGE =
                    'This session is no longer active. Please sign in again.';
    END;

    IF v_user_id IS NULL
       OR v_session_id IS NULL
       OR v_client_id IS NULL THEN
        RAISE SQLSTATE 'PT401'
            USING MESSAGE =
                'This page is no longer the active login.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.active_client_leases AS lease_record
        JOIN auth.sessions AS session_record
          ON session_record.id = lease_record.session_id
         AND session_record.user_id = lease_record.user_id
        WHERE lease_record.user_id = v_user_id
          AND lease_record.session_id = v_session_id
          AND lease_record.client_id = v_client_id
          AND lease_record.expires_at > clock_timestamp()
          AND (
              session_record.not_after IS NULL
              OR session_record.not_after > clock_timestamp()
          )
    ) THEN
        RAISE SQLSTATE 'PT401'
            USING MESSAGE =
                'This page is no longer the active login.';
    END IF;
END;
$function$;

COMMENT ON FUNCTION public.fn_enforce_active_auth_session() IS
    'Rejects authenticated Data API requests unless the JWT session and x-insuregpte-client-id own the current unexpired active-client lease.';

REVOKE ALL ON FUNCTION public.fn_enforce_active_auth_session()
FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.fn_enforce_active_auth_session()
TO anon, authenticated, service_role, authenticator;

ALTER ROLE authenticator
SET pgrst.db_pre_request = 'public.fn_enforce_active_auth_session';

NOTIFY pgrst, 'reload config';
NOTIFY pgrst, 'reload schema';
