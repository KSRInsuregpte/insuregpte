-- Run after both active-client lease migrations:
--   20260720090000_add_active_client_lease.sql
--   20260720100000_require_active_client_lease.sql
--
-- This catalogue verification does not modify application data. It returns
-- "Success. No rows returned" when every database check passes.

DO $verification$
DECLARE
    v_table_oid oid := to_regclass('public.active_client_leases');
    v_function_oid oid;
    v_guard_oid oid := to_regprocedure(
        'public.fn_enforce_active_auth_session()'
    );
    v_signature text;
    v_definition text;
    v_security_definer boolean;
    v_configuration text[];
BEGIN
    IF v_table_oid IS NULL THEN
        RAISE EXCEPTION 'public.active_client_leases is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_class AS relation
        WHERE relation.oid = v_table_oid
          AND relation.relkind = 'r'
          AND relation.relrowsecurity
    ) THEN
        RAISE EXCEPTION
            'active_client_leases must be a table with RLS enabled';
    END IF;

    IF (
        SELECT count(*)
        FROM pg_catalog.pg_attribute AS attribute
        WHERE attribute.attrelid = v_table_oid
          AND attribute.attnum > 0
          AND NOT attribute.attisdropped
          AND attribute.attnotnull
          AND (
              attribute.attname,
              pg_catalog.format_type(
                  attribute.atttypid,
                  attribute.atttypmod
              )
          ) IN (
              ('user_id', 'uuid'),
              ('session_id', 'uuid'),
              ('client_id', 'uuid'),
              ('claimed_at', 'timestamp with time zone'),
              ('last_seen_at', 'timestamp with time zone'),
              ('expires_at', 'timestamp with time zone')
          )
    ) <> 6 THEN
        RAISE EXCEPTION
            'active_client_leases columns are incomplete or nullable';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_constraint AS constraint_record
        WHERE constraint_record.conrelid = v_table_oid
          AND constraint_record.contype = 'p'
          AND pg_catalog.pg_get_constraintdef(
              constraint_record.oid
          ) = 'PRIMARY KEY (user_id)'
    ) THEN
        RAISE EXCEPTION
            'active_client_leases must have user_id as its primary key';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_constraint AS constraint_record
        WHERE constraint_record.conrelid = v_table_oid
          AND constraint_record.contype = 'f'
          AND constraint_record.confrelid = 'auth.users'::regclass
          AND constraint_record.confdeltype = 'c'
    ) THEN
        RAISE EXCEPTION
            'active_client_leases must cascade from auth.users';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_catalog.pg_policy AS policy_record
        WHERE policy_record.polrelid = v_table_oid
    ) THEN
        RAISE EXCEPTION
            'active_client_leases must not expose direct RLS policies';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_catalog.pg_class AS relation
        CROSS JOIN LATERAL pg_catalog.aclexplode(
            COALESCE(
                relation.relacl,
                pg_catalog.acldefault('r', relation.relowner)
            )
        ) AS privilege
        LEFT JOIN pg_catalog.pg_roles AS grantee_role
          ON grantee_role.oid = privilege.grantee
        WHERE relation.oid = v_table_oid
          AND (
              privilege.grantee = 0
              OR grantee_role.rolname IN (
                  'anon',
                  'authenticated',
                  'service_role'
              )
          )
    ) THEN
        RAISE EXCEPTION
            'Browser and service roles must not access active_client_leases directly';
    END IF;

    FOREACH v_signature IN ARRAY ARRAY[
        'public.claim_active_client(uuid,boolean)',
        'public.heartbeat_active_client(uuid)',
        'public.release_active_client(uuid)'
    ]
    LOOP
        v_function_oid := to_regprocedure(v_signature);

        IF v_function_oid IS NULL THEN
            RAISE EXCEPTION '% is missing', v_signature;
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
            RAISE EXCEPTION '% must be SECURITY DEFINER', v_signature;
        END IF;

        IF NOT EXISTS (
            SELECT 1
            FROM unnest(
                COALESCE(v_configuration, ARRAY[]::text[])
            ) AS function_setting(setting)
            WHERE function_setting.setting IN (
                'search_path=',
                'search_path=""'
            )
        ) THEN
            RAISE EXCEPTION
                '% must use an empty search_path', v_signature;
        END IF;

        IF v_definition NOT LIKE '%request.jwt.claims%'
           OR v_definition NOT LIKE '%request.headers%'
           OR v_definition NOT LIKE '%x-insuregpte-client-id%'
           OR v_definition NOT LIKE '%auth.uid()%'
           OR v_definition NOT LIKE '%session_id%'
           OR v_definition NOT LIKE '%client_id%'
           OR v_definition NOT LIKE '%PT401%' THEN
            RAISE EXCEPTION '% validation is incomplete', v_signature;
        END IF;

        IF EXISTS (
            SELECT 1
            FROM pg_catalog.pg_proc AS procedure
            CROSS JOIN LATERAL pg_catalog.aclexplode(
                COALESCE(
                    procedure.proacl,
                    pg_catalog.acldefault('f', procedure.proowner)
                )
            ) AS privilege
            WHERE procedure.oid = v_function_oid
              AND privilege.grantee = 0
              AND privilege.privilege_type = 'EXECUTE'
        )
           OR has_function_privilege('anon', v_function_oid, 'EXECUTE')
           OR has_function_privilege(
               'service_role',
               v_function_oid,
               'EXECUTE'
           ) THEN
            RAISE EXCEPTION
                '% is executable by an unintended role', v_signature;
        END IF;

        IF NOT has_function_privilege(
            'authenticated',
            v_function_oid,
            'EXECUTE'
        ) THEN
            RAISE EXCEPTION
                'authenticated is missing EXECUTE on %', v_signature;
        END IF;
    END LOOP;

    IF v_guard_oid IS NULL THEN
        RAISE EXCEPTION 'fn_enforce_active_auth_session() is missing';
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
    WHERE procedure.oid = v_guard_oid;

    IF v_security_definer IS NOT TRUE THEN
        RAISE EXCEPTION
            'fn_enforce_active_auth_session must be SECURITY DEFINER';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM unnest(
            COALESCE(v_configuration, ARRAY[]::text[])
        ) AS function_setting(setting)
        WHERE function_setting.setting IN (
            'search_path=',
            'search_path=""'
        )
    ) THEN
        RAISE EXCEPTION
            'fn_enforce_active_auth_session must use an empty search_path';
    END IF;

    IF v_definition NOT LIKE '%request.jwt.claims%'
       OR v_definition NOT LIKE '%request.headers%'
       OR v_definition NOT LIKE '%request.method%'
       OR v_definition NOT LIKE '%request.path%'
       OR v_definition NOT LIKE '%rpc/claim_active_client%'
       OR v_definition NOT LIKE '%x-insuregpte-client-id%'
       OR v_definition NOT LIKE '%active_client_leases%'
       OR v_definition NOT LIKE '%auth.sessions%'
       OR v_definition NOT LIKE '%PT401%'
       OR v_definition LIKE '%created_at DESC%' THEN
        RAISE EXCEPTION
            'The strict active-client pre-request guard is incomplete';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_catalog.pg_proc AS procedure
        CROSS JOIN LATERAL pg_catalog.aclexplode(
            COALESCE(
                procedure.proacl,
                pg_catalog.acldefault('f', procedure.proowner)
            )
        ) AS privilege
        WHERE procedure.oid = v_guard_oid
          AND privilege.grantee = 0
          AND privilege.privilege_type = 'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'PUBLIC must not execute fn_enforce_active_auth_session';
    END IF;

    IF NOT has_function_privilege('anon', v_guard_oid, 'EXECUTE')
       OR NOT has_function_privilege(
           'authenticated',
           v_guard_oid,
           'EXECUTE'
       )
       OR NOT has_function_privilege(
           'service_role',
           v_guard_oid,
           'EXECUTE'
       )
       OR NOT has_function_privilege(
           'authenticator',
           v_guard_oid,
           'EXECUTE'
       ) THEN
        RAISE EXCEPTION
            'Required PostgREST roles are missing guard EXECUTE privilege';
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
            'The authenticator pre-request setting is missing';
    END IF;
END;
$verification$;

-- Runtime behavior still requires the Chrome/Edge and duplicate-tab tests in
-- docs/06_TESTING_GUIDE.md because catalogue checks cannot simulate browsers.
