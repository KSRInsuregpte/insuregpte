-- Run after:
-- supabase/migrations/20260723214500_defer_mobile_verification.sql
-- Expected result: Success. No rows returned.

DO $verification$
DECLARE
    v_activate_oid regprocedure :=
        pg_catalog.to_regprocedure('public.activate_verified_user()');
    v_guard_oid regprocedure :=
        pg_catalog.to_regprocedure(
            'public.fn_enforce_active_auth_session()'
        );
    v_definition text;
BEGIN
    IF v_activate_oid IS NULL OR v_guard_oid IS NULL THEN
        RAISE EXCEPTION
            'One or more email-only activation functions are missing';
    END IF;

    SELECT pg_catalog.pg_get_functiondef(v_activate_oid)
    INTO v_definition;

    IF v_definition NOT LIKE
        '%WHEN NEW.email_confirmed_at IS NOT NULL THEN%'
       OR v_definition LIKE
        '%WHEN profile_record.registration_security_version >= 2%' THEN
        RAISE EXCEPTION
            'Profile activation still requires mobile confirmation';
    END IF;

    SELECT pg_catalog.pg_get_functiondef(v_guard_oid)
    INTO v_definition;

    IF v_definition NOT LIKE
        '%Complete email verification before continuing.%'
       OR v_definition LIKE
        '%Complete email and mobile verification before continuing.%' THEN
        RAISE EXCEPTION
            'The Data API guard still reports dual verification';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.profiles AS profile_record
        WHERE profile_record.registration_security_version >= 2
          AND profile_record.status = 'active'
          AND profile_record.email_verified_at IS NULL
    ) THEN
        RAISE EXCEPTION
            'A protected account is active without email verification';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.profiles AS profile_record
        JOIN auth.users AS auth_user
          ON auth_user.id = profile_record.id
        WHERE profile_record.status = 'verification_pending'
          AND auth_user.email_confirmed_at IS NOT NULL
    ) THEN
        RAISE EXCEPTION
            'An email-confirmed profile remains verification_pending';
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
            'The existing mobile uniqueness constraint is missing';
    END IF;
END;
$verification$;
