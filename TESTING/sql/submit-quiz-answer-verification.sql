-- Run after 20260719180000_harden_submit_quiz_answer.sql in a non-production
-- environment. These checks do not modify application data.

DO $verification$
DECLARE
    v_function_oid oid;
    v_definition text;
    v_security_definer boolean;
    v_settings text[];
BEGIN
    v_function_oid := to_regprocedure(
        'public.submit_quiz_answer(uuid,bigint,text)'
    );

    IF v_function_oid IS NULL THEN
        RAISE EXCEPTION 'submit_quiz_answer signature is missing';
    END IF;

    SELECT
        procedure.prosecdef,
        procedure.proconfig,
        pg_catalog.pg_get_functiondef(procedure.oid)
    INTO
        v_security_definer,
        v_settings,
        v_definition
    FROM pg_catalog.pg_proc AS procedure
    WHERE procedure.oid = v_function_oid;

    IF v_security_definer IS NOT TRUE THEN
        RAISE EXCEPTION 'submit_quiz_answer must remain SECURITY DEFINER';
    END IF;

    IF v_settings IS NULL
       OR NOT ('search_path=""' = ANY (v_settings)) THEN
        RAISE EXCEPTION 'submit_quiz_answer has an unsafe search_path';
    END IF;

    IF has_function_privilege(
        'anon',
        v_function_oid,
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'anon must not execute submit_quiz_answer';
    END IF;

    IF NOT has_function_privilege(
        'authenticated',
        v_function_oid,
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'authenticated requires submit_quiz_answer EXECUTE';
    END IF;

    IF v_definition NOT LIKE '%v_feedback_mode%' THEN
        RAISE EXCEPTION 'feedback-mode protection is missing';
    END IF;

    IF v_definition NOT LIKE '%v_expires_at%' THEN
        RAISE EXCEPTION 'server-side expiry protection is missing';
    END IF;
END;
$verification$;

-- Functional verification cases to execute through an authenticated client:
-- 1. Practice mode returns immediate correctness and explanation.
-- 2. Mock and proctored_mock return NULL for is_correct, correct_answer, and
--    explanation before finalization.
-- 3. A second submission for the same attempt/question is rejected.
-- 4. A second authenticated user cannot submit to the first user's attempt.
-- 5. An expired attempt rejects new answers.
-- 6. The final answer keeps answered_count, correct_answers, wrong_answers,
--    score, percentage, passed, status, and completed_at consistent.
