-- Emergency rollback for 20260719182000_harden_profile_registration.sql.
-- This intentionally restores the insecure state captured on 2026-07-19.
-- Run the 1810 privilege rollback separately only if its grants must also
-- be restored.

DROP TRIGGER IF EXISTS trg_auth_users_create_profile ON auth.users;

DROP FUNCTION IF EXISTS public.fn_create_user_profile();

CREATE OR REPLACE FUNCTION public.save_user_profile(user_id uuid, fname text, lname text, mob text, prof text, company text, bldg text, st text, ar text, ct text, pin text, cnt text, subjects jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN

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
        user_id,
        fname,
        lname,
        mob,
        company,
        prof,
        bldg,
        st,
        ar,
        ct,
        pin,
        cnt,
        subjects,
        'verification_pending',
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
$function$

REVOKE ALL ON FUNCTION public.save_user_profile(
    uuid, text, text, text, text, text, text,
    text, text, text, text, text, jsonb
) FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.save_user_profile(
    uuid, text, text, text, text, text, text,
    text, text, text, text, text, jsonb
) TO PUBLIC, postgres, anon, authenticated, service_role;

DROP POLICY IF EXISTS profiles_select_own ON public.profiles;

CREATE POLICY "Allow authenticated users to manage their own profile"
ON public.profiles
AS PERMISSIVE
FOR ALL
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

CREATE POLICY "Allow users to insert their own profile"
ON public.profiles
AS PERMISSIVE
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

CREATE POLICY "Enable insert for authenticated users only"
ON public.profiles
AS PERMISSIVE
FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "Users can update their own profile"
ON public.profiles
AS PERMISSIVE
FOR UPDATE
TO authenticated
USING (auth.uid() = id);

CREATE POLICY "Users can view their own profile"
ON public.profiles
AS PERMISSIVE
FOR SELECT
TO authenticated
USING (auth.uid() = id);

ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;

