-- Rotate answer options in the server-side question RPC.
-- Scoring remains authoritative because submit_quiz_answer compares the
-- submitted option text with questions.correct_option (the stored answer text).

CREATE OR REPLACE FUNCTION public.get_attempt_questions(p_attempt_id uuid)
RETURNS TABLE (
    attempt_id uuid,
    attempt_number integer,
    test_mode text,
    total_questions integer,
    time_limit_minutes integer,
    feedback_mode text,
    started_at timestamptz,
    question_id bigint,
    question_order integer,
    question_text text,
    option_a text,
    option_b text,
    option_c text,
    option_d text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $function$
    WITH question_rows AS (
        SELECT
            qa.id AS attempt_id,
            qa.attempt_number,
            qa.test_mode,
            qa.total_questions,
            qa.time_limit_minutes,
            qa.feedback_mode,
            qa.started_at,
            q.id AS question_id,
            aq.question_order,
            q.question_text,
            q.option_a,
            q.option_b,
            q.option_c,
            q.option_d,
            MOD(
                ABS(pg_catalog.hashtextextended(
                    qa.id::text || ':' || q.id::text,
                    20260913
                )),
                4
            )::integer AS rotation
        FROM public.quiz_attempts AS qa
        JOIN public.quiz_attempt_questions AS aq
          ON aq.attempt_id = qa.id
        JOIN public.questions AS q
          ON q.id = aq.question_id
        WHERE qa.id = p_attempt_id
          AND qa.user_id = auth.uid()
          AND qa.status = 'in_progress'
    )
    SELECT
        attempt_id,
        attempt_number,
        test_mode,
        total_questions,
        time_limit_minutes,
        feedback_mode,
        started_at,
        question_id,
        question_order,
        question_text,
        CASE rotation
            WHEN 0 THEN option_a
            WHEN 1 THEN option_d
            WHEN 2 THEN option_c
            ELSE option_b
        END,
        CASE rotation
            WHEN 0 THEN option_b
            WHEN 1 THEN option_a
            WHEN 2 THEN option_d
            ELSE option_c
        END,
        CASE rotation
            WHEN 0 THEN option_c
            WHEN 1 THEN option_b
            WHEN 2 THEN option_a
            ELSE option_d
        END,
        CASE rotation
            WHEN 0 THEN option_d
            WHEN 1 THEN option_c
            WHEN 2 THEN option_b
            ELSE option_a
        END
    FROM question_rows
    ORDER BY question_order;
$function$;

REVOKE ALL ON FUNCTION public.get_attempt_questions(uuid)
FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_attempt_questions(uuid)
TO authenticated;

COMMENT ON FUNCTION public.get_attempt_questions(uuid) IS
    'Returns authenticated attempt questions with deterministic server-side option rotation; scoring remains text-authoritative.';

NOTIFY pgrst, 'reload schema';
