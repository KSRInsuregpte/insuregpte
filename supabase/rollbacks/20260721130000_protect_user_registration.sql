-- Emergency rollback for 20260721130000_protect_user_registration.sql.
--
-- This restores the prior email-only profile activation and strict
-- active-client lease guard. Newly added profile audit columns are retained so
-- rollback cannot destroy registration-source or verification history.
-- Disable public signup before running this rollback.

DROP TRIGGER IF EXISTS trigger_activate_verified_user ON auth.users;

CREATE OR REPLACE FUNCTION public.activate_verified_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $function$
BEGIN
    UPDATE public.profiles
    SET status = 'active'
    WHERE id = NEW.id
      AND status = 'verification_pending';

    RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.activate_verified_user()
FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER trigger_activate_verified_user
AFTER UPDATE OF email_confirmed_at ON auth.users
FOR EACH ROW
WHEN (
    OLD.email_confirmed_at IS NULL
    AND NEW.email_confirmed_at IS NOT NULL
)
EXECUTE FUNCTION public.activate_verified_user();

CREATE OR REPLACE FUNCTION public.fn_create_user_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_subjects jsonb;
BEGIN
    v_subjects := CASE
        WHEN jsonb_typeof(
            COALESCE(NEW.raw_user_meta_data -> 'subjects', '[]'::jsonb)
        ) = 'array'
        THEN COALESCE(
            NEW.raw_user_meta_data -> 'subjects',
            '[]'::jsonb
        )
        ELSE '[]'::jsonb
    END;

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
        subscription_plan
    )
    VALUES (
        NEW.id,
        NULLIF(BTRIM(NEW.raw_user_meta_data ->> 'first_name'), ''),
        NULLIF(BTRIM(NEW.raw_user_meta_data ->> 'last_name'), ''),
        NULLIF(BTRIM(NEW.raw_user_meta_data ->> 'mobile'), ''),
        NULLIF(BTRIM(NEW.raw_user_meta_data ->> 'company_name'), ''),
        NULLIF(BTRIM(NEW.raw_user_meta_data ->> 'profession'), ''),
        NULLIF(BTRIM(NEW.raw_user_meta_data ->> 'building_name'), ''),
        NULLIF(BTRIM(NEW.raw_user_meta_data ->> 'street_name'), ''),
        NULLIF(BTRIM(NEW.raw_user_meta_data ->> 'area'), ''),
        NULLIF(BTRIM(NEW.raw_user_meta_data ->> 'city'), ''),
        NULLIF(BTRIM(NEW.raw_user_meta_data ->> 'pin_code'), ''),
        NULLIF(BTRIM(NEW.raw_user_meta_data ->> 'country'), ''),
        v_subjects,
        'verification_pending',
        'user',
        'free'
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_create_user_profile()
FROM PUBLIC, anon, authenticated;

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
    v_current_user_id uuid;
    v_status text;
BEGIN
    v_current_user_id := auth.uid();

    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'You must be signed in.';
    END IF;

    IF user_id IS DISTINCT FROM v_current_user_id THEN
        RAISE EXCEPTION 'You may update only your own profile.';
    END IF;

    IF subjects IS NOT NULL
       AND jsonb_typeof(subjects) <> 'array' THEN
        RAISE EXCEPTION 'Subjects must be a JSON array.';
    END IF;

    SELECT CASE
        WHEN auth_user.email_confirmed_at IS NOT NULL THEN 'active'
        ELSE 'verification_pending'
    END
    INTO v_status
    FROM auth.users AS auth_user
    WHERE auth_user.id = v_current_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'The authenticated user record was not found.';
    END IF;

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
        subscription_plan
    )
    VALUES (
        v_current_user_id,
        NULLIF(BTRIM(fname), ''),
        NULLIF(BTRIM(lname), ''),
        NULLIF(BTRIM(mob), ''),
        NULLIF(BTRIM(company), ''),
        NULLIF(BTRIM(prof), ''),
        NULLIF(BTRIM(bldg), ''),
        NULLIF(BTRIM(st), ''),
        NULLIF(BTRIM(ar), ''),
        NULLIF(BTRIM(ct), ''),
        NULLIF(BTRIM(pin), ''),
        NULLIF(BTRIM(cnt), ''),
        COALESCE(subjects, '[]'::jsonb),
        v_status,
        'user',
        'free'
    )
    ON CONFLICT (id) DO UPDATE SET
        first_name = EXCLUDED.first_name,
        last_name = EXCLUDED.last_name,
        mobile = EXCLUDED.mobile,
        company_name = EXCLUDED.company_name,
        profession = EXCLUDED.profession,
        building_name = EXCLUDED.building_name,
        street_name = EXCLUDED.street_name,
        area = EXCLUDED.area,
        city = EXCLUDED.city,
        pin_code = EXCLUDED.pin_code,
        country = EXCLUDED.country,
        interested_business_areas = EXCLUDED.interested_business_areas;
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
FROM PUBLIC, anon;
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

DROP FUNCTION IF EXISTS public.hook_validate_user_registration(jsonb);

ALTER TABLE public.profiles
DROP CONSTRAINT IF EXISTS chk_profiles_protected_registration_complete;
ALTER TABLE public.profiles
DROP CONSTRAINT IF EXISTS chk_profiles_registration_security_version;

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

    v_user_id := auth.uid();

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
                    'This session is no longer active. Please sign in again.';
    END;

    IF v_user_id IS NULL
       OR v_session_id IS NULL
       OR v_client_id IS NULL THEN
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
    'Rejects authenticated Data API requests unless the JWT session and x-insuregpte-client-id own the current unexpired active-client lease.';

REVOKE ALL ON FUNCTION public.fn_enforce_active_auth_session()
FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_enforce_active_auth_session()
TO anon, authenticated, service_role, authenticator;

NOTIFY pgrst, 'reload schema';
