-- Expected result: Success. No rows returned.
-- Run after 20260731120000_expand_admin_bulk_import.sql.

DO $verification$
DECLARE
    v_signature text;
    v_definition text;
    v_constraint_definition text;
BEGIN
    FOREACH v_signature IN ARRAY ARRAY[
        'public.admin_bulk_import(text,jsonb)',
        'public.admin_save_academic_content(text,jsonb)',
        'public.admin_save_entitlement(jsonb)',
        'public.admin_save_exam_information(jsonb)'
    ]
    LOOP
        IF pg_catalog.to_regprocedure(v_signature) IS NULL THEN
            RAISE EXCEPTION 'Required function % is missing.',
                v_signature;
        END IF;

        IF pg_catalog.has_function_privilege(
            'anon',
            v_signature,
            'EXECUTE'
        ) OR pg_catalog.has_function_privilege(
            'service_role',
            v_signature,
            'EXECUTE'
        ) THEN
            RAISE EXCEPTION
                'Only authenticated administrators may reach %.',
                v_signature;
        END IF;

        IF NOT pg_catalog.has_function_privilege(
            'authenticated',
            v_signature,
            'EXECUTE'
        ) THEN
            RAISE EXCEPTION
                'authenticated cannot execute guarded function %.',
                v_signature;
        END IF;
    END LOOP;

    SELECT pg_catalog.pg_get_functiondef(
        pg_catalog.to_regprocedure(
            'public.admin_bulk_import(text,jsonb)'
        )
    )
    INTO v_definition;

    IF v_definition NOT LIKE '%public.fn_is_admin()%'
       OR v_definition NOT LIKE
          '%public.admin_save_academic_content(%'
       OR v_definition NOT LIKE
          '%public.admin_save_entitlement(%'
       OR v_definition NOT LIKE
          '%public.admin_save_exam_information(%'
       OR v_definition NOT LIKE
          '%public.admin_save_subject(v_row)%'
       OR v_definition NOT LIKE
          '%public.admin_save_question(v_payload)%'
       OR v_definition NOT LIKE
          '%public.admin_set_user_status(%'
       OR v_definition NOT LIKE '%BETWEEN 1 AND 250%'
       OR v_definition NOT LIKE '%exam_information%'
       OR v_definition NOT LIKE '%learning_resources%'
       OR v_definition NOT LIKE '%entitlements%' THEN
        RAISE EXCEPTION
            'The expanded bulk coordinator does not preserve the approved audited routes.';
    END IF;

    SELECT pg_catalog.pg_get_functiondef(
        pg_catalog.to_regprocedure(
            'public.admin_save_academic_content(text,jsonb)'
        )
    )
    INTO v_definition;

    IF v_definition NOT LIKE '%SECURITY DEFINER%'
       OR v_definition NOT LIKE '%SET search_path TO%'
       OR v_definition NOT LIKE '%public.fn_is_admin()%'
       OR v_definition NOT LIKE
          '%INSERT INTO public.admin_audit_events%'
       OR v_definition NOT LIKE '%qualification_levels%'
       OR v_definition NOT LIKE '%subject_modules%'
       OR v_definition NOT LIKE '%subject_chapters%'
       OR v_definition NOT LIKE '%subject_topics%'
       OR v_definition NOT LIKE '%learning_resource_types%'
       OR v_definition NOT LIKE '%learning_resources%'
       OR v_definition NOT LIKE '%flashcards%' THEN
        RAISE EXCEPTION
            'Academic-content save function is not guarded, audited, or complete.';
    END IF;

    SELECT pg_catalog.pg_get_functiondef(
        pg_catalog.to_regprocedure(
            'public.admin_save_entitlement(jsonb)'
        )
    )
    INTO v_definition;

    IF v_definition NOT LIKE '%public.fn_is_admin()%'
       OR v_definition NOT LIKE
          '%profile_record.status = ''active''%'
       OR v_definition NOT LIKE
          '%Payment or subscription entitlements cannot be changed%'
       OR v_definition NOT LIKE
          '%INSERT INTO public.admin_audit_events%'
       OR v_definition LIKE '%INSERT INTO auth.users%'
       OR v_definition LIKE '%UPDATE auth.users%' THEN
        RAISE EXCEPTION
            'Entitlement import does not preserve the approved access boundary.';
    END IF;

    SELECT pg_catalog.pg_get_functiondef(
        pg_catalog.to_regprocedure(
            'public.admin_save_exam_information(jsonb)'
        )
    )
    INTO v_definition;

    IF v_definition NOT LIKE '%official_notice%'
       OR v_definition NOT LIKE
          '%programme.exam_authority_id = v_exam_authority_id%'
       OR v_definition NOT LIKE
          '%section.training_programme_id =%' THEN
        RAISE EXCEPTION
            'Examination-information save contract is missing the approved notice or hierarchy validation.';
    END IF;

    SELECT pg_catalog.pg_get_constraintdef(constraint_record.oid)
    INTO v_constraint_definition
    FROM pg_catalog.pg_constraint AS constraint_record
    WHERE constraint_record.conrelid =
        'public.regulatory_academic_publications'::regclass
      AND constraint_record.conname =
        'regulatory_academic_publications_document_type_check';

    IF v_constraint_definition NOT LIKE '%official_notice%' THEN
        RAISE EXCEPTION
            'The existing examination-information table does not accept official notices.';
    END IF;

    BEGIN
        PERFORM public.admin_save_academic_content(
            'qualification_levels',
            '{}'::jsonb
        );
        RAISE EXCEPTION
            'Unauthenticated academic save was accepted.';
    EXCEPTION
        WHEN SQLSTATE 'PT403' THEN
            NULL;
    END;

    BEGIN
        PERFORM public.admin_save_entitlement('{}'::jsonb);
        RAISE EXCEPTION
            'Unauthenticated entitlement save was accepted.';
    EXCEPTION
        WHEN SQLSTATE 'PT403' THEN
            NULL;
    END;
END;
$verification$;
