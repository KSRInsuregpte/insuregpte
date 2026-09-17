-- Separate demo and practice attempt numbering at the database boundary.
-- The legacy constraint omitted test_mode and incorrectly treated demo attempt 1
-- as a duplicate of practice attempt 1.

ALTER TABLE public.quiz_attempts
DROP CONSTRAINT IF EXISTS quiz_attempts_user_subject_attempt_unique;

ALTER TABLE public.quiz_attempts
DROP CONSTRAINT IF EXISTS uq_quiz_attempts_user_subject_attempt_number;

ALTER TABLE public.quiz_attempts
ADD CONSTRAINT quiz_attempts_user_subject_mode_attempt_unique
UNIQUE (user_id, subject_id, test_mode, attempt_number);

COMMENT ON CONSTRAINT quiz_attempts_user_subject_mode_attempt_unique
ON public.quiz_attempts IS
    'Keeps attempt numbering independent for each user, subject, and quiz mode.';
