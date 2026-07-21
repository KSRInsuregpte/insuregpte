-- Harden submit_quiz_answer without changing its deployed signature or return
-- shape. This migration prevents final-only feedback disclosure, rejects late
-- submissions, serializes answer updates, and keeps attempt totals consistent.
--
-- Rollback:
-- supabase/rollbacks/20260719180000_harden_submit_quiz_answer.sql

CREATE OR REPLACE FUNCTION public.submit_quiz_answer(
    p_attempt_id uuid,
    p_question_id bigint,
    p_selected_answer text
)
RETURNS TABLE (
    is_correct boolean,
    correct_answer text,
    explanation text,
    answered_count integer,
    score integer,
    completed boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id uuid;
    v_feedback_mode text;
    v_total_questions integer;
    v_pass_percentage numeric;
    v_expires_at timestamptz;
    v_correct_answer text;
    v_explanation text;
    v_is_correct boolean;
    v_answered_count integer;
    v_score integer;
    v_percentage numeric;
    v_completed boolean;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'You must be signed in.';
    END IF;

    IF NULLIF(TRIM(p_selected_answer), '') IS NULL THEN
        RAISE EXCEPTION 'A selected answer is required.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.profiles AS profile
        WHERE profile.id = v_user_id
          AND profile.status = 'active'
    ) THEN
        RAISE EXCEPTION 'Your account is not active.';
    END IF;

    SELECT
        attempt.feedback_mode,
        attempt.total_questions,
        attempt.pass_percentage,
        attempt.started_at
            + make_interval(mins => attempt.time_limit_minutes),
        question.correct_option,
        question.explanation
    INTO
        v_feedback_mode,
        v_total_questions,
        v_pass_percentage,
        v_expires_at,
        v_correct_answer,
        v_explanation
    FROM public.quiz_attempts AS attempt
    JOIN public.quiz_attempt_questions AS attempt_question
        ON attempt_question.attempt_id = attempt.id
    JOIN public.questions AS question
        ON question.id = attempt_question.question_id
    WHERE attempt.id = p_attempt_id
      AND attempt.user_id = v_user_id
      AND attempt.status = 'in_progress'
      AND attempt_question.question_id = p_question_id
      AND attempt_question.answered_at IS NULL
    FOR UPDATE OF attempt, attempt_question;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'The attempt or question is invalid, completed, or already answered.';
    END IF;

    IF clock_timestamp() >= v_expires_at THEN
        RAISE EXCEPTION
            'The quiz time limit has expired. Finalize the attempt.';
    END IF;

    v_is_correct :=
        TRIM(p_selected_answer) = TRIM(COALESCE(v_correct_answer, ''));

    UPDATE public.quiz_attempt_questions
    SET
        selected_answer = p_selected_answer,
        is_correct = v_is_correct,
        marks_awarded = CASE WHEN v_is_correct THEN 1 ELSE 0 END,
        answered_at = clock_timestamp()
    WHERE attempt_id = p_attempt_id
      AND question_id = p_question_id
      AND answered_at IS NULL;

    SELECT
        COUNT(*) FILTER (
            WHERE attempt_question.answered_at IS NOT NULL
        )::integer,
        COALESCE(SUM(attempt_question.marks_awarded), 0)::integer
    INTO
        v_answered_count,
        v_score
    FROM public.quiz_attempt_questions AS attempt_question
    WHERE attempt_question.attempt_id = p_attempt_id;

    v_completed := v_answered_count >= v_total_questions;
    v_percentage := ROUND(
        (v_score::numeric / NULLIF(v_total_questions, 0)) * 100,
        2
    );

    UPDATE public.quiz_attempts
    SET
        answered_count = v_answered_count,
        correct_answers = v_score,
        wrong_answers = v_answered_count - v_score,
        score = v_score,
        percentage = COALESCE(v_percentage, 0),
        passed = CASE
            WHEN v_completed THEN
                COALESCE(v_percentage, 0) >= pass_percentage
            ELSE false
        END,
        status = CASE
            WHEN v_completed THEN 'completed'
            ELSE 'in_progress'
        END,
        completed_at = CASE
            WHEN v_completed THEN clock_timestamp()
            ELSE NULL
        END
    WHERE id = p_attempt_id
      AND user_id = v_user_id;

    RETURN QUERY
    SELECT
        CASE
            WHEN v_feedback_mode = 'immediate' THEN v_is_correct
            ELSE NULL::boolean
        END,
        CASE
            WHEN v_feedback_mode = 'immediate' THEN v_correct_answer
            ELSE NULL::text
        END,
        CASE
            WHEN v_feedback_mode = 'immediate' THEN v_explanation
            ELSE NULL::text
        END,
        v_answered_count,
        v_score,
        v_completed;
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_quiz_answer(uuid, bigint, text)
FROM PUBLIC;

REVOKE EXECUTE ON FUNCTION public.submit_quiz_answer(uuid, bigint, text)
FROM anon;

GRANT EXECUTE ON FUNCTION public.submit_quiz_answer(uuid, bigint, text)
TO authenticated;
