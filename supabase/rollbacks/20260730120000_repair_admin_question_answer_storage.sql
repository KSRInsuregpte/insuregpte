-- Safe operational rollback for the administrator correct-answer repair.
--
-- Repaired question data must not be changed back to A/B/C/D tags because the
-- quiz engine compares selected answer text with questions.correct_option.
-- If the replacement RPC must be withdrawn, freeze administrator question
-- writes and retain the scoring-compatible data. Reapply the forward migration
-- to restore administrator question editing.

BEGIN;

REVOKE EXECUTE ON FUNCTION public.admin_save_question(jsonb)
FROM authenticated;

COMMENT ON FUNCTION public.admin_save_question(jsonb) IS
    'Administrator question writes are temporarily disabled by the safe rollback; repaired answer text remains scoring-compatible.';

NOTIFY pgrst, 'reload schema';

COMMIT;
