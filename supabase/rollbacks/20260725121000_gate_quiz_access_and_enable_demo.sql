-- Roll back entitlement-gated quiz starts and demo mode.
--
-- This rollback refuses to discard demo attempt history. If demo attempts
-- exist, archive or migrate them under an approved change before retrying.

DO $guard$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM public.quiz_attempts
        WHERE test_mode = 'demo'
    ) THEN
        RAISE EXCEPTION
            'Rollback stopped: demo quiz attempts exist and will not be deleted automatically';
    END IF;
END;
$guard$;

DELETE FROM public.quiz_mode_config
WHERE test_mode = 'demo';

ALTER TABLE public.quiz_mode_config
DROP CONSTRAINT IF EXISTS quiz_mode_config_test_mode_check;
ALTER TABLE public.quiz_mode_config
ADD CONSTRAINT quiz_mode_config_test_mode_check
CHECK (test_mode IN ('practice', 'mock', 'proctored_mock'));

ALTER TABLE public.quiz_attempts
DROP CONSTRAINT IF EXISTS quiz_attempts_test_mode_check;
ALTER TABLE public.quiz_attempts
ADD CONSTRAINT quiz_attempts_test_mode_check
CHECK (test_mode IN ('practice', 'mock', 'proctored_mock'));

CREATE OR REPLACE FUNCTION public.start_quiz_attempt(
    p_subject_id bigint,
    p_test_mode text
)
RETURNS TABLE (
    attempt_id uuid,
    attempt_number integer,
    total_questions integer,
    time_limit_minutes integer,
    feedback_mode text,
    resumed boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id uuid;
    v_question_count integer;
    v_maximum_attempts integer;
    v_time_limit_minutes integer;
    v_feedback_mode text;
    v_mode_is_active boolean;
    v_existing_attempt_id uuid;
    v_existing_attempt_number integer;
    v_attempt_id uuid;
    v_attempt_number integer;
    v_existing_attempt_count integer;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'You must be signed in to start a quiz.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE id = v_user_id
          AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'Your account is not active.';
    END IF;

    SELECT
        mode_record.question_count,
        mode_record.maximum_attempts,
        mode_record.time_limit_minutes,
        mode_record.feedback_mode,
        mode_record.is_active
    INTO
        v_question_count,
        v_maximum_attempts,
        v_time_limit_minutes,
        v_feedback_mode,
        v_mode_is_active
    FROM public.quiz_mode_config AS mode_record
    WHERE mode_record.test_mode = p_test_mode;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid test mode: %', p_test_mode;
    END IF;

    IF v_mode_is_active IS NOT TRUE THEN
        RAISE EXCEPTION
            'The selected test mode is not currently available.';
    END IF;

    IF (
        SELECT COUNT(*)
        FROM public.questions
        WHERE subject_id = p_subject_id
    ) < v_question_count THEN
        RAISE EXCEPTION
            'This subject does not contain enough questions for % mode.',
            p_test_mode;
    END IF;

    SELECT
        attempt_record.id,
        attempt_record.attempt_number
    INTO
        v_existing_attempt_id,
        v_existing_attempt_number
    FROM public.quiz_attempts AS attempt_record
    WHERE attempt_record.user_id = v_user_id
      AND attempt_record.subject_id = p_subject_id
      AND attempt_record.test_mode = p_test_mode
      AND attempt_record.status = 'in_progress'
    ORDER BY attempt_record.started_at DESC
    LIMIT 1;

    IF v_existing_attempt_id IS NOT NULL THEN
        RETURN QUERY
        SELECT
            v_existing_attempt_id,
            v_existing_attempt_number,
            v_question_count,
            v_time_limit_minutes,
            v_feedback_mode,
            true;
        RETURN;
    END IF;

    SELECT COUNT(*)
    INTO v_existing_attempt_count
    FROM public.quiz_attempts AS attempt_record
    WHERE attempt_record.user_id = v_user_id
      AND attempt_record.subject_id = p_subject_id
      AND attempt_record.test_mode = p_test_mode;

    IF v_existing_attempt_count >= v_maximum_attempts THEN
        RAISE EXCEPTION
            'You have reached the maximum permitted % attempt(s) for % mode.',
            v_maximum_attempts,
            p_test_mode;
    END IF;

    v_attempt_number := v_existing_attempt_count + 1;

    INSERT INTO public.quiz_attempts (
        user_id,
        subject_id,
        attempt_number,
        total_questions,
        status,
        test_mode,
        time_limit_minutes,
        feedback_mode,
        auto_submitted,
        violation_count
    )
    VALUES (
        v_user_id,
        p_subject_id,
        v_attempt_number,
        v_question_count,
        'in_progress',
        p_test_mode,
        v_time_limit_minutes,
        v_feedback_mode,
        false,
        0
    )
    RETURNING id INTO v_attempt_id;

    INSERT INTO public.quiz_attempt_questions (
        attempt_id,
        question_id,
        question_order
    )
    SELECT
        v_attempt_id,
        selected_question.id,
        ROW_NUMBER() OVER ()::integer
    FROM (
        SELECT question_record.id
        FROM public.questions AS question_record
        WHERE question_record.subject_id = p_subject_id
        ORDER BY random()
        LIMIT v_question_count
    ) AS selected_question;

    RETURN QUERY
    SELECT
        v_attempt_id,
        v_attempt_number,
        v_question_count,
        v_time_limit_minutes,
        v_feedback_mode,
        false;
END;
$function$;

REVOKE ALL ON FUNCTION public.start_quiz_attempt(bigint, text)
FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.start_quiz_attempt(bigint, text)
TO authenticated;

NOTIFY pgrst, 'reload schema';
