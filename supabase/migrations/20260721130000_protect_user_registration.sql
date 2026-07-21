-- Protect public registration with server-side metadata validation, require
-- email plus mobile verification for new accounts, and record referral data.
--
-- Prerequisites:
--   * 20260719182000_harden_profile_registration.sql
--   * 20260720090000_add_active_client_lease.sql
--   * 20260720100000_require_active_client_lease.sql
--   * Configure this function as Authentication > Hooks > Before User Created:
--       public.hook_validate_user_registration
--
-- The Auth hook provides friendly rejections. The auth.users profile trigger
-- repeats the critical checks so incomplete users still cannot be created if
-- the hook is accidentally disabled.
--
-- Rollback:
-- supabase/rollbacks/20260721130000_protect_user_registration.sql

DO $guard$
DECLARE
    v_guard_description text;
BEGIN
    IF to_regclass('public.profiles') IS NULL
       OR to_regclass('public.subjects') IS NULL THEN
        RAISE EXCEPTION 'Required profiles or subjects table is missing';
    END IF;

    IF to_regprocedure('public.fn_create_user_profile()') IS NULL
       OR to_regprocedure('public.activate_verified_user()') IS NULL THEN
        RAISE EXCEPTION 'Required profile lifecycle functions are missing';
    END IF;

    IF to_regclass('public.active_client_leases') IS NULL
       OR to_regprocedure(
           'public.claim_active_client(uuid,boolean)'
       ) IS NULL THEN
        RAISE EXCEPTION
            'Deploy the active-client lease migrations before this migration';
    END IF;

    SELECT pg_catalog.obj_description(
        to_regprocedure('public.fn_enforce_active_auth_session()'),
        'pg_proc'
    )
    INTO v_guard_description;

    IF v_guard_description IS DISTINCT FROM
        'Rejects authenticated Data API requests unless the JWT session and x-insuregpte-client-id own the current unexpired active-client lease.' THEN
        RAISE EXCEPTION
            'Strict active-client lease enforcement must be active first';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_constraint AS constraint_record
        WHERE constraint_record.conrelid = 'public.profiles'::regclass
          AND constraint_record.contype = 'u'
          AND pg_catalog.pg_get_constraintdef(
              constraint_record.oid
          ) = 'UNIQUE (mobile)'
    ) THEN
        RAISE EXCEPTION
            'The existing unique profiles.mobile constraint is missing';
    END IF;

    IF to_regprocedure(
        'public.hook_validate_user_registration(jsonb)'
    ) IS NOT NULL THEN
        RAISE EXCEPTION
            'hook_validate_user_registration(jsonb) already exists';
    END IF;
END;
$guard$;

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS registration_source text,
ADD COLUMN IF NOT EXISTS registration_source_detail text,
ADD COLUMN IF NOT EXISTS registration_security_version smallint
    NOT NULL DEFAULT 1,
ADD COLUMN IF NOT EXISTS email_verified_at timestamptz,
ADD COLUMN IF NOT EXISTS mobile_verified_at timestamptz;

COMMENT ON COLUMN public.profiles.registration_source IS
    'Learner-reported source through which they learned about InsureGPTE.';
COMMENT ON COLUMN public.profiles.registration_source_detail IS
    'Optional learner-provided detail for the selected registration source.';
COMMENT ON COLUMN public.profiles.registration_security_version IS
    'Trusted registration validation version copied by the auth trigger.';
COMMENT ON COLUMN public.profiles.email_verified_at IS
    'Supabase Auth email confirmation time copied by the auth trigger.';
COMMENT ON COLUMN public.profiles.mobile_verified_at IS
    'Supabase Auth phone confirmation time after it matches profiles.mobile.';

ALTER TABLE public.profiles
DROP CONSTRAINT IF EXISTS chk_profiles_registration_security_version;
ALTER TABLE public.profiles
ADD CONSTRAINT chk_profiles_registration_security_version
CHECK (registration_security_version >= 1);

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
        AND jsonb_array_length(interested_business_areas) >= 1
        AND NULLIF(BTRIM(registration_source), '') IS NOT NULL
    )
);

CREATE FUNCTION public.hook_validate_user_registration(event jsonb)
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
    v_subject_count integer;
    v_valid_subject_count integer;
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
        <> '2' THEN
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
    ELSIF jsonb_typeof(v_metadata -> 'subjects') <> 'array' THEN
        v_error := 'Select at least one subject.';
    ELSE
        v_subject_count := jsonb_array_length(v_metadata -> 'subjects');

        IF v_subject_count NOT BETWEEN 1 AND 20 THEN
            v_error := 'Select between 1 and 20 subjects.';
        ELSIF EXISTS (
            SELECT 1
            FROM jsonb_array_elements(v_metadata -> 'subjects') AS item
            WHERE jsonb_typeof(item.value) <> 'string'
               OR NULLIF(BTRIM(item.value #>> '{}'), '') IS NULL
        ) THEN
            v_error := 'The selected subjects are invalid.';
        ELSE
            SELECT COUNT(DISTINCT selected_subject.code)
            INTO v_valid_subject_count
            FROM jsonb_array_elements_text(
                v_metadata -> 'subjects'
            ) AS selected_subject(code)
            JOIN public.subjects AS subject_record
              ON subject_record.code = selected_subject.code
             AND subject_record.is_active = true;

            IF v_valid_subject_count <> v_subject_count THEN
                v_error := 'One or more selected subjects are unavailable.';
            END IF;
        END IF;
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
    v_subjects jsonb;
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

    IF v_security_version IS DISTINCT FROM 2 THEN
        RAISE EXCEPTION
            'Registration rejected: use the current InsureGPTE form';
    END IF;

    IF jsonb_typeof(v_metadata -> 'subjects') <> 'array'
       OR jsonb_array_length(v_metadata -> 'subjects') < 1 THEN
        RAISE EXCEPTION
            'Registration rejected: select at least one subject';
    END IF;

    v_subjects := v_metadata -> 'subjects';
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
        v_subjects,
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

CREATE OR REPLACE FUNCTION public.activate_verified_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
    UPDATE public.profiles AS profile_record
    SET email_verified_at = NEW.email_confirmed_at,
        mobile_verified_at = CASE
            WHEN NEW.phone_confirmed_at IS NOT NULL
             AND NEW.phone = profile_record.mobile
            THEN NEW.phone_confirmed_at
            ELSE profile_record.mobile_verified_at
        END,
        status = CASE
            WHEN profile_record.status <> 'verification_pending' THEN
                profile_record.status
            WHEN profile_record.registration_security_version < 2
             AND NEW.email_confirmed_at IS NOT NULL THEN
                'active'
            WHEN profile_record.registration_security_version >= 2
             AND NEW.email_confirmed_at IS NOT NULL
             AND NEW.phone_confirmed_at IS NOT NULL
             AND NEW.phone = profile_record.mobile THEN
                'active'
            ELSE profile_record.status
        END
    WHERE profile_record.id = NEW.id;

    RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.activate_verified_user()
FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trigger_activate_verified_user ON auth.users;

CREATE TRIGGER trigger_activate_verified_user
AFTER UPDATE OF email_confirmed_at, phone, phone_confirmed_at
ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.activate_verified_user();

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

    IF jsonb_typeof(subjects) <> 'array'
       OR jsonb_array_length(subjects) < 1 THEN
        RAISE EXCEPTION 'Select at least one subject.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements_text(subjects) AS selected_subject(code)
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
        WHEN v_profile.registration_security_version < 2
         AND v_auth_user.email_confirmed_at IS NOT NULL THEN 'active'
        WHEN v_profile.registration_security_version >= 2
         AND v_auth_user.email_confirmed_at IS NOT NULL
         AND v_auth_user.phone_confirmed_at IS NOT NULL
         AND v_auth_user.phone = v_profile.mobile THEN 'active'
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
        interested_business_areas = subjects,
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

-- Preserve the strict one-active-page behavior and add an account-status gate.
-- Supabase Auth phone/email endpoints remain reachable because this guard is
-- used only by PostgREST table and RPC requests.
CREATE OR REPLACE FUNCTION public.fn_enforce_active_auth_session()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_claims jsonb;
    v_headers jsonb;
    v_user_id uuid;
    v_session_id uuid;
    v_client_id uuid;
    v_request_method text;
    v_request_path text;
BEGIN
    BEGIN
        v_claims := COALESCE(
            NULLIF(current_setting('request.jwt.claims', true), ''),
            '{}'
        )::jsonb;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE SQLSTATE 'PT401'
                USING MESSAGE =
                    'This session is no longer active. Please sign in again.';
    END;

    IF COALESCE(v_claims ->> 'role', '') <> 'authenticated' THEN
        RETURN;
    END IF;

    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE SQLSTATE 'PT401'
            USING MESSAGE =
                'This session is no longer active. Please sign in again.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.profiles AS profile_record
        WHERE profile_record.id = v_user_id
          AND profile_record.status = 'active'
    ) THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE =
                'Complete email and mobile verification before continuing.';
    END IF;

    v_request_method := UPPER(
        COALESCE(current_setting('request.method', true), '')
    );
    v_request_path := LTRIM(
        COALESCE(current_setting('request.path', true), ''),
        '/'
    );

    IF v_request_method = 'POST'
       AND v_request_path = 'rpc/claim_active_client' THEN
        RETURN;
    END IF;

    BEGIN
        v_session_id := NULLIF(v_claims ->> 'session_id', '')::uuid;
        v_headers := COALESCE(
            NULLIF(current_setting('request.headers', true), ''),
            '{}'
        )::jsonb;
        v_client_id := NULLIF(
            v_headers ->> 'x-insuregpte-client-id',
            ''
        )::uuid;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE SQLSTATE 'PT401'
                USING MESSAGE =
                    'This page is no longer the active login.';
    END;

    IF v_session_id IS NULL OR v_client_id IS NULL THEN
        RAISE SQLSTATE 'PT401'
            USING MESSAGE =
                'This page is no longer the active login.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.active_client_leases AS lease_record
        JOIN auth.sessions AS session_record
          ON session_record.id = lease_record.session_id
         AND session_record.user_id = lease_record.user_id
        WHERE lease_record.user_id = v_user_id
          AND lease_record.session_id = v_session_id
          AND lease_record.client_id = v_client_id
          AND lease_record.expires_at > clock_timestamp()
          AND (
              session_record.not_after IS NULL
              OR session_record.not_after > clock_timestamp()
          )
    ) THEN
        RAISE SQLSTATE 'PT401'
            USING MESSAGE =
                'This page is no longer the active login.';
    END IF;
END;
$function$;

COMMENT ON FUNCTION public.fn_enforce_active_auth_session() IS
    'Requires an active verified profile plus the current unexpired active-client lease for authenticated Data API requests.';

REVOKE ALL ON FUNCTION public.fn_enforce_active_auth_session()
FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_enforce_active_auth_session()
TO anon, authenticated, service_role, authenticator;

NOTIFY pgrst, 'reload schema';
