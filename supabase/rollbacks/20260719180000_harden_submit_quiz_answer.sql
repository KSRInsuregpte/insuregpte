-- Roll back 20260719180000_harden_submit_quiz_answer.sql.
-- Restores the exact definition and grants captured on 2026-07-19.

CREATE OR REPLACE FUNCTION public.submit_quiz_answer(p_attempt_id uuid, p_question_id bigint, p_selected_answer text)
 RETURNS TABLE(is_correct boolean, correct_answer text, explanation text, answered_count integer, score integer, completed boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$

DECLARE
    v_user_id uuid;
    v_correct_answer text;
    v_explanation text;
    v_is_correct boolean;
    v_answered_count integer;
    v_score integer;
    v_total_questions integer;
    v_completed boolean;

BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'You must be signed in.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.quiz_attempts
        WHERE id = p_attempt_id
          AND user_id = v_user_id
          AND status = 'in_progress'
    ) THEN
        RAISE EXCEPTION
            'The quiz attempt is invalid or already completed.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.quiz_attempt_questions
        WHERE attempt_id = p_attempt_id
          AND question_id = p_question_id
    ) THEN
        RAISE EXCEPTION
            'This question does not belong to this attempt.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.quiz_attempt_questions
        WHERE attempt_id = p_attempt_id
          AND question_id = p_question_id
          AND answered_at IS NOT NULL
    ) THEN
        RAISE EXCEPTION
            'This question has already been answered.';
    END IF;

    SELECT
        q.correct_option,
        q.explanation
    INTO
        v_correct_answer,
        v_explanation
    FROM public.questions q
    WHERE q.id = p_question_id;

    v_is_correct :=
        TRIM(COALESCE(p_selected_answer, '')) =
        TRIM(COALESCE(v_correct_answer, ''));

    UPDATE public.quiz_attempt_questions
    SET
        selected_answer = p_selected_answer,
        is_correct = v_is_correct,
        marks_awarded =
            CASE
                WHEN v_is_correct THEN 1
                ELSE 0
            END,
        answered_at = now()
    WHERE attempt_id = p_attempt_id
      AND question_id = p_question_id;

    SELECT
        COUNT(*) FILTER (
            WHERE answered_at IS NOT NULL
        )::integer,

        COALESCE(
            SUM(marks_awarded),
            0
        )::integer

    INTO
        v_answered_count,
        v_score

    FROM public.quiz_attempt_questions
    WHERE attempt_id = p_attempt_id;

    SELECT total_questions
    INTO v_total_questions
    FROM public.quiz_attempts
    WHERE id = p_attempt_id
      AND user_id = v_user_id;

    v_completed :=
        v_answered_count >= v_total_questions;

    UPDATE public.quiz_attempts
    SET
        answered_count = v_answered_count,
        correct_answers = v_score,
        wrong_answers = v_answered_count - v_score,
        score = v_score,

        status =
            CASE
                WHEN v_completed THEN 'completed'
                ELSE 'in_progress'
            END,

        completed_at =
            CASE
                WHEN v_completed THEN now()
                ELSE NULL
            END

    WHERE id = p_attempt_id
      AND user_id = v_user_id;

    RETURN QUERY
    SELECT
        v_is_correct,
        v_correct_answer,
        v_explanation,
        v_answered_count,
        v_score,
        v_completed;

END;

$function$

REVOKE ALL ON FUNCTION public.submit_quiz_answer(uuid, bigint, text)
FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.submit_quiz_answer(uuid, bigint, text)
TO anon, authenticated, service_role;

