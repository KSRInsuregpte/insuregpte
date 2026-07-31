-- Expected result: Success. No rows returned.
-- Run after 20260730150000_add_admin_bulk_import.sql.

DO $verification$
DECLARE
    v_signature text := 'public.admin_bulk_import(text,jsonb)';
    v_definition text;
BEGIN
    IF pg_catalog.to_regprocedure(v_signature) IS NULL THEN
        RAISE EXCEPTION 'admin_bulk_import(text,jsonb) is missing';
    END IF;

    IF pg_catalog.has_function_privilege(
        'anon',
        v_signature,
        'EXECUTE'
    ) OR pg_catalog.has_function_privilege(
        'service_role',
        v_signature,
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'Only authenticated administrators may reach the bulk-import RPC';
    END IF;

    IF NOT pg_catalog.has_function_privilege(
        'authenticated',
        v_signature,
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'authenticated cannot execute the guarded bulk-import RPC';
    END IF;

    SELECT pg_catalog.pg_get_functiondef(
        pg_catalog.to_regprocedure(v_signature)
    )
    INTO v_definition;

    IF v_definition NOT LIKE '%SECURITY DEFINER%'
       OR v_definition NOT LIKE '%SET search_path TO%'
       OR v_definition NOT LIKE '%public.fn_is_admin()%'
       OR v_definition NOT LIKE '%public.admin_save_subject(v_row)%'
       OR v_definition NOT LIKE '%public.admin_save_question(v_payload)%'
       OR v_definition NOT LIKE
          '%public.admin_set_user_status(%'
       OR v_definition NOT LIKE '%BETWEEN 1 AND 250%'
       OR v_definition NOT LIKE '%subject_code%' THEN
        RAISE EXCEPTION
            'The bulk coordinator does not preserve the approved admin boundaries';
    END IF;

    IF v_definition LIKE '%INSERT INTO public.subjects%'
       OR v_definition LIKE '%INSERT INTO public.questions%'
       OR v_definition LIKE '%UPDATE public.profiles%'
       OR v_definition LIKE '%INSERT INTO auth.users%'
       OR v_definition LIKE '%UPDATE auth.users%' THEN
        RAISE EXCEPTION
            'Bulk import must delegate to existing audited save functions';
    END IF;

    BEGIN
        PERFORM public.admin_bulk_import(
            'users',
            '[{"email":"nobody@example.invalid","status":"active"}]'::jsonb
        );
        RAISE EXCEPTION
            'A request without an authenticated administrator was accepted';
    EXCEPTION
        WHEN SQLSTATE 'PT403' THEN
            NULL;
    END;
END;
$verification$;
