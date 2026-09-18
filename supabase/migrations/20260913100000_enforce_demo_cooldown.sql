-- Enforce a five-minute server-side cooldown between completed demos.
-- This protects the quiz start flow even when a client bypasses browser storage.

CREATE OR REPLACE FUNCTION public.enforce_demo_cooldown()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_completed_at timestamptz;
    v_retry_after timestamptz;
BEGIN
    IF NEW.test_mode <> 'demo' THEN
        RETURN NEW;
    END IF;

    SELECT attempt_record.completed_at
    INTO v_completed_at
    FROM public.quiz_attempts AS attempt_record
    WHERE attempt_record.user_id = NEW.user_id
      AND attempt_record.subject_id = NEW.subject_id
      AND attempt_record.test_mode = 'demo'
      AND attempt_record.completed_at IS NOT NULL
      AND attempt_record.completed_at > clock_timestamp() - interval '5 minutes'
    ORDER BY attempt_record.completed_at DESC
    LIMIT 1;

    IF v_completed_at IS NOT NULL THEN
        v_retry_after := v_completed_at + interval '5 minutes';
        RAISE EXCEPTION 'This demo was completed recently. Please try again after %.',
            to_char(v_retry_after AT TIME ZONE 'Asia/Kolkata', 'HH24:MI:SS')
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS quiz_attempts_demo_cooldown ON public.quiz_attempts;

CREATE TRIGGER quiz_attempts_demo_cooldown
    BEFORE INSERT ON public.quiz_attempts
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_demo_cooldown();

REVOKE ALL ON FUNCTION public.enforce_demo_cooldown() FROM PUBLIC;

COMMENT ON FUNCTION public.enforce_demo_cooldown() IS
    'Prevents a user from starting the same subject demo within five minutes of completion.';
