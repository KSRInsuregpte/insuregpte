-- Follow-up for the already-applied payment boundary migration.

CREATE OR REPLACE FUNCTION public.set_payment_provider_order(
    p_order_id uuid,
    p_provider_order_id text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
    IF nullif(btrim(p_provider_order_id), '') IS NULL THEN
        RAISE EXCEPTION 'A provider order ID is required.';
    END IF;
    UPDATE public.payment_orders
    SET provider_order_id = btrim(p_provider_order_id),
        updated_at = clock_timestamp()
    WHERE id = p_order_id AND status = 'pending';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pending payment order was not found.';
    END IF;
END;
$function$;

REVOKE ALL ON FUNCTION public.set_payment_provider_order(uuid,text)
FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.set_payment_provider_order(uuid,text)
TO service_role;

NOTIFY pgrst, 'reload schema';
