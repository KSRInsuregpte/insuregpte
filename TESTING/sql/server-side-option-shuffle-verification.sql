-- Run after 20260913120000_shuffle_quiz_options_server_side.sql.
-- This is a metadata/security check; it does not expose learner answers.
DO $verification$
DECLARE
    v_definition text;
BEGIN
    SELECT pg_get_functiondef(p.oid)
    INTO v_definition
    FROM pg_proc AS p
    JOIN pg_namespace AS n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.oid::regprocedure::text = 'get_attempt_questions(uuid)'::text;

    IF v_definition IS NULL THEN
        RAISE EXCEPTION 'get_attempt_questions(uuid) is missing';
    END IF;
    IF v_definition NOT LIKE '%hashtextextended%' THEN
        RAISE EXCEPTION 'server-side option rotation is not installed';
    END IF;
    IF v_definition ILIKE '%correct_option%' THEN
        RAISE EXCEPTION 'get_attempt_questions must not expose correct_option';
    END IF;
END;
$verification$;

SELECT
    'server-side option shuffle installed' AS check_name,
    true AS passed;
