-- Incremental migration for projects that already applied
-- 20260913140000_add_duration_pricing_plans.sql.

CREATE OR REPLACE FUNCTION public.get_my_cart_with_plans()
RETURNS TABLE (
    cart_id uuid,
    subject_id bigint,
    subject_code text,
    subject_title text,
    unit_price numeric,
    currency_code text,
    duration_days integer,
    added_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id uuid := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Sign in to view your cart.';
    END IF;

    RETURN QUERY
    SELECT c.id, s.id::bigint, s.code, s.title, i.unit_price,
        i.currency_code, i.duration_days, i.created_at
    FROM public.carts AS c
    JOIN public.cart_items AS i ON i.cart_id = c.id
    JOIN public.subjects AS s ON s.id = i.subject_id
    WHERE c.user_id = v_user_id AND c.status = 'active'
    ORDER BY i.created_at;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_my_cart_with_plans()
FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_my_cart_with_plans()
TO authenticated;

NOTIFY pgrst, 'reload schema';
