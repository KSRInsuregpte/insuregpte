SELECT duration_days, price, currency_code, is_active
FROM public.subject_pricing_plans
ORDER BY duration_days;

SELECT
    has_table_privilege('anon', 'public.subject_pricing_plans', 'SELECT') AS anon_table_select,
    has_table_privilege('authenticated', 'public.subject_pricing_plans', 'SELECT') AS authenticated_table_select,
    has_function_privilege('anon', 'public.get_subject_pricing_plans()', 'EXECUTE') AS anon_plan_rpc,
    has_function_privilege('authenticated', 'public.get_subject_pricing_plans()', 'EXECUTE') AS authenticated_plan_rpc;
