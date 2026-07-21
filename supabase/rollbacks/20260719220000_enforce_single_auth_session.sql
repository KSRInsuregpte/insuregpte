-- Roll back the PostgREST one-active-session guard.
-- This does not change Supabase Auth users or application data.

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

ALTER ROLE authenticator RESET pgrst.db_pre_request;

NOTIFY pgrst, 'reload config';

DROP FUNCTION IF EXISTS public.fn_enforce_active_auth_session();
