-- Add the administrator-only write boundary for the global duration plans.
-- The selected plan remains the sole source of cart and purchase pricing.

DO $guard$
BEGIN
    IF pg_catalog.to_regclass('public.subject_pricing_plans') IS NULL
       OR pg_catalog.to_regclass('public.admin_audit_events') IS NULL
       OR pg_catalog.to_regprocedure('public.fn_is_admin()') IS NULL THEN
        RAISE EXCEPTION
            'Pricing plans, audit history, and administrator authorization must exist first';
    END IF;
END;
$guard$;

ALTER TABLE public.admin_audit_events
DROP CONSTRAINT IF EXISTS admin_audit_events_entity_type_check;

ALTER TABLE public.admin_audit_events
ADD CONSTRAINT admin_audit_events_entity_type_check CHECK (
    entity_type IN (
        'subject', 'question', 'user', 'exam_information',
        'qualification_levels', 'exam_authorities', 'training_programmes',
        'programme_sections', 'modules', 'chapters', 'topics',
        'learning_resource_types', 'learning_resources', 'flashcards',
        'entitlement', 'pricing_plan', 'security_event', 'enforcement_case',
        'notification_outbox'
    )
);

CREATE OR REPLACE FUNCTION public.admin_save_pricing_plan(
    p_plan jsonb
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_actor uuid := auth.uid();
    v_plan_id bigint := NULLIF(p_plan ->> 'id', '')::bigint;
    v_duration_days integer := NULLIF(p_plan ->> 'duration_days', '')::integer;
    v_price numeric(10,2) := NULLIF(p_plan ->> 'price', '')::numeric(10,2);
    v_old_price numeric(10,2);
    v_currency_code text := upper(pg_catalog.btrim(COALESCE(p_plan ->> 'currency_code', 'INR')));
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;
    IF v_plan_id IS NULL OR v_duration_days NOT IN (15, 30, 60, 90) THEN
        RAISE EXCEPTION 'A valid duration pricing plan is required.';
    END IF;
    IF v_price IS NULL OR v_price < 0 OR v_price > 99999999.99 THEN
        RAISE EXCEPTION 'Price must be between 0 and 99999999.99.';
    END IF;
    IF v_currency_code !~ '^[A-Z]{3}$' THEN
        RAISE EXCEPTION 'Currency must be a three-letter ISO code.';
    END IF;

    SELECT price INTO v_old_price
    FROM public.subject_pricing_plans
    WHERE id = v_plan_id AND duration_days = v_duration_days
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'The selected pricing plan was not found.';
    END IF;

    UPDATE public.subject_pricing_plans
    SET price = v_price,
        currency_code = v_currency_code,
        updated_at = pg_catalog.clock_timestamp()
    WHERE id = v_plan_id;

    INSERT INTO public.admin_audit_events (
        actor_user_id,
        action,
        entity_type,
        entity_key,
        change_summary
    )
    VALUES (
        v_actor,
        'update',
        'pricing_plan',
        v_plan_id::text,
        pg_catalog.jsonb_build_object(
            'duration_days', v_duration_days,
            'old_price', v_old_price,
            'new_price', v_price,
            'currency_code', v_currency_code
        )
    );

    RETURN v_plan_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_save_pricing_plan(jsonb)
FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_save_pricing_plan(jsonb)
TO authenticated;

COMMENT ON FUNCTION public.admin_save_pricing_plan(jsonb) IS
    'Updates one global duration pricing plan for administrators and records old/new values in audit history.';

NOTIFY pgrst, 'reload schema';
