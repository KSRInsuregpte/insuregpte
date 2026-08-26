-- Restore the pre-repair Learning progress definitions.
-- This rollback is included for traceability but reintroduces the runtime
-- completion failure and should be used only while rolling back the full
-- Learning Module trial release.

BEGIN;

DO $rollback$
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
        IF pg_catalog.strpos(v_definition, 'GREATEST(') = 0 THEN
            RAISE EXCEPTION
                'Function % does not contain the corrected expression; review before rollback.',
                v_signature;
        END IF;

        EXECUTE pg_catalog.replace(
            v_definition,
            'GREATEST(',
            'pg_catalog.greatest('
        );
    END LOOP;
END;
$rollback$;

COMMIT;
