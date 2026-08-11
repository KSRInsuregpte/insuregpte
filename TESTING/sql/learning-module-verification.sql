-- Run after 20260811150000_build_learning_module.sql in the trial project.
-- This verification is read-only and returns no learner or content values.

DO $verify$
DECLARE
    v_signature text;
    v_oid oid;
    v_security_definer boolean;
    v_definition text;
    v_relation text;
BEGIN
    FOREACH v_signature IN ARRAY ARRAY[
        'public.get_subject_hierarchy(bigint)',
        'public.get_modules_by_subject(bigint)',
        'public.get_chapters_by_module(integer)',
        'public.get_topics_by_chapter(integer)',
        'public.get_topic_details(integer)',
        'public.get_learning_resources(integer)',
        'public.get_flashcards(integer)',
        'public.record_learning_activity(integer,text,bigint,integer,numeric)',
        'public.get_resume_learning(bigint)',
        'public.get_recent_activity(integer)',
        'public.get_topic_completion(integer)',
        'public.get_learning_statistics(bigint)',
        'public.upsert_user_topic_progress(uuid,integer,text,numeric,integer)'
    ]
    LOOP
        v_oid := pg_catalog.to_regprocedure(v_signature);
        IF v_oid IS NULL THEN
            RAISE EXCEPTION 'Required Learning function % is missing.', v_signature;
        END IF;
        SELECT procedure_record.prosecdef,
               pg_catalog.pg_get_functiondef(procedure_record.oid)
        INTO STRICT v_security_definer, v_definition
        FROM pg_catalog.pg_proc AS procedure_record
        WHERE procedure_record.oid = v_oid
          AND procedure_record.prosecdef = true;
        IF v_definition NOT LIKE '%auth.uid()%' THEN
            RAISE EXCEPTION 'Learning function % does not validate auth.uid().', v_signature;
        END IF;
        IF NOT pg_catalog.has_function_privilege(
            'authenticated', pg_catalog.to_regprocedure(v_signature), 'EXECUTE'
        ) OR pg_catalog.has_function_privilege(
            'anon', pg_catalog.to_regprocedure(v_signature), 'EXECUTE'
        ) THEN
            RAISE EXCEPTION 'Learning function % has incorrect browser grants.', v_signature;
        END IF;
    END LOOP;

    IF pg_catalog.pg_get_functiondef(pg_catalog.to_regprocedure(
        'public.upsert_user_topic_progress(uuid,integer,text,numeric,integer)'
    )) NOT LIKE '%p_user_id IS DISTINCT FROM v_user_id%' THEN
        RAISE EXCEPTION 'The legacy progress ownership repair is missing.';
    END IF;

    FOREACH v_relation IN ARRAY ARRAY[
        'subject_modules', 'subject_chapters', 'subject_topics',
        'learning_resource_types', 'learning_resources', 'flashcards',
        'user_topic_progress', 'user_learning_activity'
    ]
    LOOP
        IF EXISTS (
            SELECT 1
            FROM information_schema.role_table_grants AS grant_record
            WHERE grant_record.table_schema = 'public'
              AND grant_record.table_name = v_relation
              AND grant_record.grantee IN ('anon', 'authenticated')
        ) THEN
            RAISE EXCEPTION 'Direct browser grant remains on public.%.', v_relation;
        END IF;
    END LOOP;
END;
$verify$;

SELECT
    procedure_record.proname AS function_name,
    pg_catalog.pg_get_function_identity_arguments(procedure_record.oid)
        AS arguments,
    pg_catalog.pg_get_function_result(procedure_record.oid) AS result,
    procedure_record.prosecdef AS security_definer,
    pg_catalog.has_function_privilege(
        'authenticated', procedure_record.oid, 'EXECUTE'
    ) AS authenticated_execute,
    pg_catalog.has_function_privilege(
        'anon', procedure_record.oid, 'EXECUTE'
    ) AS anonymous_execute
FROM pg_catalog.pg_proc AS procedure_record
JOIN pg_catalog.pg_namespace AS namespace_record
  ON namespace_record.oid = procedure_record.pronamespace
WHERE namespace_record.nspname = 'public'
  AND procedure_record.proname IN (
      'get_subject_hierarchy', 'get_modules_by_subject',
      'get_chapters_by_module', 'get_topics_by_chapter',
      'get_topic_details', 'get_learning_resources', 'get_flashcards',
      'record_learning_activity', 'get_resume_learning',
      'get_recent_activity', 'get_topic_completion',
      'get_learning_statistics', 'upsert_user_topic_progress'
  )
ORDER BY procedure_record.proname;
