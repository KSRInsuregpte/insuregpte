-- Restore dual email/mobile activation. Review affected active users before
-- running this rollback in production.

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

UPDATE public.profiles AS profile_record
SET status = 'verification_pending'
FROM auth.users AS auth_user
WHERE auth_user.id = profile_record.id
  AND profile_record.registration_security_version >= 2
  AND profile_record.status = 'active'
  AND (
      auth_user.email_confirmed_at IS NULL
      OR auth_user.phone_confirmed_at IS NULL
      OR auth_user.phone IS DISTINCT FROM profile_record.mobile
  );

NOTIFY pgrst, 'reload schema';
