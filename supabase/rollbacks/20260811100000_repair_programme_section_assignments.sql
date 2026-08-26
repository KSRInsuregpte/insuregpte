-- Deliberate no-op rollback.
--
-- The migration repairs invalid foreign-key combinations without deleting
-- records. Restoring mismatched programme-section assignments would recreate
-- the administrator save failure, so the corrected references are preserved.

DO $rollback$
BEGIN
    RAISE NOTICE
        'Programme-section assignment repairs are intentionally preserved.';
END;
$rollback$;
