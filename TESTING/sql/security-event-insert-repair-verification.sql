-- Run after:
-- supabase/migrations/20260803100000_repair_security_event_insert.sql
--
-- Expected result: Success. No rows returned.
-- This verification executes both INSERT and deduplication paths inside a
-- transaction and rolls the test records back before completion.

BEGIN;

DO $verification$
DECLARE
    v_dedupe_key text := 'repair-verification:'
        || pg_backend_pid()::text || ':' || txid_current()::text;
    v_first_event_id bigint;
    v_second_event_id bigint;
    v_event record;
BEGIN
    IF to_regprocedure(
        'public.fn_insert_security_event(text,text,uuid,text,text,jsonb,text,timestamp with time zone)'
    ) IS NULL THEN
        RAISE EXCEPTION 'The repaired safety-event helper is missing';
    END IF;

    v_first_event_id := public.fn_insert_security_event(
        'auth_anomaly',
        'low',
        NULL,
        'repair_verification',
        v_dedupe_key,
        jsonb_build_object(
            'verification', true,
            'contains_sensitive_information', false
        ),
        'Transactional repair verification only.',
        clock_timestamp()
    );

    IF v_first_event_id IS NULL THEN
        RAISE EXCEPTION 'The safety-event helper returned no event identifier';
    END IF;

    v_second_event_id := public.fn_insert_security_event(
        'auth_anomaly',
        'low',
        NULL,
        'repair_verification',
        v_dedupe_key,
        jsonb_build_object(
            'verification', true,
            'dedupe_path', true,
            'contains_sensitive_information', false
        ),
        'Transactional repair verification only.',
        clock_timestamp()
    );

    SELECT
        event.id,
        event.occurrence_count,
        event.created_at,
        event.updated_at,
        event.last_seen_at,
        event.evidence_summary
    INTO v_event
    FROM public.security_events AS event
    WHERE event.id = v_first_event_id;

    IF v_second_event_id IS DISTINCT FROM v_first_event_id
       OR v_event.id IS NULL
       OR v_event.occurrence_count IS DISTINCT FROM 2
       OR v_event.created_at IS NULL
       OR v_event.updated_at IS NULL
       OR v_event.last_seen_at IS NULL
       OR v_event.evidence_summary ->> 'dedupe_path' IS DISTINCT FROM 'true' THEN
        RAISE EXCEPTION
            'The repaired safety-event insert or deduplication path failed';
    END IF;
END;
$verification$;

ROLLBACK;
