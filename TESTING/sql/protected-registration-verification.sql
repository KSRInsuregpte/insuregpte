-- Run after 20260721130000_protect_user_registration.sql and after selecting
-- public.hook_validate_user_registration as the Before User Created Auth hook.
-- This verification is read-only and does not create application users.

DO $verification$
DECLARE
    v_hook_oid oid := to_regprocedure(
        'public.hook_validate_user_registration(jsonb)'
    );
    v_create_profile_oid oid := to_regprocedure(
        'public.fn_create_user_profile()'
    );
    v_save_profile_oid oid := to_regprocedure(
        'public.save_user_profile('
        || 'uuid,text,text,text,text,text,text,'
        || 'text,text,text,text,text,jsonb)'
    );
    v_guard_oid oid := to_regprocedure(
        'public.fn_enforce_active_auth_session()'
    );
    v_subject_code text;
    v_valid_event jsonb;
    v_result jsonb;
    v_definition text;
    v_trigger_definition text;
BEGIN
    IF v_hook_oid IS NULL THEN
        RAISE EXCEPTION 'The Before User Created hook function is missing';
    END IF;

    IF v_create_profile_oid IS NULL
       OR v_save_profile_oid IS NULL
       OR v_guard_oid IS NULL THEN
        RAISE EXCEPTION 'A protected registration dependency is missing';
    END IF;

    IF has_function_privilege('anon', v_hook_oid, 'EXECUTE')
       OR has_function_privilege('authenticated', v_hook_oid, 'EXECUTE')
       OR has_function_privilege('service_role', v_hook_oid, 'EXECUTE') THEN
        RAISE EXCEPTION 'Browser or service roles can execute the Auth hook';
    END IF;

    IF NOT has_function_privilege(
        'supabase_auth_admin',
        v_hook_oid,
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'supabase_auth_admin cannot execute the Auth hook';
    END IF;

    IF has_function_privilege('anon', v_create_profile_oid, 'EXECUTE')
       OR has_function_privilege(
           'authenticated',
           v_create_profile_oid,
           'EXECUTE'
       ) THEN
        RAISE EXCEPTION 'Browser roles can execute the profile trigger function';
    END IF;

    IF has_function_privilege('anon', v_save_profile_oid, 'EXECUTE')
       OR NOT has_function_privilege(
           'authenticated',
           v_save_profile_oid,
           'EXECUTE'
       ) THEN
        RAISE EXCEPTION 'save_user_profile grants are incorrect';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns AS column_record
        WHERE column_record.table_schema = 'public'
          AND column_record.table_name = 'profiles'
          AND column_record.column_name = 'registration_source'
    ) OR NOT EXISTS (
        SELECT 1
        FROM information_schema.columns AS column_record
        WHERE column_record.table_schema = 'public'
          AND column_record.table_name = 'profiles'
          AND column_record.column_name = 'registration_security_version'
          AND column_record.is_nullable = 'NO'
    ) OR NOT EXISTS (
        SELECT 1
        FROM information_schema.columns AS column_record
        WHERE column_record.table_schema = 'public'
          AND column_record.table_name = 'profiles'
          AND column_record.column_name = 'email_verified_at'
    ) OR NOT EXISTS (
        SELECT 1
        FROM information_schema.columns AS column_record
        WHERE column_record.table_schema = 'public'
          AND column_record.table_name = 'profiles'
          AND column_record.column_name = 'mobile_verified_at'
    ) THEN
        RAISE EXCEPTION 'Required protected-registration columns are missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_constraint AS constraint_record
        WHERE constraint_record.conrelid = 'public.profiles'::regclass
          AND constraint_record.conname =
              'chk_profiles_protected_registration_complete'
    ) THEN
        RAISE EXCEPTION 'The complete-registration constraint is missing';
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
        RAISE EXCEPTION 'The existing mobile uniqueness constraint is missing';
    END IF;

    SELECT pg_catalog.pg_get_triggerdef(trigger_record.oid)
    INTO v_trigger_definition
    FROM pg_catalog.pg_trigger AS trigger_record
    WHERE trigger_record.tgrelid = 'auth.users'::regclass
      AND trigger_record.tgname = 'trigger_activate_verified_user'
      AND trigger_record.tgisinternal IS FALSE;

    IF v_trigger_definition IS NULL
       OR v_trigger_definition NOT ILIKE '%email_confirmed_at%'
       OR v_trigger_definition NOT ILIKE '%phone_confirmed_at%' THEN
        RAISE EXCEPTION 'The dual-verification trigger is missing or incorrect';
    END IF;

    SELECT pg_catalog.pg_get_functiondef(v_create_profile_oid)
    INTO v_definition;

    IF v_definition NOT LIKE '%registration_security_version%'
       OR v_definition NOT LIKE '%select at least one subject%' THEN
        RAISE EXCEPTION 'The profile creation backstop is incomplete';
    END IF;

    SELECT pg_catalog.pg_get_functiondef(v_save_profile_oid)
    INTO v_definition;

    IF v_definition NOT LIKE '%auth.uid()%'
       OR v_definition NOT LIKE '%OTP verification%' THEN
        RAISE EXCEPTION 'save_user_profile protections are incomplete';
    END IF;

    IF pg_catalog.obj_description(v_guard_oid, 'pg_proc') IS DISTINCT FROM
        'Requires an active verified profile plus the current unexpired active-client lease for authenticated Data API requests.' THEN
        RAISE EXCEPTION 'The verified-profile Data API guard is not active';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.profiles AS profile_record
        WHERE profile_record.registration_security_version >= 2
          AND (
              profile_record.status = 'active'
              AND (
                  profile_record.email_verified_at IS NULL
                  OR profile_record.mobile_verified_at IS NULL
              )
          )
    ) THEN
        RAISE EXCEPTION
            'A protected account is active without both verifications';
    END IF;

    SELECT subject_record.code
    INTO v_subject_code
    FROM public.subjects AS subject_record
    WHERE subject_record.is_active = true
    ORDER BY subject_record.id
    LIMIT 1;

    IF v_subject_code IS NULL THEN
        RAISE EXCEPTION
            'At least one active subject is required for hook verification';
    END IF;

    v_valid_event := jsonb_build_object(
        'user',
        jsonb_build_object(
            'email', 'registration-check@example.com',
            'is_anonymous', false,
            'app_metadata', jsonb_build_object('provider', 'email'),
            'user_metadata', jsonb_build_object(
                'registration_security_version', 2,
                'first_name', 'Test',
                'last_name', 'Learner',
                'mobile', '+919876543210',
                'company_name', 'Test Institution',
                'profession', 'Student',
                'building_name', 'Test House',
                'street_name', 'Test Street',
                'area', 'Test Area',
                'city', 'Chennai',
                'pin_code', '600001',
                'country', 'India',
                'registration_source', 'direct_invitation',
                'registration_source_detail', '',
                'subjects', jsonb_build_array(v_subject_code)
            )
        )
    );

    v_result := public.hook_validate_user_registration(v_valid_event);

    IF v_result <> '{}'::jsonb THEN
        RAISE EXCEPTION 'A valid registration was rejected: %', v_result;
    END IF;

    v_result := public.hook_validate_user_registration(
        jsonb_build_object(
            'user',
            jsonb_build_object(
                'email', 'anonymous@example.com',
                'is_anonymous', true,
                'app_metadata', jsonb_build_object('provider', 'email'),
                'user_metadata', '{}'::jsonb
            )
        )
    );

    IF v_result -> 'error' ->> 'message' NOT ILIKE '%Anonymous%' THEN
        RAISE EXCEPTION 'Anonymous signup was not rejected correctly';
    END IF;

    v_result := public.hook_validate_user_registration(
        jsonb_set(
            v_valid_event,
            '{user,user_metadata,subjects}',
            '[]'::jsonb
        )
    );

    IF v_result -> 'error' ->> 'message' NOT ILIKE '%subject%' THEN
        RAISE EXCEPTION 'An empty subject selection was not rejected';
    END IF;

    v_result := public.hook_validate_user_registration(
        jsonb_set(
            v_valid_event,
            '{user,user_metadata,mobile}',
            '"9876543210"'::jsonb
        )
    );

    IF v_result -> 'error' ->> 'message' NOT ILIKE '%mobile%' THEN
        RAISE EXCEPTION 'A non-E.164 mobile number was not rejected';
    END IF;
END;
$verification$;

-- Manual checks that cannot be proven by database catalogue inspection:
-- 1. Supabase Auth > Hooks shows Before User Created enabled with
--    public.hook_validate_user_registration.
-- 2. CAPTCHA protection is enabled with the matching Turnstile secret.
-- 3. Email confirmation remains enabled and anonymous signup remains disabled.
-- 4. Phone authentication and an SMS provider are configured.
-- 5. Auth password policy requires at least 12 characters, upper/lowercase,
--    a number, and a symbol.
