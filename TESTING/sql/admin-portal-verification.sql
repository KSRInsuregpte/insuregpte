-- Expected result: Success. No rows returned.
-- Run after 20260727180000_build_admin_portal.sql.

DO $verification$
DECLARE
    v_signature text;
    v_definition text;
    v_admin_count integer;
BEGIN
    IF pg_catalog.to_regclass('public.admin_audit_events') IS NULL THEN
        RAISE EXCEPTION 'admin_audit_events is missing';
    END IF;

    IF NOT (
        SELECT classes.relrowsecurity
        FROM pg_catalog.pg_class AS classes
        WHERE classes.oid = 'public.admin_audit_events'::regclass
    ) THEN
        RAISE EXCEPTION 'RLS is not enabled on admin_audit_events';
    END IF;

    IF pg_catalog.has_table_privilege(
        'anon',
        'public.admin_audit_events',
        'SELECT'
    ) OR pg_catalog.has_table_privilege(
        'authenticated',
        'public.admin_audit_events',
        'SELECT'
    ) OR pg_catalog.has_table_privilege(
        'authenticated',
        'public.admin_audit_events',
        'INSERT'
    ) THEN
        RAISE EXCEPTION
            'Browser roles must not access admin_audit_events directly';
    END IF;

    IF pg_catalog.has_table_privilege(
        'anon',
        'public.subjects',
        'SELECT'
    ) OR pg_catalog.has_table_privilege(
        'anon',
        'public.subjects',
        'INSERT'
    ) OR pg_catalog.has_table_privilege(
        'authenticated',
        'public.subjects',
        'UPDATE'
    ) OR pg_catalog.has_table_privilege(
        'anon',
        'public.questions',
        'SELECT'
    ) OR pg_catalog.has_table_privilege(
        'authenticated',
        'public.questions',
        'INSERT'
    ) OR pg_catalog.has_table_privilege(
        'authenticated',
        'public.questions',
        'DELETE'
    ) THEN
        RAISE EXCEPTION
            'Browser roles must use RPCs for subjects and questions';
    END IF;

    FOREACH v_signature IN ARRAY ARRAY[
        'public.fn_is_admin()',
        'public.get_admin_portal_summary()',
        'public.admin_list_subjects()',
        'public.admin_save_subject(jsonb)',
        'public.admin_list_questions(bigint)',
        'public.admin_save_question(jsonb)',
        'public.admin_list_users()',
        'public.admin_set_user_status(uuid,text)',
        'public.admin_list_exam_information()',
        'public.admin_save_exam_information(jsonb)',
        'public.admin_retire_exam_information(bigint)',
        'public.admin_list_audit_events(integer)'
    ]
    LOOP
        IF pg_catalog.to_regprocedure(v_signature) IS NULL THEN
            RAISE EXCEPTION 'Required admin function % is missing',
                v_signature;
        END IF;

        IF pg_catalog.has_function_privilege(
            'anon',
            v_signature,
            'EXECUTE'
        ) THEN
            RAISE EXCEPTION 'anon must not execute %', v_signature;
        END IF;

        IF NOT pg_catalog.has_function_privilege(
            'authenticated',
            v_signature,
            'EXECUTE'
        ) THEN
            RAISE EXCEPTION 'authenticated cannot execute %', v_signature;
        END IF;

        SELECT pg_catalog.pg_get_functiondef(
            pg_catalog.to_regprocedure(v_signature)
        )
        INTO v_definition;

        IF v_definition NOT LIKE '%SECURITY DEFINER%'
           OR v_definition NOT LIKE '%SET search_path TO%'
           OR (
               v_signature <> 'public.fn_is_admin()'
               AND v_definition NOT LIKE '%public.fn_is_admin()%'
           ) THEN
            RAISE EXCEPTION
                'Function % does not enforce the admin boundary',
                v_signature;
        END IF;
    END LOOP;

    SELECT COUNT(*)
    INTO v_admin_count
    FROM public.profiles AS profile_record
    WHERE profile_record.role = 'admin'
      AND profile_record.status = 'active';

    IF v_admin_count < 1 THEN
        RAISE EXCEPTION 'No active administrator profile exists';
    END IF;

    SELECT pg_catalog.pg_get_functiondef(
        pg_catalog.to_regprocedure(
            'public.admin_save_question(jsonb)'
        )
    )
    INTO v_definition;

    IF v_definition NOT LIKE '%WHEN ''easy'' THEN ''foundation''%'
       OR v_definition NOT LIKE
          '%WHEN ''moderate'' THEN ''intermediate''%'
       OR v_definition NOT LIKE '%WHEN ''hard'' THEN ''advanced''%'
       OR v_definition NOT LIKE '%question_type = ''MCQ''%' THEN
        RAISE EXCEPTION
            'Question difficulty or current MCQ safeguards are missing';
    END IF;

    SELECT pg_catalog.pg_get_functiondef(
        pg_catalog.to_regprocedure(
            'public.admin_set_user_status(uuid,text)'
        )
    )
    INTO v_definition;

    IF v_definition LIKE '%SET role =%'
       OR v_definition NOT LIKE
          '%(''active'', ''verification_pending'')%' THEN
        RAISE EXCEPTION
            'User management must not change roles or Auth credentials';
    END IF;

    BEGIN
        PERFORM public.get_admin_portal_summary();
        RAISE EXCEPTION
            'A request without an authenticated admin was unexpectedly accepted';
    EXCEPTION
        WHEN SQLSTATE 'PT403' THEN
            NULL;
    END;
END;
$verification$;
