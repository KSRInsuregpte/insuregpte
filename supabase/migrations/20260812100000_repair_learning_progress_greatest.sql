-- Repair Learning progress writes after trial runtime testing found that
-- GREATEST was incorrectly schema-qualified as pg_catalog.greatest.
-- PostgreSQL implements GREATEST as a special SQL expression, not as a
-- pg_catalog function. No learner or content row is changed.
--
-- Prerequisite:
--   20260811150000_build_learning_module.sql
--
-- Rollback:
--   supabase/rollbacks/20260812100000_repair_learning_progress_greatest.sql

BEGIN;

DO $repair$
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
            RAISE EXCEPTION
                'Required Learning progress function % is missing.',
                v_signature;
        END IF;

        v_definition := pg_catalog.pg_get_functiondef(v_oid);
        IF pg_catalog.strpos(v_definition, 'pg_catalog.greatest(') = 0 THEN
            RAISE EXCEPTION
                'Function % does not contain the audited qualification defect; review before deployment.',
                v_signature;
        END IF;

        EXECUTE pg_catalog.replace(
            v_definition,
            'pg_catalog.greatest(',
            'GREATEST('
        );
    END LOOP;
END;
$repair$;

COMMIT;
