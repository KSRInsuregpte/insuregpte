DROP FUNCTION IF EXISTS public.add_subject_to_cart(bigint, integer);
DROP FUNCTION IF EXISTS public.get_subject_pricing_plans();
DROP FUNCTION IF EXISTS public.get_my_cart_with_plans();
ALTER TABLE public.cart_items
    DROP CONSTRAINT IF EXISTS cart_items_pricing_plan_fk,
    DROP CONSTRAINT IF EXISTS cart_items_duration_check,
    DROP COLUMN IF EXISTS pricing_plan_id,
    DROP COLUMN IF EXISTS duration_days;
DROP TABLE IF EXISTS public.subject_pricing_plans;
NOTIFY pgrst, 'reload schema';
