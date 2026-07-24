-- Temporarily activate complete protected registrations after email OTP only.
-- Mobile remains mandatory, normalized, and unique profile data. Existing
-- mobile verification evidence is preserved, but SMS OTP is not an access gate
-- until a production SMS plan is approved and deployed.

DO $block$
BEGIN
    IF pg_catalog.to_regprocedure(
        'public.activate_verified_user()'
    ) IS NULL
       OR pg_catalog.to_regprocedure(
           'public.fn_enforce_active_auth_session()'
       ) IS NULL THEN
        RAISE EXCEPTION
            'Deploy the protected-registration migration before this migration';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns AS column_record
        WHERE column_record.table_schema = 'public'
          AND column_record.table_name = 'profiles'
          AND column_record.column_name = 'registration_security_version'
    ) THEN
        RAISE EXCEPTION
            'The protected-registration profile columns are missing';
    END IF;
END;
$block$;

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
            WHEN NEW.email_confirmed_at IS NOT NULL THEN
                'active'
            ELSE profile_record.status
        END
    WHERE profile_record.id = NEW.id;

    RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.activate_verified_user()
FROM PUBLIC, anon, authenticated, service_role;

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
                'Complete email verification before continuing.';
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
    'Requires an active email-verified profile plus the current unexpired active-client lease for authenticated Data API requests.';

REVOKE ALL ON FUNCTION public.fn_enforce_active_auth_session()
FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_enforce_active_auth_session()
TO anon, authenticated, service_role, authenticator;

-- Release complete protected registrations that already finished email OTP.
-- Suspended and closed profiles are intentionally not reactivated.
UPDATE public.profiles AS profile_record
SET email_verified_at = auth_user.email_confirmed_at,
    mobile_verified_at = CASE
        WHEN auth_user.phone_confirmed_at IS NOT NULL
         AND auth_user.phone = profile_record.mobile
        THEN auth_user.phone_confirmed_at
        ELSE profile_record.mobile_verified_at
    END,
    status = 'active'
FROM auth.users AS auth_user
WHERE auth_user.id = profile_record.id
  AND profile_record.status = 'verification_pending'
  AND auth_user.email_confirmed_at IS NOT NULL;

NOTIFY pgrst, 'reload schema';
