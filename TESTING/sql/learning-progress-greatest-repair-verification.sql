-- Run after 20260812100000_repair_learning_progress_greatest.sql.
-- This verification is read-only and returns no learner or content data.

DO $verify$
DECLARE
    v_signature text;
    v_oid oid;
    v_definition text;
BEGIN
    FOREACH v_signature IN ARRAY ARRAY[
        'public.record_learning_activity(integer,text,bigint,integer,numeric)',
        'public.upsert_user_topic_progress(uuid,integer,text,numeric,integer)'
    ]
    LOOP
        v_oid := pg_catalog.to_regprocedure(v_signature);
        IF v_oid IS NULL THEN
            RAISE EXCEPTION 'Required function % is missing.', v_signature;
        END IF;

        v_definition := pg_catalog.pg_get_functiondef(v_oid);
        IF pg_catalog.strpos(v_definition, 'pg_catalog.greatest(') > 0 THEN
            RAISE EXCEPTION
                'The invalid pg_catalog.greatest qualification remains in %.',
                v_signature;
        END IF;
        IF pg_catalog.strpos(v_definition, 'GREATEST(') = 0 THEN
            RAISE EXCEPTION
                'The corrected GREATEST expression is missing from %.',
                v_signature;
        END IF;
        IF NOT pg_catalog.has_function_privilege(
            'authenticated', v_oid, 'EXECUTE'
        ) OR pg_catalog.has_function_privilege('anon', v_oid, 'EXECUTE') THEN
            RAISE EXCEPTION 'Function % has incorrect browser grants.', v_signature;
        END IF;
    END LOOP;
END;
$verify$;

SELECT
    procedure_record.proname AS function_name,
    pg_catalog.strpos(
        pg_catalog.pg_get_functiondef(procedure_record.oid),
        'GREATEST('
    ) > 0 AS corrected_greatest,
    pg_catalog.strpos(
        pg_catalog.pg_get_functiondef(procedure_record.oid),
        'pg_catalog.greatest('
    ) = 0 AS invalid_qualification_removed,
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
      'record_learning_activity',
      'upsert_user_topic_progress'
  )
ORDER BY procedure_record.proname;
