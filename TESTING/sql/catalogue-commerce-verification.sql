-- Expected result: Success. No rows returned.
-- Run after 20260725120000_launch_subject_catalogue.sql.

DO $verification$
DECLARE
    v_function text;
    v_definition text;
BEGIN
    FOREACH v_function IN ARRAY ARRAY[
        'public.get_subject_catalogue()',
        'public.add_subject_to_cart(bigint)',
        'public.remove_subject_from_cart(bigint)',
        'public.get_my_cart()'
    ]
    LOOP
        IF pg_catalog.to_regprocedure(v_function) IS NULL THEN
            RAISE EXCEPTION 'Required RPC is missing: %', v_function;
        END IF;
    END LOOP;

    SELECT pg_catalog.pg_get_functiondef(
        pg_catalog.to_regprocedure(
            'public.hook_validate_user_registration(jsonb)'
        )
    )
    INTO v_definition;

    IF v_definition NOT LIKE '%registration_security_version%' ||
       v_definition NOT LIKE '%<> ''3''%' ||
       v_definition NOT LIKE
           '%Choose subjects from the catalogue after registration.%' THEN
        RAISE EXCEPTION
            'The registration version-3 Auth hook is not active';
    END IF;

    IF pg_catalog.has_function_privilege(
        'anon',
        'public.add_subject_to_cart(bigint)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'anon must not execute add_subject_to_cart';
    END IF;

    IF NOT pg_catalog.has_function_privilege(
        'authenticated',
        'public.add_subject_to_cart(bigint)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'authenticated cannot execute add_subject_to_cart';
    END IF;

    IF NOT pg_catalog.has_function_privilege(
        'anon',
        'public.get_subject_catalogue()',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'anon cannot execute the public catalogue RPC';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.profiles AS profile_record
        CROSS JOIN LATERAL jsonb_array_elements_text(
            CASE
                WHEN jsonb_typeof(
                    profile_record.interested_business_areas
                ) = 'array'
                THEN profile_record.interested_business_areas
                ELSE '[]'::jsonb
            END
        ) AS selected_subject(code)
        JOIN public.subjects AS subject_record
          ON subject_record.code = selected_subject.code
         AND subject_record.is_active = true
        WHERE NOT EXISTS (
            SELECT 1
            FROM public.user_entitlements AS entitlement_record
            WHERE entitlement_record.user_id = profile_record.id
              AND entitlement_record.subject_id = subject_record.id
              AND entitlement_record.status = 'active'
              AND entitlement_record.valid_from <= clock_timestamp()
              AND (
                  entitlement_record.valid_until IS NULL
                  OR entitlement_record.valid_until > clock_timestamp()
              )
        )
    ) THEN
        RAISE EXCEPTION
            'At least one legacy registration subject lacks an active entitlement';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.cart_items AS first_item
        JOIN public.cart_items AS second_item
          ON second_item.cart_id = first_item.cart_id
         AND second_item.subject_id = first_item.subject_id
         AND second_item.id <> first_item.id
    ) THEN
        RAISE EXCEPTION
            'Duplicate subject rows exist in an active cart';
    END IF;
END;
$verification$;
