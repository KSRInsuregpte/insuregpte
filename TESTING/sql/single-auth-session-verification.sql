-- Run after 20260719220000_enforce_single_auth_session.sql.
-- This catalogue verification does not modify application data and returns no
-- rows when every check passes.

DO $verification$
DECLARE
    v_function_oid oid;
    v_definition text;
    v_security_definer boolean;
    v_configuration text[];
BEGIN
    v_function_oid := to_regprocedure(
        'public.fn_enforce_active_auth_session()'
    );

    IF v_function_oid IS NULL THEN
        RAISE EXCEPTION
            'fn_enforce_active_auth_session() is missing';
    END IF;

    SELECT
        procedure.prosecdef,
        procedure.proconfig,
        pg_catalog.pg_get_functiondef(procedure.oid)
    INTO
        v_security_definer,
        v_configuration,
        v_definition
    FROM pg_catalog.pg_proc AS procedure
    WHERE procedure.oid = v_function_oid;

    IF v_security_definer IS NOT TRUE THEN
        RAISE EXCEPTION
            'fn_enforce_active_auth_session must be SECURITY DEFINER';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM unnest(COALESCE(v_configuration, ARRAY[]::text[]))
            AS function_setting(setting)
        WHERE function_setting.setting IN (
            'search_path=',
            'search_path=""'
        )
    ) THEN
        RAISE EXCEPTION
            'fn_enforce_active_auth_session must use an empty search_path';
    END IF;

    IF v_definition NOT LIKE '%request.jwt.claims%'
       OR v_definition NOT LIKE '%auth.uid()%'
       OR v_definition NOT LIKE '%auth.sessions%'
       OR v_definition NOT LIKE '%session_id%'
       OR v_definition NOT LIKE '%created_at DESC%'
       OR v_definition NOT LIKE '%not_after%'
       OR v_definition NOT LIKE '%PT401%' THEN
        RAISE EXCEPTION
            'The session guard definition is incomplete';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_catalog.pg_proc AS procedure
        CROSS JOIN LATERAL aclexplode(
            COALESCE(
                procedure.proacl,
                acldefault('f', procedure.proowner)
            )
        ) AS privilege
        WHERE procedure.oid = v_function_oid
          AND privilege.grantee = 0
          AND privilege.privilege_type = 'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'PUBLIC must not execute fn_enforce_active_auth_session';
    END IF;

    IF NOT has_function_privilege(
        'anon',
        v_function_oid,
        'EXECUTE'
    ) OR NOT has_function_privilege(
        'authenticated',
        v_function_oid,
        'EXECUTE'
    ) OR NOT has_function_privilege(
        'service_role',
        v_function_oid,
        'EXECUTE'
    ) OR NOT has_function_privilege(
        'authenticator',
        v_function_oid,
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'Required PostgREST roles are missing EXECUTE privilege';
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
            'The authenticator PostgREST pre-request setting is missing';
    END IF;
END;
$verification$;

-- Runtime verification is mandatory because catalogue checks cannot prove
-- request-time JWT behavior. Follow docs/06_TESTING_GUIDE.md with two users,
-- two browsers, shared-session tabs, an active quiz, and explicit logout.
