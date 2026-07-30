-- Enforce entitlement-based paid quiz access and add a ten-question demo mode.
--
-- The existing start_quiz_attempt(bigint, text) signature is preserved.
-- "Hard" demo questions map to the existing database value "advanced".
--
-- Prerequisite:
--   20260725120000_launch_subject_catalogue.sql
--
-- Rollback:
--   supabase/rollbacks/20260725121000_gate_quiz_access_and_enable_demo.sql

DO $guard$
BEGIN
    IF pg_catalog.to_regprocedure(
        'public.get_subject_catalogue()'
    ) IS NULL
       OR pg_catalog.to_regclass('public.user_entitlements') IS NULL
       OR pg_catalog.to_regprocedure(
           'public.start_quiz_attempt(bigint,text)'
       ) IS NULL THEN
        RAISE EXCEPTION
            'Deploy the catalogue migration and existing quiz RPCs first';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.quiz_mode_config
        WHERE test_mode = 'demo'
    ) THEN
        RAISE EXCEPTION
            'Demo mode already exists; audit it before deployment';
    END IF;
END;
$guard$;

DO $constraints$
DECLARE
    v_constraint record;
BEGIN
    FOR v_constraint IN
        SELECT constraint_record.conname
        FROM pg_catalog.pg_constraint AS constraint_record
        WHERE constraint_record.conrelid =
            'public.quiz_mode_config'::regclass
          AND constraint_record.contype = 'c'
          AND pg_catalog.pg_get_constraintdef(
              constraint_record.oid
          ) ILIKE '%test_mode%'
    LOOP
        EXECUTE pg_catalog.format(
            'ALTER TABLE public.quiz_mode_config DROP CONSTRAINT %I',
            v_constraint.conname
        );
    END LOOP;

    FOR v_constraint IN
        SELECT constraint_record.conname
        FROM pg_catalog.pg_constraint AS constraint_record
        WHERE constraint_record.conrelid =
            'public.quiz_attempts'::regclass
          AND constraint_record.contype = 'c'
          AND pg_catalog.pg_get_constraintdef(
              constraint_record.oid
          ) ILIKE '%test_mode%'
    LOOP
        EXECUTE pg_catalog.format(
            'ALTER TABLE public.quiz_attempts DROP CONSTRAINT %I',
            v_constraint.conname
        );
    END LOOP;
END;
$constraints$;

ALTER TABLE public.quiz_mode_config
ADD CONSTRAINT quiz_mode_config_test_mode_check
CHECK (
    test_mode IN ('practice', 'mock', 'proctored_mock', 'demo')
);

ALTER TABLE public.quiz_attempts
ADD CONSTRAINT quiz_attempts_test_mode_check
CHECK (
    test_mode IN ('practice', 'mock', 'proctored_mock', 'demo')
);

INSERT INTO public.quiz_mode_config (
    test_mode,
    question_count,
    maximum_attempts,
    time_limit_minutes,
    feedback_mode,
    fullscreen_required,
    camera_required,
    microphone_required,
    violation_logging_required,
    is_active
)
VALUES (
    'demo',
    10,
    5,
    30,
    'immediate',
    false,
    false,
    false,
    false,
    true
);

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
    v_user_id uuid := auth.uid();
    v_question_count integer;
    v_maximum_attempts integer;
    v_time_limit_minutes integer;
    v_feedback_mode text;
    v_mode_is_active boolean;
    v_demo_limit integer;
    v_demo_available boolean;
    v_existing_attempt_id uuid;
    v_existing_attempt_number integer;
    v_attempt_id uuid;
    v_attempt_number integer;
    v_existing_attempt_count integer;
    v_available_question_count integer;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'You must be signed in to start a quiz.';
    END IF;

    -- The row lock serializes attempt creation for this learner and closes the
    -- concurrent-request gap in the existing attempt-limit check.
    PERFORM 1
    FROM public.profiles AS profile_record
    WHERE profile_record.id = v_user_id
      AND profile_record.status = 'active'
    FOR UPDATE;

    IF NOT FOUND THEN
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

    SELECT
        subject_record.demo_question_limit,
        subject_record.is_demo_available
    INTO
        v_demo_limit,
        v_demo_available
    FROM public.subjects AS subject_record
    WHERE subject_record.id = p_subject_id
      AND subject_record.is_active = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'The selected subject is not currently available.';
    END IF;

    IF p_test_mode = 'demo' THEN
        IF v_demo_available IS NOT TRUE OR v_demo_limit < 1 THEN
            RAISE EXCEPTION
                'A free demo is not available for this subject.';
        END IF;

        v_question_count := LEAST(v_question_count, v_demo_limit);
    ELSIF NOT EXISTS (
        SELECT 1
        FROM public.user_entitlements AS entitlement_record
        WHERE entitlement_record.user_id = v_user_id
          AND entitlement_record.subject_id = p_subject_id
          AND entitlement_record.status = 'active'
          AND entitlement_record.valid_from <= clock_timestamp()
          AND (
              entitlement_record.valid_until IS NULL
              OR entitlement_record.valid_until > clock_timestamp()
          )
    ) THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE =
                'Purchase or obtain access to this subject before starting the test.';
    END IF;

    SELECT COUNT(*)
    INTO v_available_question_count
    FROM public.questions AS question_record
    WHERE question_record.subject_id = p_subject_id
      AND question_record.is_active = true
      AND (
          p_test_mode <> 'demo'
          OR question_record.difficulty_level = 'advanced'
      );

    IF v_available_question_count < v_question_count THEN
        IF p_test_mode = 'demo' THEN
            RAISE EXCEPTION
                'This subject does not yet contain % active advanced questions for the demo.',
                v_question_count;
        END IF;

        RAISE EXCEPTION
            'This subject does not contain enough active questions for % mode.',
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
        ROW_NUMBER() OVER (
            ORDER BY selected_question.random_order
        )::integer
    FROM (
        SELECT
            question_record.id,
            random() AS random_order
        FROM public.questions AS question_record
        WHERE question_record.subject_id = p_subject_id
          AND question_record.is_active = true
          AND (
              p_test_mode <> 'demo'
              OR question_record.difficulty_level = 'advanced'
          )
        ORDER BY random_order
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

COMMENT ON FUNCTION public.start_quiz_attempt(bigint, text) IS
    'Starts or resumes an entitlement-gated quiz; demo mode selects active advanced questions and preserves the existing RPC signature.';

NOTIFY pgrst, 'reload schema';
