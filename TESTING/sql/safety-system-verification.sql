-- Run after:
-- supabase/migrations/20260802150000_add_safety_monitoring_and_enforcement.sql
--
-- Expected result: Success. No rows returned.
-- This verification is read-only and does not create alerts, warnings, or
-- suspensions.

DO $verification$
DECLARE
    v_name text;
    v_definition text;
    v_rls boolean;
BEGIN
    FOREACH v_name IN ARRAY ARRAY[
        'public.security_events',
        'public.account_enforcement_cases',
        'public.notification_outbox'
    ]
    LOOP
        IF to_regclass(v_name) IS NULL THEN
            RAISE EXCEPTION 'Missing safety-system relation: %', v_name;
        END IF;

        SELECT relation.relrowsecurity
        INTO v_rls
        FROM pg_catalog.pg_class AS relation
        WHERE relation.oid = to_regclass(v_name);

        IF v_rls IS DISTINCT FROM true THEN
            RAISE EXCEPTION 'RLS is not enabled on %', v_name;
        END IF;
    END LOOP;

    FOREACH v_name IN ARRAY ARRAY[
        'public.fn_insert_security_event(text,text,uuid,text,text,jsonb,text,timestamp with time zone)',
        'public.fn_queue_safety_notification(text,text,uuid,text,bigint,bigint,text,text,jsonb,text)',
        'public.fn_queue_account_activation_notification()',
        'public.fn_scan_long_running_sessions()',
        'public.record_security_event(text,text,uuid,text,text,jsonb,text,timestamp with time zone)',
        'public.get_admin_security_summary()',
        'public.admin_list_security_events(integer)',
        'public.admin_review_security_event(bigint,text,text)',
        'public.admin_list_enforcement_cases(integer)',
        'public.admin_issue_security_warning(bigint,text)',
        'public.admin_suspend_user_access(bigint,text,timestamp with time zone)',
        'public.admin_restore_user_access(bigint,text)',
        'public.admin_list_notification_outbox(integer)',
        'public.get_my_security_notices(integer)',
        'public.acknowledge_my_security_notice(bigint)',
        'public.claim_notification_outbox(integer)',
        'public.complete_notification_outbox(bigint,boolean,text)'
    ]
    LOOP
        IF to_regprocedure(v_name) IS NULL THEN
            RAISE EXCEPTION 'Missing safety-system function: %', v_name;
        END IF;
    END LOOP;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_trigger AS trigger_record
        WHERE trigger_record.tgrelid = 'public.profiles'::regclass
          AND trigger_record.tgname =
              'trg_profiles_queue_activation_notification'
          AND NOT trigger_record.tgisinternal
    ) THEN
        RAISE EXCEPTION
            'The account-activation notification trigger is missing';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.role_table_grants AS grant_record
        WHERE grant_record.table_schema = 'public'
          AND grant_record.table_name IN (
              'security_events',
              'account_enforcement_cases',
              'notification_outbox'
          )
          AND grant_record.grantee IN (
              'anon',
              'authenticated',
              'service_role'
          )
    ) THEN
        RAISE EXCEPTION
            'A governed safety table has a direct application-role grant';
    END IF;

    SELECT pg_get_functiondef(
        'public.admin_issue_security_warning(bigint,text)'::regprocedure
    )
    INTO v_definition;

    IF v_definition NOT LIKE '%public.fn_is_admin()%'
       OR v_definition NOT LIKE '%warning_count >= 3%'
       OR v_definition NOT LIKE '%warning_count = warning_count + 1%' THEN
        RAISE EXCEPTION
            'The administrator warning function is not safely constrained';
    END IF;

    SELECT pg_get_functiondef(
        'public.admin_suspend_user_access(bigint,text,timestamp with time zone)'::regprocedure
    )
    INTO v_definition;

    IF v_definition NOT LIKE '%public.fn_is_admin()%'
       OR v_definition NOT LIKE '%warning_count < 3%'
       OR v_definition NOT LIKE '%critical_attack%'
       OR v_definition NOT LIKE '%role = ''admin''%'
       OR v_definition NOT LIKE '%status = ''suspended''%'
       OR v_definition NOT LIKE '%DELETE FROM public.active_client_leases%' THEN
        RAISE EXCEPTION
            'The suspension function does not enforce the approved policy';
    END IF;

    SELECT pg_get_functiondef(
        'public.admin_restore_user_access(bigint,text)'::regprocedure
    )
    INTO v_definition;

    IF v_definition NOT LIKE '%public.fn_is_admin()%'
       OR v_definition NOT LIKE '%status = ''active''%'
       OR v_definition NOT LIKE '%status = ''restored''%' THEN
        RAISE EXCEPTION
            'The restoration function does not restore the profile and case';
    END IF;

    SELECT pg_get_functiondef(
        'public.fn_scan_long_running_sessions()'::regprocedure
    )
    INTO v_definition;

    IF v_definition NOT LIKE '%interval ''48 hours''%'
       OR v_definition NOT LIKE '%active_client_leases%'
       OR v_definition LIKE '%auth.sessions%' THEN
        RAISE EXCEPTION
            'The long-session scan does not use the approved lease boundary';
    END IF;

    IF NOT has_function_privilege(
        'authenticated',
        'public.get_admin_security_summary()',
        'EXECUTE'
    ) OR NOT has_function_privilege(
        'authenticated',
        'public.get_my_security_notices(integer)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'The intended authenticated RPC grants are missing';
    END IF;

    IF has_function_privilege(
        'anon',
        'public.get_admin_security_summary()',
        'EXECUTE'
    ) OR has_function_privilege(
        'authenticated',
        'public.claim_notification_outbox(integer)',
        'EXECUTE'
    ) OR NOT has_function_privilege(
        'service_role',
        'public.claim_notification_outbox(integer)',
        'EXECUTE'
    ) OR has_function_privilege(
        'authenticated',
        'public.record_security_event(text,text,uuid,text,text,jsonb,text,timestamp with time zone)',
        'EXECUTE'
    ) OR NOT has_function_privilege(
        'service_role',
        'public.record_security_event(text,text,uuid,text,text,jsonb,text,timestamp with time zone)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'Safety RPC execution privileges are not correctly restricted';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_constraint AS constraint_record
        WHERE constraint_record.conrelid =
              'public.admin_audit_events'::regclass
          AND constraint_record.conname =
              'admin_audit_events_entity_type_check'
          AND pg_get_constraintdef(constraint_record.oid)
              LIKE '%security_event%'
          AND pg_get_constraintdef(constraint_record.oid)
              LIKE '%enforcement_case%'
    ) THEN
        RAISE EXCEPTION
            'Administrator audit history does not accept safety actions';
    END IF;
END;
$verification$;
