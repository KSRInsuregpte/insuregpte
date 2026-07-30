-- Expected result: Success. No rows returned.
-- Run after 20260728100000_restore_catalogue_admin_compatibility.sql.

DO $verification$
DECLARE
    v_signature text;
    v_function_oid regprocedure;
    v_owner text;
    v_catalogue_count integer;
BEGIN
    FOREACH v_signature IN ARRAY ARRAY[
        'public.get_subject_catalogue()',
        'public.add_subject_to_cart(bigint)',
        'public.remove_subject_from_cart(bigint)',
        'public.get_my_cart()',
        'public.get_my_quiz_attempts()',
        'public.start_quiz_attempt(bigint,text)',
        'public.fn_is_admin()'
    ]
    LOOP
        v_function_oid := pg_catalog.to_regprocedure(v_signature);

        IF v_function_oid IS NULL THEN
            RAISE EXCEPTION 'Required RPC is missing: %', v_signature;
        END IF;
    END LOOP;

    FOREACH v_signature IN ARRAY ARRAY[
        'public.get_subject_catalogue()',
        'public.add_subject_to_cart(bigint)',
        'public.remove_subject_from_cart(bigint)',
        'public.get_my_cart()'
    ]
    LOOP
        v_function_oid := pg_catalog.to_regprocedure(v_signature);

        SELECT role_record.rolname
        INTO v_owner
        FROM pg_catalog.pg_proc AS procedure_record
        JOIN pg_catalog.pg_roles AS role_record
          ON role_record.oid = procedure_record.proowner
        WHERE procedure_record.oid = v_function_oid
          AND procedure_record.prosecdef = true;

        IF v_owner IS DISTINCT FROM 'postgres' THEN
            RAISE EXCEPTION
                'RPC % must be SECURITY DEFINER and owned by postgres',
                v_signature;
        END IF;
    END LOOP;

    IF NOT pg_catalog.has_function_privilege(
        'anon',
        'public.get_subject_catalogue()',
        'EXECUTE'
    ) OR NOT pg_catalog.has_function_privilege(
        'authenticated',
        'public.get_subject_catalogue()',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'The public catalogue RPC is not callable by both browser roles';
    END IF;

    IF pg_catalog.has_function_privilege(
        'anon',
        'public.get_my_cart()',
        'EXECUTE'
    ) OR NOT pg_catalog.has_function_privilege(
        'authenticated',
        'public.get_my_cart()',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'Cart access grants do not match the authenticated-only boundary';
    END IF;

    IF pg_catalog.has_table_privilege(
        'anon',
        'public.subjects',
        'SELECT'
    ) OR pg_catalog.has_table_privilege(
        'authenticated',
        'public.subjects',
        'SELECT'
    ) OR pg_catalog.has_table_privilege(
        'anon',
        'public.questions',
        'SELECT'
    ) OR pg_catalog.has_table_privilege(
        'authenticated',
        'public.questions',
        'SELECT'
    ) THEN
        RAISE EXCEPTION
            'Browser roles must not read subjects or questions directly';
    END IF;

    SELECT COUNT(*)
    INTO v_catalogue_count
    FROM public.get_subject_catalogue();

    IF v_catalogue_count < 3 THEN
        RAISE EXCEPTION
            'The runtime catalogue returned fewer than the three active launch subjects';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.quiz_mode_config AS mode_record
        WHERE mode_record.test_mode = 'demo'
          AND mode_record.is_active = true
          AND mode_record.question_count = 10
    ) THEN
        RAISE EXCEPTION
            'The active ten-question demo configuration is missing';
    END IF;
END;
$verification$;

-- Exercise the public RPC with the same role used by a logged-out browser.
BEGIN;
SET LOCAL ROLE anon;
DO $anonymous_runtime$
BEGIN
    PERFORM 1
    FROM public.get_subject_catalogue()
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'The anonymous catalogue call returned no active subject';
    END IF;
END;
$anonymous_runtime$;
RESET ROLE;
ROLLBACK;
