-- Duration prices are public catalogue data; cart mutations remain authenticated
-- and continue to validate the selected plan server-side.
GRANT EXECUTE ON FUNCTION public.get_subject_pricing_plans()
TO anon, authenticated;
