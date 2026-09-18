-- Provider-neutral payment boundary.
-- A trusted server-side payment adapter must verify the provider signature and
-- then call verify_payment_webhook with the provider's normalized result.

DO $guard$
BEGIN
    IF pg_catalog.to_regclass('public.carts') IS NULL
       OR pg_catalog.to_regclass('public.cart_items') IS NULL
       OR pg_catalog.to_regclass('public.user_entitlements') IS NULL THEN
        RAISE EXCEPTION 'Cart and entitlement tables must exist first';
    END IF;
END;
$guard$;

CREATE TABLE IF NOT EXISTS public.payment_orders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id),
    cart_id uuid NOT NULL REFERENCES public.carts(id),
    provider text NOT NULL,
    provider_order_id text,
    status text NOT NULL DEFAULT 'pending',
    currency_code text NOT NULL,
    amount numeric(12,2) NOT NULL,
    cart_snapshot jsonb NOT NULL,
    provider_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    paid_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT payment_orders_status_check
        CHECK (status IN ('pending', 'paid', 'failed', 'refunded', 'cancelled')),
    CONSTRAINT payment_orders_amount_check CHECK (amount > 0),
    CONSTRAINT payment_orders_provider_check CHECK (length(btrim(provider)) BETWEEN 2 AND 40),
    CONSTRAINT payment_orders_provider_order_unique UNIQUE (provider, provider_order_id)
);

CREATE INDEX IF NOT EXISTS payment_orders_user_created_idx
    ON public.payment_orders (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.payment_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    provider text NOT NULL,
    provider_event_id text NOT NULL,
    provider_order_id text,
    event_type text NOT NULL,
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    processed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT payment_events_provider_event_unique UNIQUE (provider, provider_event_id)
);

REVOKE ALL ON TABLE public.payment_orders, public.payment_events
FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.create_payment_order(p_provider text)
RETURNS TABLE (
    order_id uuid,
    provider text,
    currency_code text,
    amount numeric,
    cart_snapshot jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id uuid := auth.uid();
    v_cart_id uuid;
    v_currency text;
    v_amount numeric(12,2);
    v_snapshot jsonb;
    v_order_id uuid;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Sign in before checkout.';
    END IF;
    IF lower(btrim(coalesce(p_provider, ''))) NOT IN ('razorpay') THEN
        RAISE EXCEPTION 'The selected payment provider is not enabled.';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = v_user_id AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'Your account is not active.';
    END IF;

    SELECT c.id, c.currency_code
    INTO v_cart_id, v_currency
    FROM public.carts c
    WHERE c.user_id = v_user_id AND c.status = 'active'
    ORDER BY c.created_at LIMIT 1 FOR UPDATE;
    IF v_cart_id IS NULL THEN
        RAISE EXCEPTION 'Your cart is empty.';
    END IF;

    SELECT sum(i.unit_price),
           jsonb_agg(jsonb_build_object(
               'subject_id', i.subject_id,
               'pricing_plan_id', i.pricing_plan_id,
               'duration_days', i.duration_days,
               'unit_price', i.unit_price,
               'currency_code', i.currency_code
           ) ORDER BY i.subject_id)
    INTO v_amount, v_snapshot
    FROM public.cart_items i
    WHERE i.cart_id = v_cart_id;
    IF v_amount IS NULL OR v_amount <= 0 THEN
        RAISE EXCEPTION 'Your cart is empty.';
    END IF;

    INSERT INTO public.payment_orders (
        user_id, cart_id, provider, status, currency_code, amount, cart_snapshot
    )
    VALUES (
        v_user_id, v_cart_id, lower(btrim(p_provider)), 'pending',
        v_currency, v_amount, coalesce(v_snapshot, '[]'::jsonb)
    )
    RETURNING id INTO v_order_id;

    RETURN QUERY SELECT v_order_id, lower(btrim(p_provider)), v_currency,
        v_amount, coalesce(v_snapshot, '[]'::jsonb);
END;
$function$;

REVOKE ALL ON FUNCTION public.create_payment_order(text)
FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.create_payment_order(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.verify_payment_webhook(
    p_provider text,
    p_provider_event_id text,
    p_provider_order_id text,
    p_event_type text,
    p_payment_status text,
    p_provider_payload jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_event_id uuid;
    v_order public.payment_orders%ROWTYPE;
    v_item jsonb;
    v_valid_from timestamptz := clock_timestamp();
BEGIN
    IF lower(btrim(coalesce(p_provider, ''))) <> 'razorpay'
       OR nullif(btrim(p_provider_event_id), '') IS NULL
       OR nullif(btrim(p_provider_order_id), '') IS NULL THEN
        RAISE EXCEPTION 'Invalid verified payment event.';
    END IF;

    INSERT INTO public.payment_events (
        provider, provider_event_id, provider_order_id, event_type, payload
    ) VALUES (
        'razorpay', btrim(p_provider_event_id), btrim(p_provider_order_id),
        btrim(p_event_type), coalesce(p_provider_payload, '{}'::jsonb)
    )
    ON CONFLICT (provider, provider_event_id) DO NOTHING
    RETURNING id INTO v_event_id;

    IF v_event_id IS NULL THEN
        SELECT id INTO v_event_id FROM public.payment_events
        WHERE provider = 'razorpay' AND provider_event_id = btrim(p_provider_event_id);
        RETURN v_event_id;
    END IF;

    SELECT * INTO v_order
    FROM public.payment_orders
    WHERE provider = 'razorpay' AND provider_order_id = btrim(p_provider_order_id)
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Payment order was not found.';
    END IF;

    IF lower(coalesce(p_payment_status, '')) = 'paid' THEN
        IF v_order.status = 'paid' THEN
            RETURN v_event_id;
        END IF;

        UPDATE public.payment_orders
        SET status = 'paid', paid_at = v_valid_from,
            provider_payload = coalesce(p_provider_payload, '{}'::jsonb),
            updated_at = v_valid_from
        WHERE id = v_order.id;

        FOR v_item IN SELECT * FROM jsonb_array_elements(v_order.cart_snapshot)
        LOOP
            INSERT INTO public.user_entitlements (
                user_id, subject_id, access_type, status,
                valid_from, valid_until, source_reference
            ) VALUES (
                v_order.user_id,
                (v_item ->> 'subject_id')::bigint,
                'purchase', 'active', v_valid_from,
                v_valid_from + ((v_item ->> 'duration_days')::integer || ' days')::interval,
                'payment:' || v_order.id::text
            )
            ON CONFLICT DO NOTHING;
        END LOOP;

        UPDATE public.carts SET status = 'converted', updated_at = v_valid_from
        WHERE id = v_order.cart_id AND status = 'active';
    ELSE
        UPDATE public.payment_orders
        SET status = CASE WHEN lower(coalesce(p_payment_status, '')) = 'refunded'
                          THEN 'refunded' ELSE 'failed' END,
            provider_payload = coalesce(p_provider_payload, '{}'::jsonb),
            updated_at = v_valid_from
        WHERE id = v_order.id AND status = 'pending';
    END IF;

    UPDATE public.payment_events SET processed_at = v_valid_from WHERE id = v_event_id;
    RETURN v_event_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.verify_payment_webhook(text,text,text,text,text,jsonb)
FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.verify_payment_webhook(text,text,text,text,text,jsonb)
TO service_role;

COMMENT ON FUNCTION public.verify_payment_webhook(text,text,text,text,text,jsonb) IS
    'Finalizes only a trusted normalized payment event; the provider signature must be verified by the payment adapter before this RPC is called.';

NOTIFY pgrst, 'reload schema';
