-- Add a short-lived active-client lease without interrupting the currently
-- deployed frontend. This is stage 1 of the approved first-active-page policy.
--
-- During this deployment stage:
--   * updated pages send x-insuregpte-client-id and are checked by the lease;
--   * older cached/deployed pages without that header retain the existing
--     newest-auth-session behavior until stage 2 is applied.
--
-- Apply stage 2 immediately after the updated frontend is deployed:
-- supabase/migrations/20260720100000_require_active_client_lease.sql
--
-- Rollback:
-- supabase/rollbacks/20260720090000_add_active_client_lease.sql

DO $guard$
DECLARE
    v_conflicting_setting text;
    v_existing_description text;
BEGIN
    SELECT role_setting.setting
    INTO v_conflicting_setting
    FROM (
        SELECT config.setting
        FROM pg_catalog.pg_roles AS role_record
        CROSS JOIN LATERAL unnest(
            COALESCE(role_record.rolconfig, ARRAY[]::text[])
        ) AS config(setting)
        WHERE role_record.rolname = 'authenticator'

        UNION

        SELECT config.setting
        FROM pg_catalog.pg_db_role_setting AS database_role_setting
        JOIN pg_catalog.pg_roles AS role_record
          ON role_record.oid = database_role_setting.setrole
        CROSS JOIN LATERAL unnest(
            COALESCE(database_role_setting.setconfig, ARRAY[]::text[])
        ) AS config(setting)
        WHERE role_record.rolname = 'authenticator'
          AND database_role_setting.setdatabase IN (
              0,
              (
                  SELECT database_record.oid
                  FROM pg_catalog.pg_database AS database_record
                  WHERE database_record.datname = current_database()
              )
          )
    ) AS role_setting
    WHERE role_setting.setting LIKE 'pgrst.db_pre_request=%'
      AND role_setting.setting NOT IN (
          'pgrst.db_pre_request=',
          'pgrst.db_pre_request=public.fn_enforce_active_auth_session'
      )
    LIMIT 1;

    IF v_conflicting_setting IS NOT NULL THEN
        RAISE EXCEPTION
            'A different PostgREST pre-request function is configured: %',
            v_conflicting_setting;
    END IF;

    IF to_regprocedure(
        'public.fn_enforce_active_auth_session()'
    ) IS NOT NULL THEN
        SELECT pg_catalog.obj_description(
            to_regprocedure(
                'public.fn_enforce_active_auth_session()'
            ),
            'pg_proc'
        )
        INTO v_existing_description;

        IF v_existing_description =
            'Rejects authenticated Data API requests unless the JWT session and x-insuregpte-client-id own the current unexpired active-client lease.' THEN
            RAISE EXCEPTION
                'Strict stage 2 is already active; do not rerun stage 1';
        END IF;

        IF v_existing_description IS NULL
           OR v_existing_description NOT IN (
               'Rejects authenticated PostgREST requests unless the JWT session_id is the user''s newest active auth.sessions row.',
               'Stage-1 compatibility guard: enforces active-client leases for updated pages and newest Auth session for pages not yet sending a client header.'
           ) THEN
            RAISE EXCEPTION
                'An unrecognized fn_enforce_active_auth_session() already exists';
        END IF;
    END IF;

    IF to_regclass('public.active_client_leases') IS NOT NULL THEN
        SELECT pg_catalog.obj_description(
            to_regclass('public.active_client_leases'),
            'pg_class'
        )
        INTO v_existing_description;

        IF v_existing_description IS DISTINCT FROM
            'Short-lived control lease for the one-active-browser-page policy; Supabase Auth remains the identity and authentication authority.' THEN
            RAISE EXCEPTION
                'An unrecognized public.active_client_leases object already exists';
        END IF;
    END IF;

    IF to_regprocedure(
        'public.claim_active_client(uuid,boolean)'
    ) IS NOT NULL THEN
        SELECT pg_catalog.obj_description(
            to_regprocedure(
                'public.claim_active_client(uuid,boolean)'
            ),
            'pg_proc'
        )
        INTO v_existing_description;

        IF v_existing_description IS DISTINCT FROM
            'Claims or explicitly transfers the short-lived active-client lease for the authenticated user.' THEN
            RAISE EXCEPTION
                'An unrecognized claim_active_client(uuid, boolean) already exists';
        END IF;
    END IF;

    IF to_regprocedure(
        'public.heartbeat_active_client(uuid)'
    ) IS NOT NULL THEN
        SELECT pg_catalog.obj_description(
            to_regprocedure('public.heartbeat_active_client(uuid)'),
            'pg_proc'
        )
        INTO v_existing_description;

        IF v_existing_description IS DISTINCT FROM
            'Renews the active-client lease only for its owning authenticated session and client.' THEN
            RAISE EXCEPTION
                'An unrecognized heartbeat_active_client(uuid) already exists';
        END IF;
    END IF;

    IF to_regprocedure(
        'public.release_active_client(uuid)'
    ) IS NOT NULL THEN
        SELECT pg_catalog.obj_description(
            to_regprocedure('public.release_active_client(uuid)'),
            'pg_proc'
        )
        INTO v_existing_description;

        IF v_existing_description IS DISTINCT FROM
            'Releases the active-client lease only when called by its owning authenticated session and client.' THEN
            RAISE EXCEPTION
                'An unrecognized release_active_client(uuid) already exists';
        END IF;
    END IF;
END;
$guard$;

CREATE TABLE IF NOT EXISTS public.active_client_leases (
    user_id uuid NOT NULL,
    session_id uuid NOT NULL,
    client_id uuid NOT NULL,
    claimed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    last_seen_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    expires_at timestamptz NOT NULL,
    CONSTRAINT active_client_leases_pkey PRIMARY KEY (user_id),
    CONSTRAINT active_client_leases_user_id_fkey
        FOREIGN KEY (user_id)
        REFERENCES auth.users (id)
        ON DELETE CASCADE,
    CONSTRAINT active_client_leases_expiry_check
        CHECK (expires_at > claimed_at)
);

COMMENT ON TABLE public.active_client_leases IS
    'Short-lived control lease for the one-active-browser-page policy; Supabase Auth remains the identity and authentication authority.';

COMMENT ON COLUMN public.active_client_leases.client_id IS
    'Random non-secret browser-page client identifier supplied in x-insuregpte-client-id.';

ALTER TABLE public.active_client_leases ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.active_client_leases
FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.claim_active_client(
    p_client_id uuid,
    p_takeover boolean DEFAULT false
)
RETURNS TABLE (
    claim_status text,
    conflict boolean,
    lease_expires_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_claims jsonb;
    v_headers jsonb;
    v_user_id uuid;
    v_session_id uuid;
    v_header_client_id uuid;
    v_now timestamptz := clock_timestamp();
    v_new_expiry timestamptz;
    v_lease public.active_client_leases%ROWTYPE;
    v_has_live_lease boolean := false;
BEGIN
    BEGIN
        v_claims := COALESCE(
            NULLIF(current_setting('request.jwt.claims', true), ''),
            '{}'
        )::jsonb;
        v_headers := COALESCE(
            NULLIF(current_setting('request.headers', true), ''),
            '{}'
        )::jsonb;
        v_user_id := auth.uid();
        v_session_id := NULLIF(v_claims ->> 'session_id', '')::uuid;
        v_header_client_id := NULLIF(
            v_headers ->> 'x-insuregpte-client-id',
            ''
        )::uuid;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE SQLSTATE 'PT401'
                USING MESSAGE =
                    'This login cannot be activated. Please sign in again.';
    END;

    IF COALESCE(v_claims ->> 'role', '') <> 'authenticated'
       OR v_user_id IS NULL
       OR v_session_id IS NULL
       OR p_client_id IS NULL
       OR v_header_client_id IS DISTINCT FROM p_client_id THEN
        RAISE SQLSTATE 'PT401'
            USING MESSAGE =
                'This login cannot be activated. Please sign in again.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM auth.sessions AS session_record
        WHERE session_record.id = v_session_id
          AND session_record.user_id = v_user_id
          AND (
              session_record.not_after IS NULL
              OR session_record.not_after > v_now
          )
    ) THEN
        RAISE SQLSTATE 'PT401'
            USING MESSAGE =
                'This login cannot be activated. Please sign in again.';
    END IF;

    -- Serialize claims for the same account so two simultaneous logins cannot
    -- both observe an available lease.
    PERFORM pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(v_user_id::text, 0)
    );

    SELECT lease_record.*
    INTO v_lease
    FROM public.active_client_leases AS lease_record
    WHERE lease_record.user_id = v_user_id
    FOR UPDATE;

    IF FOUND THEN
        v_has_live_lease := v_lease.expires_at > v_now
            AND EXISTS (
                SELECT 1
                FROM auth.sessions AS session_record
                WHERE session_record.id = v_lease.session_id
                  AND session_record.user_id = v_user_id
                  AND (
                      session_record.not_after IS NULL
                      OR session_record.not_after > v_now
                  )
            );
    END IF;

    v_new_expiry := v_now + interval '90 seconds';

    IF NOT v_has_live_lease THEN
        INSERT INTO public.active_client_leases AS lease_record (
            user_id,
            session_id,
            client_id,
            claimed_at,
            last_seen_at,
            expires_at
        )
        VALUES (
            v_user_id,
            v_session_id,
            p_client_id,
            v_now,
            v_now,
            v_new_expiry
        )
        ON CONFLICT (user_id) DO UPDATE
        SET session_id = EXCLUDED.session_id,
            client_id = EXCLUDED.client_id,
            claimed_at = EXCLUDED.claimed_at,
            last_seen_at = EXCLUDED.last_seen_at,
            expires_at = EXCLUDED.expires_at;

        RETURN QUERY
        SELECT 'acquired'::text, false, v_new_expiry;
        RETURN;
    END IF;

    IF v_lease.session_id = v_session_id
       AND v_lease.client_id = p_client_id THEN
        UPDATE public.active_client_leases AS lease_record
        SET last_seen_at = v_now,
            expires_at = v_new_expiry
        WHERE lease_record.user_id = v_user_id;

        RETURN QUERY
        SELECT 'acquired'::text, false, v_new_expiry;
        RETURN;
    END IF;

    IF NOT COALESCE(p_takeover, false) THEN
        RETURN QUERY
        SELECT 'conflict'::text, true, NULL::timestamptz;
        RETURN;
    END IF;

    UPDATE public.active_client_leases AS lease_record
    SET session_id = v_session_id,
        client_id = p_client_id,
        claimed_at = v_now,
        last_seen_at = v_now,
        expires_at = v_new_expiry
    WHERE lease_record.user_id = v_user_id;

    RETURN QUERY
    SELECT 'taken_over'::text, false, v_new_expiry;
END;
$function$;

COMMENT ON FUNCTION public.claim_active_client(uuid, boolean) IS
    'Claims or explicitly transfers the short-lived active-client lease for the authenticated user.';

CREATE OR REPLACE FUNCTION public.heartbeat_active_client(
    p_client_id uuid
)
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_claims jsonb;
    v_headers jsonb;
    v_user_id uuid;
    v_session_id uuid;
    v_header_client_id uuid;
    v_now timestamptz := clock_timestamp();
    v_new_expiry timestamptz := v_now + interval '90 seconds';
    v_updated_expiry timestamptz;
BEGIN
    BEGIN
        v_claims := COALESCE(
            NULLIF(current_setting('request.jwt.claims', true), ''),
            '{}'
        )::jsonb;
        v_headers := COALESCE(
            NULLIF(current_setting('request.headers', true), ''),
            '{}'
        )::jsonb;
        v_user_id := auth.uid();
        v_session_id := NULLIF(v_claims ->> 'session_id', '')::uuid;
        v_header_client_id := NULLIF(
            v_headers ->> 'x-insuregpte-client-id',
            ''
        )::uuid;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE SQLSTATE 'PT401'
                USING MESSAGE =
                    'This page is no longer the active login.';
    END;

    IF COALESCE(v_claims ->> 'role', '') <> 'authenticated'
       OR v_user_id IS NULL
       OR v_session_id IS NULL
       OR p_client_id IS NULL
       OR v_header_client_id IS DISTINCT FROM p_client_id THEN
        RAISE SQLSTATE 'PT401'
            USING MESSAGE =
                'This page is no longer the active login.';
    END IF;

    UPDATE public.active_client_leases AS lease_record
    SET last_seen_at = v_now,
        expires_at = v_new_expiry
    WHERE lease_record.user_id = v_user_id
      AND lease_record.session_id = v_session_id
      AND lease_record.client_id = p_client_id
      AND lease_record.expires_at > v_now
      AND EXISTS (
          SELECT 1
          FROM auth.sessions AS session_record
          WHERE session_record.id = v_session_id
            AND session_record.user_id = v_user_id
            AND (
                session_record.not_after IS NULL
                OR session_record.not_after > v_now
            )
      )
    RETURNING lease_record.expires_at
    INTO v_updated_expiry;

    IF v_updated_expiry IS NULL THEN
        RAISE SQLSTATE 'PT401'
            USING MESSAGE =
                'This page is no longer the active login.';
    END IF;

    RETURN v_updated_expiry;
END;
$function$;

COMMENT ON FUNCTION public.heartbeat_active_client(uuid) IS
    'Renews the active-client lease only for its owning authenticated session and client.';

CREATE OR REPLACE FUNCTION public.release_active_client(
    p_client_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_claims jsonb;
    v_headers jsonb;
    v_user_id uuid;
    v_session_id uuid;
    v_header_client_id uuid;
    v_released boolean;
BEGIN
    BEGIN
        v_claims := COALESCE(
            NULLIF(current_setting('request.jwt.claims', true), ''),
            '{}'
        )::jsonb;
        v_headers := COALESCE(
            NULLIF(current_setting('request.headers', true), ''),
            '{}'
        )::jsonb;
        v_user_id := auth.uid();
        v_session_id := NULLIF(v_claims ->> 'session_id', '')::uuid;
        v_header_client_id := NULLIF(
            v_headers ->> 'x-insuregpte-client-id',
            ''
        )::uuid;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE SQLSTATE 'PT401'
                USING MESSAGE =
                    'This page is no longer the active login.';
    END;

    IF COALESCE(v_claims ->> 'role', '') <> 'authenticated'
       OR v_user_id IS NULL
       OR v_session_id IS NULL
       OR p_client_id IS NULL
       OR v_header_client_id IS DISTINCT FROM p_client_id THEN
        RAISE SQLSTATE 'PT401'
            USING MESSAGE =
                'This page is no longer the active login.';
    END IF;

    DELETE FROM public.active_client_leases AS lease_record
    WHERE lease_record.user_id = v_user_id
      AND lease_record.session_id = v_session_id
      AND lease_record.client_id = p_client_id;

    v_released := FOUND;
    RETURN v_released;
END;
$function$;

COMMENT ON FUNCTION public.release_active_client(uuid) IS
    'Releases the active-client lease only when called by its owning authenticated session and client.';

REVOKE ALL ON FUNCTION public.claim_active_client(uuid, boolean)
FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.heartbeat_active_client(uuid)
FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.release_active_client(uuid)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.claim_active_client(uuid, boolean)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.heartbeat_active_client(uuid)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.release_active_client(uuid)
TO authenticated;

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

    -- Temporary stage-1 compatibility for the already deployed frontend.
    -- Stage 2 removes this entire fallback and requires the client header.
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
