-- Create profiles from trusted auth.users rows, enable effective profile RLS,
-- and harden the existing save_user_profile signature.
--
-- Prerequisite:
-- 20260719181000_restrict_profiles_table_privileges.sql
--
-- Rollback:
-- supabase/rollbacks/20260719182000_harden_profile_registration.sql

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

DROP TRIGGER IF EXISTS trg_auth_users_create_profile ON auth.users;

CREATE TRIGGER trg_auth_users_create_profile
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.fn_create_user_profile();

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

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS
    "Allow authenticated users to manage their own profile"
    ON public.profiles;

DROP POLICY IF EXISTS
    "Allow users to insert their own profile"
    ON public.profiles;

DROP POLICY IF EXISTS
    "Enable insert for authenticated users only"
    ON public.profiles;

DROP POLICY IF EXISTS
    "Users can update their own profile"
    ON public.profiles;

DROP POLICY IF EXISTS
    "Users can view their own profile"
    ON public.profiles;

DROP POLICY IF EXISTS profiles_select_own ON public.profiles;

CREATE POLICY profiles_select_own
ON public.profiles
FOR SELECT
TO authenticated
USING (id = auth.uid());
