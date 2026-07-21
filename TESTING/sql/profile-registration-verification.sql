-- Run after 20260719182000_harden_profile_registration.sql in a
-- non-production environment. This script does not modify application data.

DO $verification$
DECLARE
    v_save_profile_oid oid;
    v_trigger_function_oid oid;
    v_definition text;
    v_rls_enabled boolean;
    v_policy_count integer;
    v_trigger_count integer;
BEGIN
    SELECT table_class.relrowsecurity
    INTO v_rls_enabled
    FROM pg_catalog.pg_class AS table_class
    WHERE table_class.oid = 'public.profiles'::regclass;

    IF v_rls_enabled IS NOT TRUE THEN
        RAISE EXCEPTION 'RLS is not enabled on public.profiles';
    END IF;

    SELECT COUNT(*)
    INTO v_policy_count
    FROM pg_catalog.pg_policies AS policy
    WHERE policy.schemaname = 'public'
      AND policy.tablename = 'profiles';

    IF v_policy_count <> 1 THEN
        RAISE EXCEPTION
            'Expected one profiles policy, found %',
            v_policy_count;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_policies AS policy
        WHERE policy.schemaname = 'public'
          AND policy.tablename = 'profiles'
          AND policy.policyname = 'profiles_select_own'
          AND policy.cmd = 'SELECT'
          AND policy.roles = ARRAY['authenticated']::name[]
          AND policy.qual = '(id = auth.uid())'
    ) THEN
        RAISE EXCEPTION 'profiles_select_own is missing or incorrect';
    END IF;

    SELECT COUNT(*)
    INTO v_trigger_count
    FROM pg_catalog.pg_trigger AS trigger_record
    WHERE trigger_record.tgrelid = 'auth.users'::regclass
      AND trigger_record.tgname = 'trg_auth_users_create_profile'
      AND trigger_record.tgisinternal IS FALSE;

    IF v_trigger_count <> 1 THEN
        RAISE EXCEPTION 'The auth profile creation trigger is missing';
    END IF;

    v_trigger_function_oid := to_regprocedure(
        'public.fn_create_user_profile()'
    );

    IF v_trigger_function_oid IS NULL THEN
        RAISE EXCEPTION 'fn_create_user_profile is missing';
    END IF;

    IF has_function_privilege(
        'anon',
        v_trigger_function_oid,
        'EXECUTE'
    ) OR has_function_privilege(
        'authenticated',
        v_trigger_function_oid,
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'Browser roles must not execute fn_create_user_profile';
    END IF;

    v_save_profile_oid := to_regprocedure(
        'public.save_user_profile('
        || 'uuid,text,text,text,text,text,text,'
        || 'text,text,text,text,text,jsonb)'
    );

    IF v_save_profile_oid IS NULL THEN
        RAISE EXCEPTION 'The deployed save_user_profile signature changed';
    END IF;

    SELECT pg_catalog.pg_get_functiondef(procedure.oid)
    INTO v_definition
    FROM pg_catalog.pg_proc AS procedure
    WHERE procedure.oid = v_save_profile_oid;

    IF v_definition NOT LIKE '%auth.uid()%' THEN
        RAISE EXCEPTION 'save_user_profile auth.uid validation is missing';
    END IF;

    IF has_function_privilege(
        'anon',
        v_save_profile_oid,
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'anon must not execute save_user_profile';
    END IF;

    IF NOT has_function_privilege(
        'authenticated',
        v_save_profile_oid,
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'authenticated requires save_user_profile EXECUTE';
    END IF;
END;
$verification$;

-- Functional verification:
-- 1. Register a new user with email confirmation enabled.
-- 2. Confirm one verification_pending profile is created automatically.
-- 3. Verify role=user and subscription_plan=free regardless of user metadata.
-- 4. Confirm the email and verify the existing activation trigger sets active.
-- 5. Verify authenticated SELECT returns only the current user's profile.
-- 6. Verify direct INSERT, UPDATE, and DELETE are denied.
-- 7. Verify an authenticated save_user_profile call cannot target another ID.

