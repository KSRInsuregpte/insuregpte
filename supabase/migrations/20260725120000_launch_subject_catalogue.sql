-- Launch the catalogue-first registration and entitlement model.
--
-- This migration intentionally reuses the existing subjects, academic
-- hierarchy, carts, cart_items, user_entitlements, and profiles tables.
-- It does not create a payment record or activate access from the browser.
--
-- Prerequisites:
--   * 20260721130000_protect_user_registration.sql
--   * 20260723214500_defer_mobile_verification.sql
--
-- Rollback:
--   supabase/rollbacks/20260725120000_launch_subject_catalogue.sql

DO $guard$
DECLARE
    v_required_table text;
    v_required_function text;
BEGIN
    FOREACH v_required_table IN ARRAY ARRAY[
        'profiles',
        'subjects',
        'qualification_levels',
        'exam_authorities',
        'training_programmes',
        'programme_sections',
        'carts',
        'cart_items',
        'user_entitlements',
        'questions',
        'learning_resources'
    ]
    LOOP
        IF pg_catalog.to_regclass(
            pg_catalog.format('public.%I', v_required_table)
        ) IS NULL THEN
            RAISE EXCEPTION 'Required table public.% is missing',
                v_required_table;
        END IF;
    END LOOP;

    FOREACH v_required_function IN ARRAY ARRAY[
        'public.hook_validate_user_registration(jsonb)',
        'public.fn_create_user_profile()',
        'public.save_user_profile(uuid,text,text,text,text,text,text,text,text,text,text,text,jsonb)'
    ]
    LOOP
        IF pg_catalog.to_regprocedure(v_required_function) IS NULL THEN
            RAISE EXCEPTION 'Required function % is missing',
                v_required_function;
        END IF;
    END LOOP;

    IF pg_catalog.to_regprocedure(
        'public.get_subject_catalogue()'
    ) IS NOT NULL
       OR pg_catalog.to_regprocedure(
           'public.add_subject_to_cart(bigint)'
       ) IS NOT NULL
       OR pg_catalog.to_regprocedure(
           'public.remove_subject_from_cart(bigint)'
       ) IS NOT NULL
       OR pg_catalog.to_regprocedure(
           'public.get_my_cart()'
       ) IS NOT NULL THEN
        RAISE EXCEPTION
            'One or more catalogue/cart RPCs already exist; audit before deployment';
    END IF;
END;
$guard$;

ALTER TABLE public.profiles
DROP CONSTRAINT IF EXISTS chk_profiles_protected_registration_complete;

ALTER TABLE public.profiles
ADD CONSTRAINT chk_profiles_protected_registration_complete
CHECK (
    registration_security_version < 2
    OR (
        NULLIF(BTRIM(first_name), '') IS NOT NULL
        AND NULLIF(BTRIM(last_name), '') IS NOT NULL
        AND mobile ~ '^\+[1-9][0-9]{7,14}$'
        AND NULLIF(BTRIM(company_name), '') IS NOT NULL
        AND NULLIF(BTRIM(profession), '') IS NOT NULL
        AND NULLIF(BTRIM(building_name), '') IS NOT NULL
        AND NULLIF(BTRIM(street_name), '') IS NOT NULL
        AND NULLIF(BTRIM(area), '') IS NOT NULL
        AND NULLIF(BTRIM(city), '') IS NOT NULL
        AND NULLIF(BTRIM(pin_code), '') IS NOT NULL
        AND NULLIF(BTRIM(country), '') IS NOT NULL
        AND jsonb_typeof(interested_business_areas) = 'array'
        AND (
            registration_security_version >= 3
            OR jsonb_array_length(interested_business_areas) >= 1
        )
        AND NULLIF(BTRIM(registration_source), '') IS NOT NULL
    )
);

CREATE OR REPLACE FUNCTION public.hook_validate_user_registration(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user jsonb := COALESCE(event -> 'user', '{}'::jsonb);
    v_metadata jsonb := COALESCE(
        event -> 'user' -> 'user_metadata',
        '{}'::jsonb
    );
    v_email text := LOWER(BTRIM(COALESCE(
        event -> 'user' ->> 'email',
        ''
    )));
    v_mobile text := BTRIM(COALESCE(v_metadata ->> 'mobile', ''));
    v_source text := BTRIM(COALESCE(
        v_metadata ->> 'registration_source',
        ''
    ));
    v_source_detail text := BTRIM(COALESCE(
        v_metadata ->> 'registration_source_detail',
        ''
    ));
    v_error text;
BEGIN
    IF COALESCE((v_user ->> 'is_anonymous')::boolean, false) THEN
        v_error := 'Anonymous registration is not permitted.';
    ELSIF COALESCE(
        v_user -> 'app_metadata' ->> 'provider',
        ''
    ) <> 'email' THEN
        v_error := 'Registration must use a verified email address.';
    ELSIF v_email !~
        '^[A-Za-z0-9.!#$%&''*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$' THEN
        v_error := 'Enter a valid email address.';
    ELSIF COALESCE(v_metadata ->> 'registration_security_version', '')
        <> '3' THEN
        v_error := 'Please use the current InsureGPTE registration form.';
    ELSIF BTRIM(COALESCE(v_metadata ->> 'first_name', ''))
        !~ '^[[:alpha:]][[:alpha:] .''-]{1,49}$' THEN
        v_error := 'Enter a valid first name.';
    ELSIF BTRIM(COALESCE(v_metadata ->> 'last_name', ''))
        !~ '^[[:alpha:]][[:alpha:] .''-]{0,49}$' THEN
        v_error := 'Enter a valid last name.';
    ELSIF v_mobile !~ '^\+[1-9][0-9]{7,14}$' THEN
        v_error := 'Enter the mobile number with country code.';
    ELSIF CHAR_LENGTH(BTRIM(COALESCE(
        v_metadata ->> 'company_name',
        ''
    ))) NOT BETWEEN 2 AND 120 THEN
        v_error := 'Enter the company or institution name.';
    ELSIF COALESCE(v_metadata ->> 'profession', '') NOT IN (
        'Student',
        'Working Professional',
        'Insurance Agent',
        'Insurance Broker',
        'Surveyor / Loss Assessor',
        'Other'
    ) THEN
        v_error := 'Select a valid profession.';
    ELSIF CHAR_LENGTH(BTRIM(COALESCE(
        v_metadata ->> 'building_name',
        ''
    ))) NOT BETWEEN 2 AND 120 THEN
        v_error := 'Enter a valid building or house name.';
    ELSIF CHAR_LENGTH(BTRIM(COALESCE(
        v_metadata ->> 'street_name',
        ''
    ))) NOT BETWEEN 2 AND 120 THEN
        v_error := 'Enter a valid street name.';
    ELSIF CHAR_LENGTH(BTRIM(COALESCE(
        v_metadata ->> 'area',
        ''
    ))) NOT BETWEEN 2 AND 120 THEN
        v_error := 'Enter a valid area or locality.';
    ELSIF CHAR_LENGTH(BTRIM(COALESCE(
        v_metadata ->> 'city',
        ''
    ))) NOT BETWEEN 2 AND 80 THEN
        v_error := 'Enter a valid city.';
    ELSIF BTRIM(COALESCE(v_metadata ->> 'pin_code', ''))
        !~ '^[A-Za-z0-9][A-Za-z0-9 -]{1,10}[A-Za-z0-9]$' THEN
        v_error := 'Enter a valid postal or PIN code.';
    ELSIF CHAR_LENGTH(BTRIM(COALESCE(
        v_metadata ->> 'country',
        ''
    ))) NOT BETWEEN 2 AND 56 THEN
        v_error := 'Enter a valid country.';
    ELSIF v_source NOT IN (
        'search_engine',
        'colleague',
        'employer',
        'training_institute',
        'social_media',
        'professional_association',
        'direct_invitation',
        'other'
    ) THEN
        v_error := 'Select how you learned about InsureGPTE.';
    ELSIF v_source = 'other'
          AND CHAR_LENGTH(v_source_detail) NOT BETWEEN 2 AND 120 THEN
        v_error := 'Describe how you learned about InsureGPTE.';
    ELSIF COALESCE(v_metadata -> 'subjects', '[]'::jsonb)
        <> '[]'::jsonb THEN
        v_error := 'Choose subjects from the catalogue after registration.';
    END IF;

    IF v_error IS NOT NULL THEN
        RETURN jsonb_build_object(
            'error',
            jsonb_build_object(
                'http_code', 400,
                'message', v_error
            )
        );
    END IF;

    RETURN '{}'::jsonb;
END;
$function$;

REVOKE ALL ON FUNCTION public.hook_validate_user_registration(jsonb)
FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.hook_validate_user_registration(jsonb)
TO supabase_auth_admin;
GRANT USAGE ON SCHEMA public TO supabase_auth_admin;

CREATE OR REPLACE FUNCTION public.fn_create_user_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_metadata jsonb := COALESCE(NEW.raw_user_meta_data, '{}'::jsonb);
    v_validation_result jsonb;
    v_security_version smallint;
    v_source_detail text;
BEGIN
    v_validation_result := public.hook_validate_user_registration(
        jsonb_build_object(
            'user',
            jsonb_build_object(
                'email', NEW.email,
                'is_anonymous', NEW.is_anonymous,
                'app_metadata', COALESCE(
                    NEW.raw_app_meta_data,
                    '{}'::jsonb
                ),
                'user_metadata', v_metadata
            )
        )
    );

    IF v_validation_result ? 'error' THEN
        RAISE EXCEPTION 'Registration rejected: %',
            v_validation_result -> 'error' ->> 'message';
    END IF;

    BEGIN
        v_security_version := (
            v_metadata ->> 'registration_security_version'
        )::smallint;
    EXCEPTION
        WHEN OTHERS THEN
            v_security_version := NULL;
    END;

    IF v_security_version IS DISTINCT FROM 3 THEN
        RAISE EXCEPTION
            'Registration rejected: use the current InsureGPTE form';
    END IF;

    v_source_detail := NULLIF(BTRIM(
        v_metadata ->> 'registration_source_detail'
    ), '');

    INSERT INTO public.profiles (
        id,
        first_name,
        last_name,
        mobile,
        company_name,
        profession,
        building_name,
        street_name,
        area,
        city,
        pin_code,
        country,
        interested_business_areas,
        status,
        role,
        subscription_plan,
        registration_source,
        registration_source_detail,
        registration_security_version,
        email_verified_at,
        mobile_verified_at
    )
    VALUES (
        NEW.id,
        NULLIF(BTRIM(v_metadata ->> 'first_name'), ''),
        NULLIF(BTRIM(v_metadata ->> 'last_name'), ''),
        NULLIF(BTRIM(v_metadata ->> 'mobile'), ''),
        NULLIF(BTRIM(v_metadata ->> 'company_name'), ''),
        NULLIF(BTRIM(v_metadata ->> 'profession'), ''),
        NULLIF(BTRIM(v_metadata ->> 'building_name'), ''),
        NULLIF(BTRIM(v_metadata ->> 'street_name'), ''),
        NULLIF(BTRIM(v_metadata ->> 'area'), ''),
        NULLIF(BTRIM(v_metadata ->> 'city'), ''),
        NULLIF(BTRIM(v_metadata ->> 'pin_code'), ''),
        NULLIF(BTRIM(v_metadata ->> 'country'), ''),
        '[]'::jsonb,
        'verification_pending',
        'user',
        'free',
        NULLIF(BTRIM(v_metadata ->> 'registration_source'), ''),
        v_source_detail,
        v_security_version,
        NEW.email_confirmed_at,
        CASE
            WHEN NEW.phone_confirmed_at IS NOT NULL
             AND NEW.phone = NULLIF(BTRIM(v_metadata ->> 'mobile'), '')
            THEN NEW.phone_confirmed_at
            ELSE NULL
        END
    );

    RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_create_user_profile()
FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.save_user_profile(
    user_id uuid,
    fname text,
    lname text,
    mob text,
    prof text,
    company text,
    bldg text,
    st text,
    ar text,
    ct text,
    pin text,
    cnt text,
    subjects jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_current_user_id uuid := auth.uid();
    v_profile public.profiles%ROWTYPE;
    v_auth_user auth.users%ROWTYPE;
    v_subjects jsonb := COALESCE(subjects, '[]'::jsonb);
    v_status text;
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'You must be signed in.';
    END IF;

    IF user_id IS DISTINCT FROM v_current_user_id THEN
        RAISE EXCEPTION 'You may update only your own profile.';
    END IF;

    SELECT profile_record.*
    INTO v_profile
    FROM public.profiles AS profile_record
    WHERE profile_record.id = v_current_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Your registration profile was not found.';
    END IF;

    IF NULLIF(BTRIM(fname), '') IS NULL
       OR NULLIF(BTRIM(lname), '') IS NULL
       OR NULLIF(BTRIM(mob), '') IS NULL
       OR NULLIF(BTRIM(prof), '') IS NULL
       OR NULLIF(BTRIM(company), '') IS NULL
       OR NULLIF(BTRIM(bldg), '') IS NULL
       OR NULLIF(BTRIM(st), '') IS NULL
       OR NULLIF(BTRIM(ar), '') IS NULL
       OR NULLIF(BTRIM(ct), '') IS NULL
       OR NULLIF(BTRIM(pin), '') IS NULL
       OR NULLIF(BTRIM(cnt), '') IS NULL THEN
        RAISE EXCEPTION 'All profile fields are required.';
    END IF;

    IF BTRIM(mob) !~ '^\+[1-9][0-9]{7,14}$' THEN
        RAISE EXCEPTION 'Enter the mobile number with country code.';
    END IF;

    IF v_profile.mobile IS DISTINCT FROM BTRIM(mob) THEN
        RAISE EXCEPTION
            'The mobile number can be changed only through OTP verification.';
    END IF;

    IF jsonb_typeof(v_subjects) <> 'array' THEN
        RAISE EXCEPTION 'The subject selection is invalid.';
    END IF;

    IF v_profile.registration_security_version >= 3
       AND jsonb_array_length(v_subjects) > 0 THEN
        RAISE EXCEPTION
            'Choose subjects from the catalogue after registration.';
    END IF;

    IF v_profile.registration_security_version = 2
       AND jsonb_array_length(v_subjects) < 1 THEN
        RAISE EXCEPTION 'Select at least one subject.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements_text(v_subjects) AS selected_subject(code)
        LEFT JOIN public.subjects AS subject_record
          ON subject_record.code = selected_subject.code
         AND subject_record.is_active = true
        WHERE subject_record.id IS NULL
    ) THEN
        RAISE EXCEPTION 'One or more selected subjects are unavailable.';
    END IF;

    SELECT auth_user.*
    INTO v_auth_user
    FROM auth.users AS auth_user
    WHERE auth_user.id = v_current_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'The authenticated user record was not found.';
    END IF;

    v_status := CASE
        WHEN v_profile.status <> 'verification_pending' THEN
            v_profile.status
        WHEN v_auth_user.email_confirmed_at IS NOT NULL THEN 'active'
        ELSE 'verification_pending'
    END;

    UPDATE public.profiles AS profile_record
    SET first_name = BTRIM(fname),
        last_name = BTRIM(lname),
        company_name = BTRIM(company),
        profession = BTRIM(prof),
        building_name = BTRIM(bldg),
        street_name = BTRIM(st),
        area = BTRIM(ar),
        city = BTRIM(ct),
        pin_code = BTRIM(pin),
        country = BTRIM(cnt),
        interested_business_areas = v_subjects,
        status = v_status,
        email_verified_at = v_auth_user.email_confirmed_at,
        mobile_verified_at = CASE
            WHEN v_auth_user.phone_confirmed_at IS NOT NULL
             AND v_auth_user.phone = v_profile.mobile
            THEN v_auth_user.phone_confirmed_at
            ELSE profile_record.mobile_verified_at
        END
    WHERE profile_record.id = v_current_user_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.save_user_profile(
    uuid,
    text,
    text,
    text,
    text,
    text,
    text,
    text,
    text,
    text,
    text,
    text,
    jsonb
)
FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.save_user_profile(
    uuid,
    text,
    text,
    text,
    text,
    text,
    text,
    text,
    text,
    text,
    text,
    text,
    jsonb
)
TO authenticated;

-- Preserve current learners' registration-selected subjects as complimentary
-- entitlements before the dashboard switches to entitlement-based access.
INSERT INTO public.user_entitlements (
    user_id,
    subject_id,
    access_type,
    status,
    valid_from,
    valid_until,
    source_reference
)
SELECT
    profile_record.id,
    subject_record.id,
    'complimentary',
    'active',
    clock_timestamp(),
    NULL,
    'migration:20260725120000:legacy-registration-selection'
FROM public.profiles AS profile_record
CROSS JOIN LATERAL jsonb_array_elements_text(
    CASE
        WHEN jsonb_typeof(profile_record.interested_business_areas) = 'array'
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
);

CREATE FUNCTION public.get_subject_catalogue()
RETURNS TABLE (
    subject_id bigint,
    subject_code text,
    subject_title text,
    subject_description text,
    category_code text,
    category_name text,
    qualification_level text,
    exam_authority text,
    programme_name text,
    programme_category text,
    programme_section text,
    price numeric,
    currency_code text,
    demo_question_limit integer,
    is_demo_available boolean,
    advanced_question_count bigint,
    has_learning_content boolean,
    is_entitled boolean,
    is_in_cart boolean,
    display_order integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
    SELECT
        subject_record.id::bigint,
        subject_record.code,
        subject_record.title,
        subject_record.description,
        LOWER(COALESCE(
            NULLIF(qualification_record.code, ''),
            NULLIF(programme_record.programme_category, ''),
            NULLIF(subject_record.category, ''),
            'other'
        )),
        COALESCE(
            NULLIF(qualification_record.name, ''),
            NULLIF(programme_record.programme_category, ''),
            NULLIF(subject_record.category, ''),
            'Other insurance programmes'
        ),
        qualification_record.name,
        authority_record.short_name,
        programme_record.name,
        programme_record.programme_category,
        section_record.name,
        subject_record.price,
        subject_record.currency_code,
        subject_record.demo_question_limit,
        subject_record.is_demo_available,
        (
            SELECT COUNT(*)
            FROM public.questions AS question_record
            WHERE question_record.subject_id = subject_record.id
              AND question_record.is_active = true
              AND question_record.difficulty_level = 'advanced'
        ),
        EXISTS (
            SELECT 1
            FROM public.learning_resources AS resource_record
            WHERE resource_record.subject_id = subject_record.id
              AND resource_record.is_active = true
        ),
        EXISTS (
            SELECT 1
            FROM public.user_entitlements AS entitlement_record
            WHERE entitlement_record.user_id = auth.uid()
              AND entitlement_record.subject_id = subject_record.id
              AND entitlement_record.status = 'active'
              AND entitlement_record.valid_from <= CURRENT_TIMESTAMP
              AND (
                  entitlement_record.valid_until IS NULL
                  OR entitlement_record.valid_until > CURRENT_TIMESTAMP
              )
        ),
        EXISTS (
            SELECT 1
            FROM public.carts AS cart_record
            JOIN public.cart_items AS item_record
              ON item_record.cart_id = cart_record.id
            WHERE cart_record.user_id = auth.uid()
              AND cart_record.status = 'active'
              AND item_record.subject_id = subject_record.id
        ),
        subject_record.display_order
    FROM public.subjects AS subject_record
    LEFT JOIN public.qualification_levels AS qualification_record
      ON qualification_record.id = subject_record.qualification_level_id
     AND qualification_record.is_active = true
    LEFT JOIN public.training_programmes AS programme_record
      ON programme_record.id = subject_record.training_programme_id
     AND programme_record.is_active = true
    LEFT JOIN public.exam_authorities AS authority_record
      ON authority_record.id = programme_record.exam_authority_id
     AND authority_record.is_active = true
    LEFT JOIN public.programme_sections AS section_record
      ON section_record.id = subject_record.programme_section_id
     AND section_record.is_active = true
    WHERE subject_record.is_active = true
    ORDER BY
        COALESCE(qualification_record.display_order, 999),
        COALESCE(programme_record.display_order, 999),
        COALESCE(section_record.display_order, 999),
        subject_record.display_order,
        subject_record.code;
$function$;

REVOKE ALL ON FUNCTION public.get_subject_catalogue()
FROM PUBLIC, service_role;
GRANT EXECUTE ON FUNCTION public.get_subject_catalogue()
TO anon, authenticated;

CREATE FUNCTION public.add_subject_to_cart(p_subject_id bigint)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id uuid := auth.uid();
    v_cart_id uuid;
    v_price numeric;
    v_currency_code text;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Sign in before adding a subject to your cart.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.profiles AS profile_record
        WHERE profile_record.id = v_user_id
          AND profile_record.status = 'active'
    ) THEN
        RAISE EXCEPTION 'Your account is not active.';
    END IF;

    SELECT subject_record.price, subject_record.currency_code
    INTO v_price, v_currency_code
    FROM public.subjects AS subject_record
    WHERE subject_record.id = p_subject_id
      AND subject_record.is_active = true
    FOR SHARE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'The selected subject is not available.';
    END IF;

    IF COALESCE(v_price, 0) <= 0 THEN
        RAISE EXCEPTION
            'This subject does not currently require a purchase.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.user_entitlements AS entitlement_record
        WHERE entitlement_record.user_id = v_user_id
          AND entitlement_record.subject_id = p_subject_id
          AND entitlement_record.status = 'active'
          AND entitlement_record.valid_from <= clock_timestamp()
          AND (
              entitlement_record.valid_until IS NULL
              OR entitlement_record.valid_until > clock_timestamp()
          )
    ) THEN
        RAISE EXCEPTION 'You already have access to this subject.';
    END IF;

    PERFORM pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(v_user_id::text, 0)
    );

    SELECT cart_record.id
    INTO v_cart_id
    FROM public.carts AS cart_record
    WHERE cart_record.user_id = v_user_id
      AND cart_record.status = 'active'
      AND cart_record.currency_code = v_currency_code
    ORDER BY cart_record.created_at
    LIMIT 1
    FOR UPDATE;

    IF v_cart_id IS NULL THEN
        INSERT INTO public.carts (
            user_id,
            status,
            currency_code
        )
        VALUES (
            v_user_id,
            'active',
            v_currency_code
        )
        RETURNING id INTO v_cart_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.cart_items AS item_record
        WHERE item_record.cart_id = v_cart_id
          AND item_record.subject_id = p_subject_id
    ) THEN
        INSERT INTO public.cart_items (
            cart_id,
            subject_id,
            unit_price,
            currency_code
        )
        VALUES (
            v_cart_id,
            p_subject_id,
            v_price,
            v_currency_code
        );
    END IF;

    UPDATE public.carts
    SET updated_at = clock_timestamp()
    WHERE id = v_cart_id;

    RETURN v_cart_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.add_subject_to_cart(bigint)
FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.add_subject_to_cart(bigint)
TO authenticated;

CREATE FUNCTION public.remove_subject_from_cart(p_subject_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id uuid := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Sign in to update your cart.';
    END IF;

    DELETE FROM public.cart_items AS item_record
    USING public.carts AS cart_record
    WHERE item_record.cart_id = cart_record.id
      AND cart_record.user_id = v_user_id
      AND cart_record.status = 'active'
      AND item_record.subject_id = p_subject_id;

    UPDATE public.carts AS cart_record
    SET updated_at = clock_timestamp()
    WHERE cart_record.user_id = v_user_id
      AND cart_record.status = 'active';
END;
$function$;

REVOKE ALL ON FUNCTION public.remove_subject_from_cart(bigint)
FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.remove_subject_from_cart(bigint)
TO authenticated;

CREATE FUNCTION public.get_my_cart()
RETURNS TABLE (
    cart_id uuid,
    subject_id bigint,
    subject_code text,
    subject_title text,
    unit_price numeric,
    currency_code text,
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
    SELECT
        cart_record.id,
        subject_record.id::bigint,
        subject_record.code,
        subject_record.title,
        item_record.unit_price,
        item_record.currency_code,
        item_record.created_at
    FROM public.carts AS cart_record
    JOIN public.cart_items AS item_record
      ON item_record.cart_id = cart_record.id
    JOIN public.subjects AS subject_record
      ON subject_record.id = item_record.subject_id
    WHERE cart_record.user_id = v_user_id
      AND cart_record.status = 'active'
    ORDER BY item_record.created_at;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_my_cart()
FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_my_cart()
TO authenticated;

COMMENT ON FUNCTION public.get_subject_catalogue() IS
    'Returns the active academic catalogue plus caller-specific entitlement and cart state without exposing tables.';
COMMENT ON FUNCTION public.add_subject_to_cart(bigint) IS
    'Adds one active paid subject to the authenticated learner cart using the authoritative server price.';
COMMENT ON FUNCTION public.remove_subject_from_cart(bigint) IS
    'Removes one subject from the authenticated learner active cart.';
COMMENT ON FUNCTION public.get_my_cart() IS
    'Returns the authenticated learner active cart using server-recorded prices.';

NOTIFY pgrst, 'reload schema';
