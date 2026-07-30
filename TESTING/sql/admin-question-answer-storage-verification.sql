-- Expected result: Success. No rows returned.
-- Run after 20260730120000_repair_admin_question_answer_storage.sql.

DO $verification$
DECLARE
    v_admin_save_oid regprocedure :=
        pg_catalog.to_regprocedure(
            'public.admin_save_question(jsonb)'
        );
    v_submit_answer_oid regprocedure :=
        pg_catalog.to_regprocedure(
            'public.submit_quiz_answer(uuid,bigint,text)'
        );
    v_admin_definition text;
    v_submit_definition text;
BEGIN
    IF v_admin_save_oid IS NULL OR v_submit_answer_oid IS NULL THEN
        RAISE EXCEPTION
            'The administrator save or quiz submission RPC is missing.';
    END IF;

    SELECT pg_catalog.pg_get_functiondef(v_admin_save_oid)
    INTO v_admin_definition;

    IF v_admin_definition NOT LIKE
           '%WHEN ''A'' THEN v_option_a%'
       OR v_admin_definition NOT LIKE
           '%WHEN ''B'' THEN v_option_b%'
       OR v_admin_definition NOT LIKE
           '%WHEN ''C'' THEN v_option_c%'
       OR v_admin_definition NOT LIKE
           '%WHEN ''D'' THEN v_option_d%'
       OR v_admin_definition NOT LIKE
           '%correct_option = v_correct_answer%'
       OR v_admin_definition NOT LIKE
           '%v_correct_answer,%' THEN
        RAISE EXCEPTION
            'admin_save_question does not store the selected option text.';
    END IF;

    SELECT pg_catalog.pg_get_functiondef(v_submit_answer_oid)
    INTO v_submit_definition;

    IF v_submit_definition NOT LIKE '%p_selected_answer%'
       OR v_submit_definition NOT LIKE '%v_correct_answer%' THEN
        RAISE EXCEPTION
            'submit_quiz_answer no longer follows the answer-text scoring contract.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.questions AS question_record
        WHERE pg_catalog.upper(
            pg_catalog.btrim(question_record.correct_option)
        ) IN ('A', 'B', 'C', 'D')
          AND EXISTS (
              SELECT 1
              FROM public.admin_audit_events AS audit_event
              WHERE audit_event.entity_type = 'question'
                AND audit_event.entity_key = question_record.id::text
          )
    ) THEN
        RAISE EXCEPTION
            'An administrator-edited question still stores an answer tag.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.questions AS question_record
        WHERE question_record.is_active = true
          AND NOT (
              pg_catalog.btrim(question_record.correct_option)
                  = pg_catalog.btrim(question_record.option_a)
              OR pg_catalog.btrim(question_record.correct_option)
                  = pg_catalog.btrim(question_record.option_b)
              OR pg_catalog.btrim(question_record.correct_option)
                  = pg_catalog.btrim(question_record.option_c)
              OR pg_catalog.btrim(question_record.correct_option)
                  = pg_catalog.btrim(question_record.option_d)
          )
    ) THEN
        RAISE EXCEPTION
            'An active question has a correct answer that does not match its options.';
    END IF;

    IF NOT pg_catalog.has_function_privilege(
        'authenticated',
        'public.admin_save_question(jsonb)',
        'EXECUTE'
    ) OR pg_catalog.has_function_privilege(
        'anon',
        'public.admin_save_question(jsonb)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'Administrator question-save execution grants are incorrect.';
    END IF;

    IF pg_catalog.has_table_privilege(
        'authenticated',
        'public.questions',
        'UPDATE'
    ) OR pg_catalog.has_table_privilege(
        'anon',
        'public.questions',
        'SELECT'
    ) THEN
        RAISE EXCEPTION
            'The RPC-only question-table boundary was weakened.';
    END IF;
END;
$verification$;
