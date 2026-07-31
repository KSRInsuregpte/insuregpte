-- Verify that every approved expanded bulk-import entity can be written to
-- the existing administrator audit table. Test rows use an explicit negative
-- identity and a PL/pgSQL subtransaction so neither rows nor sequence changes
-- survive verification.
--
-- Expected result: Success. No rows returned

DO $verification$
DECLARE
    v_actor uuid;
    v_constraint_definition text;
    v_entity_type text;
    v_test_key text;
BEGIN
    IF pg_catalog.to_regclass('public.admin_audit_events') IS NULL THEN
        RAISE EXCEPTION
            'public.admin_audit_events is missing.';
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
            'The administrator audit entity-type constraint is missing.';
    END IF;

    SELECT auth_user.id
    INTO v_actor
    FROM auth.users AS auth_user
    ORDER BY auth_user.created_at
    LIMIT 1;

    IF v_actor IS NULL THEN
        RAISE EXCEPTION
            'At least one Auth user is required for audit verification.';
    END IF;

    FOREACH v_entity_type IN ARRAY ARRAY[
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
    ]
    LOOP
        IF pg_catalog.strpos(
            v_constraint_definition,
            pg_catalog.quote_literal(v_entity_type)
        ) = 0 THEN
            RAISE EXCEPTION
                'Audit entity type % is missing from the constraint.',
                v_entity_type;
        END IF;

        v_test_key := '__audit_type_verification__' || v_entity_type;

        BEGIN
            INSERT INTO public.admin_audit_events (
                id,
                actor_user_id,
                action,
                entity_type,
                entity_key,
                change_summary
            )
            OVERRIDING SYSTEM VALUE
            VALUES (
                -9223372036854775807,
                v_actor,
                'update',
                v_entity_type,
                v_test_key,
                pg_catalog.jsonb_build_object('verification', true)
            );

            RAISE EXCEPTION 'Rollback verification row'
                USING ERRCODE = 'P0001';
        EXCEPTION
            WHEN SQLSTATE 'P0001' THEN
                NULL;
        END;
    END LOOP;

    IF EXISTS (
        SELECT 1
        FROM public.admin_audit_events AS audit_event
        WHERE audit_event.entity_key LIKE
              '__audit_type_verification__%'
    ) THEN
        RAISE EXCEPTION
            'A temporary administrator audit verification row was retained.';
    END IF;
END;
$verification$;
