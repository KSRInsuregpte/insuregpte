-- Expected result: Success. No rows returned.
-- Run after 20260725121000_gate_quiz_access_and_enable_demo.sql.

DO $verification$
DECLARE
    v_definition text;
    v_demo public.quiz_mode_config%ROWTYPE;
BEGIN
    SELECT mode_record.*
    INTO v_demo
    FROM public.quiz_mode_config AS mode_record
    WHERE mode_record.test_mode = 'demo';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'The demo quiz mode is missing';
    END IF;

    IF v_demo.question_count <> 10
       OR v_demo.feedback_mode <> 'immediate'
       OR v_demo.is_active IS NOT TRUE THEN
        RAISE EXCEPTION
            'The demo quiz configuration is incorrect';
    END IF;

    SELECT pg_catalog.pg_get_functiondef(
        pg_catalog.to_regprocedure(
            'public.start_quiz_attempt(bigint,text)'
        )
    )
    INTO v_definition;

    IF v_definition NOT LIKE '%public.user_entitlements%' THEN
        RAISE EXCEPTION
            'start_quiz_attempt does not enforce entitlements';
    END IF;

    IF v_definition NOT LIKE
        '%difficulty_level = ''advanced''%' THEN
        RAISE EXCEPTION
            'Demo mode does not select advanced questions';
    END IF;

    IF v_definition NOT LIKE
        '%question_record.is_active = true%' THEN
        RAISE EXCEPTION
            'Quiz allocation does not filter inactive questions';
    END IF;

    IF NOT pg_catalog.has_function_privilege(
        'authenticated',
        'public.start_quiz_attempt(bigint,text)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'authenticated cannot execute start_quiz_attempt';
    END IF;

    IF pg_catalog.has_function_privilege(
        'anon',
        'public.start_quiz_attempt(bigint,text)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'anon must not execute start_quiz_attempt';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.quiz_attempt_questions AS assigned_question
        JOIN public.quiz_attempts AS attempt_record
          ON attempt_record.id = assigned_question.attempt_id
        JOIN public.questions AS question_record
          ON question_record.id = assigned_question.question_id
        WHERE attempt_record.test_mode = 'demo'
          AND (
              question_record.is_active IS NOT TRUE
              OR question_record.difficulty_level <> 'advanced'
          )
    ) THEN
        RAISE EXCEPTION
            'A demo attempt contains a non-advanced or inactive question';
    END IF;
END;
$verification$;
