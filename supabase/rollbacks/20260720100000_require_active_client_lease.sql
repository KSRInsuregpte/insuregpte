-- Return to the stage-1 compatibility guard. The lease table and RPCs remain.

DO $guard$
DECLARE
    v_conflicting_setting text;
BEGIN
    SELECT config.setting
    INTO v_conflicting_setting
    FROM pg_catalog.pg_roles AS role_record
    CROSS JOIN LATERAL unnest(
        COALESCE(role_record.rolconfig, ARRAY[]::text[])
    ) AS config(setting)
    WHERE role_record.rolname = 'authenticator'
      AND config.setting LIKE 'pgrst.db_pre_request=%'
      AND config.setting NOT IN (
          'pgrst.db_pre_request=',
          'pgrst.db_pre_request=public.fn_enforce_active_auth_session'
      )
    LIMIT 1;

    IF v_conflicting_setting IS NOT NULL THEN
        RAISE EXCEPTION
            'Rollback refused because another pre-request function is configured: %',
            v_conflicting_setting;
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
    v_authoritative_session_id uuid;
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

    IF v_user_id IS NULL OR v_session_id IS NULL THEN
        RAISE SQLSTATE 'PT401'
            USING MESSAGE =
                'This session is no longer active. Please sign in again.';
    END IF;

    IF v_client_id IS NOT NULL THEN
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

        RETURN;
    END IF;

    SELECT session_record.id
    INTO v_authoritative_session_id
    FROM auth.sessions AS session_record
    WHERE session_record.user_id = v_user_id
      AND (
          session_record.not_after IS NULL
          OR session_record.not_after > clock_timestamp()
      )
    ORDER BY
        session_record.created_at DESC NULLS LAST,
        session_record.id DESC
    LIMIT 1;

    IF v_authoritative_session_id IS NULL
       OR v_authoritative_session_id IS DISTINCT FROM v_session_id THEN
        RAISE SQLSTATE 'PT401'
            USING MESSAGE =
                'This session is no longer active. Please sign in again.';
    END IF;
END;
$function$;

COMMENT ON FUNCTION public.fn_enforce_active_auth_session() IS
    'Stage-1 compatibility guard: enforces active-client leases for updated pages and newest Auth session for pages not yet sending a client header.';

REVOKE ALL ON FUNCTION public.fn_enforce_active_auth_session()
FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.fn_enforce_active_auth_session()
TO anon, authenticated, service_role, authenticator;

ALTER ROLE authenticator
SET pgrst.db_pre_request = 'public.fn_enforce_active_auth_session';

NOTIFY pgrst, 'reload config';
NOTIFY pgrst, 'reload schema';
