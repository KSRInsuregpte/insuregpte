-- Permit the existing administrator audit table to record every entity type
-- already supported by the audited bulk-import functions.
--
-- No table, RPC, policy, or business record is created by this migration.
-- The existing constraint is expanded in place.

BEGIN;

DO $guard$
DECLARE
    v_constraint_definition text;
    v_required_type text;
BEGIN
    IF pg_catalog.to_regclass('public.admin_audit_events') IS NULL THEN
        RAISE EXCEPTION
            'Required existing table public.admin_audit_events is missing.';
    END IF;

    IF pg_catalog.to_regprocedure(
        'public.admin_save_academic_content(text,jsonb)'
    ) IS NULL
       OR pg_catalog.to_regprocedure(
           'public.admin_save_entitlement(jsonb)'
       ) IS NULL THEN
        RAISE EXCEPTION
            'Deploy the expanded administrator bulk-import migration first.';
    END IF;

    SELECT pg_catalog.pg_get_constraintdef(constraint_record.oid)
    INTO v_constraint_definition
    FROM pg_catalog.pg_constraint AS constraint_record
    WHERE constraint_record.conrelid =
              'public.admin_audit_events'::pg_catalog.regclass
      AND constraint_record.conname =
              'admin_audit_events_entity_type_check'
      AND constraint_record.contype = 'c';

    IF v_constraint_definition IS NULL THEN
        RAISE EXCEPTION
            'The existing administrator audit entity-type constraint is missing.';
    END IF;

    FOREACH v_required_type IN ARRAY ARRAY[
        'subject',
        'question',
        'user',
        'exam_information'
    ]
    LOOP
        IF pg_catalog.strpos(
            v_constraint_definition,
            pg_catalog.quote_literal(v_required_type)
        ) = 0 THEN
            RAISE EXCEPTION
                'The existing administrator audit constraint has an unexpected definition.';
        END IF;
    END LOOP;

    IF EXISTS (
        SELECT 1
        FROM public.admin_audit_events AS audit_event
        WHERE audit_event.entity_type NOT IN (
            'subject',
            'question',
            'user',
            'exam_information',
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
            'An administrator audit row uses an unreviewed entity type.';
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
        'exam_information',
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
);

COMMENT ON CONSTRAINT admin_audit_events_entity_type_check
ON public.admin_audit_events IS
'Restricts administrator audit history to the approved portal and bulk-import entity types.';

COMMIT;
