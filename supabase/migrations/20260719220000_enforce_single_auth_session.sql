-- Enforce the approved one-active-session rule for authenticated PostgREST
-- table and RPC requests without changing any existing RPC signature.
--
-- Supabase Auth remains the source of truth. The newest auth.sessions row for
-- a user is authoritative; older session_id claims are rejected immediately.
--
-- Rollback:
-- supabase/rollbacks/20260719220000_enforce_single_auth_session.sql

DO $guard$
DECLARE
    v_conflicting_setting text;
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
            'A different PostgREST pre-request function is already configured: %',
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
    v_user_id uuid;
    v_session_id uuid;
    v_authoritative_session_id uuid;
BEGIN
    BEGIN
        v_claims := COALESCE(
            NULLIF(
                current_setting('request.jwt.claims', true),
                ''
            ),
            '{}'
        )::jsonb;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE SQLSTATE 'PT401'
                USING MESSAGE =
                    'This session is no longer active. Please sign in again.';
    END;

    -- Anonymous and server-side service-role requests are outside the
    -- one-user-session policy.
    IF COALESCE(v_claims ->> 'role', '') <> 'authenticated' THEN
        RETURN;
    END IF;

    v_user_id := auth.uid();

    BEGIN
        v_session_id := NULLIF(v_claims ->> 'session_id', '')::uuid;
    EXCEPTION
        WHEN invalid_text_representation THEN
            RAISE SQLSTATE 'PT401'
                USING MESSAGE =
                    'This session is no longer active. Please sign in again.';
    END;

    IF v_user_id IS NULL OR v_session_id IS NULL THEN
        RAISE SQLSTATE 'PT401'
            USING MESSAGE =
                'This session is no longer active. Please sign in again.';
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
    'Rejects authenticated PostgREST requests unless the JWT session_id is the user''s newest active auth.sessions row.';

REVOKE ALL ON FUNCTION public.fn_enforce_active_auth_session()
FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.fn_enforce_active_auth_session()
TO anon, authenticated, service_role, authenticator;

ALTER ROLE authenticator
SET pgrst.db_pre_request = 'public.fn_enforce_active_auth_session';

NOTIFY pgrst, 'reload config';
