-- Repair the existing safety-event helper without changing its signature.
--
-- The original safety-system migration listed ten INSERT target columns but
-- supplied only nine expressions. PostgreSQL compiles that statement when the
-- function is first executed, so catalogue-only verification did not expose
-- the defect.
--
-- Rollback:
-- supabase/rollbacks/20260803100000_repair_security_event_insert.sql

DO $guard$
BEGIN
    IF to_regclass('public.security_events') IS NULL
       OR to_regprocedure(
           'public.fn_insert_security_event(text,text,uuid,text,text,jsonb,text,timestamp with time zone)'
       ) IS NULL THEN
        RAISE EXCEPTION
            'Deploy the safety monitoring migration before this repair';
    END IF;
END;
$guard$;

CREATE OR REPLACE FUNCTION public.fn_insert_security_event(
    p_event_type text,
    p_severity text,
    p_user_id uuid,
    p_source text,
    p_dedupe_key text,
    p_evidence_summary jsonb,
    p_recommended_action text,
    p_occurred_at timestamptz DEFAULT clock_timestamp()
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_event_id bigint;
BEGIN
    INSERT INTO public.security_events (
        event_type,
        severity,
        user_id,
        source,
        dedupe_key,
        evidence_summary,
        recommended_action,
        occurred_at,
        last_seen_at,
        updated_at
    )
    VALUES (
        lower(btrim(p_event_type)),
        lower(btrim(p_severity)),
        p_user_id,
        left(btrim(p_source), 100),
        nullif(left(btrim(coalesce(p_dedupe_key, '')), 240), ''),
        coalesce(p_evidence_summary, '{}'::jsonb),
        nullif(left(btrim(coalesce(p_recommended_action, '')), 1000), ''),
        coalesce(p_occurred_at, clock_timestamp()),
        clock_timestamp(),
        clock_timestamp()
    )
    ON CONFLICT (dedupe_key) DO UPDATE
    SET last_seen_at = clock_timestamp(),
        occurrence_count = public.security_events.occurrence_count + 1,
        evidence_summary = EXCLUDED.evidence_summary,
        updated_at = clock_timestamp()
    RETURNING id INTO v_event_id;

    RETURN v_event_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_insert_security_event(
    text,text,uuid,text,text,jsonb,text,timestamptz
) FROM PUBLIC, anon, authenticated, service_role;

COMMENT ON FUNCTION public.fn_insert_security_event(
    text,text,uuid,text,text,jsonb,text,timestamptz
) IS
    'Internal privacy-safe safety-event insert and deduplication helper.';

NOTIFY pgrst, 'reload schema';
