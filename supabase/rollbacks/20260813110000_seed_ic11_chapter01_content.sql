-- Remove only the governed IC11 Chapter 1 resources and flashcards.
-- Topic hierarchy and learner history are preserved.

BEGIN;

DO $guard$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM public.user_learning_activity AS activity_record
        JOIN public.learning_resources AS resource_record
          ON resource_record.id = activity_record.reference_id
        WHERE pg_catalog.upper(resource_record.code) LIKE 'LR-IC11-C01-T__-___'
          AND activity_record.activity_type = 'resource_opened'
    ) THEN
        RAISE EXCEPTION
            'IC11 Chapter 1 resources have learner activity. Preserve history and do not use this rollback.';
    END IF;
END;
$guard$;

DELETE FROM public.learning_resources AS resource_record
WHERE pg_catalog.upper(resource_record.code) LIKE 'LR-IC11-C01-T__-___';

DELETE FROM public.flashcards AS flashcard_record
WHERE pg_catalog.upper(flashcard_record.code) LIKE 'FC-IC11-C01-T__-___';

COMMIT;
