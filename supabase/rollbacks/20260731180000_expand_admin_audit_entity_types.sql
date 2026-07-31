-- Restore the pre-bulk-upload administrator audit entity-type constraint.
--
-- This rollback refuses to discard compatibility while audit history for a
-- newly supported type exists. Audit rows must never be deleted merely to
-- force a rollback.

BEGIN;

DO $guard$
BEGIN
    IF pg_catalog.to_regclass('public.admin_audit_events') IS NULL THEN
        RAISE EXCEPTION
            'Required existing table public.admin_audit_events is missing.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_constraint AS constraint_record
        WHERE constraint_record.conrelid =
                  'public.admin_audit_events'::pg_catalog.regclass
          AND constraint_record.conname =
                  'admin_audit_events_entity_type_check'
          AND constraint_record.contype = 'c'
    ) THEN
        RAISE EXCEPTION
            'The administrator audit entity-type constraint is missing.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.admin_audit_events AS audit_event
        WHERE audit_event.entity_type IN (
            'qualification_levels',
            'exam_authorities',
            'training_programmes',
            'programme_sections',
            'modules',
            'chapters',
            'topics',
            'learning_resource_types',
            'learning_resources',
            'flashcards',
            'entitlement'
        )
    ) THEN
        RAISE EXCEPTION
            'New administrator audit history exists; preserve it and use a forward correction.';
    END IF;
END;
$guard$;

ALTER TABLE public.admin_audit_events
DROP CONSTRAINT admin_audit_events_entity_type_check;

ALTER TABLE public.admin_audit_events
ADD CONSTRAINT admin_audit_events_entity_type_check
CHECK (
    entity_type IN (
        'subject',
        'question',
        'user',
        'exam_information'
    )
);

COMMENT ON CONSTRAINT admin_audit_events_entity_type_check
ON public.admin_audit_events IS NULL;

COMMIT;
