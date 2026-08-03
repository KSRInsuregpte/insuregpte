-- Roll back the safety-system application objects.
--
-- Administrator audit rows are intentionally retained. The harmless expanded
-- admin_audit_events entity-type constraint is also retained so those history
-- rows remain valid. Learners suspended only by an open safety case are
-- restored to active before the enforcement tables are removed.

DO $guard$
BEGIN
    IF to_regclass('public.security_events') IS NULL
       OR to_regclass('public.account_enforcement_cases') IS NULL
       OR to_regclass('public.notification_outbox') IS NULL THEN
        RAISE EXCEPTION
            'The safety-system relations are not fully deployed';
    END IF;
END;
$guard$;

UPDATE public.profiles AS profile
SET status = 'active'
FROM public.account_enforcement_cases AS enforcement
WHERE enforcement.user_id = profile.id
  AND enforcement.status = 'suspended'
  AND profile.status = 'suspended';

DROP TRIGGER IF EXISTS trg_profiles_queue_activation_notification
ON public.profiles;

DROP FUNCTION IF EXISTS public.complete_notification_outbox(
    bigint,boolean,text
);
DROP FUNCTION IF EXISTS public.claim_notification_outbox(integer);
DROP FUNCTION IF EXISTS public.acknowledge_my_security_notice(bigint);
DROP FUNCTION IF EXISTS public.get_my_security_notices(integer);
DROP FUNCTION IF EXISTS public.admin_list_notification_outbox(integer);
DROP FUNCTION IF EXISTS public.admin_restore_user_access(bigint,text);
DROP FUNCTION IF EXISTS public.admin_suspend_user_access(
    bigint,text,timestamptz
);
DROP FUNCTION IF EXISTS public.admin_issue_security_warning(bigint,text);
DROP FUNCTION IF EXISTS public.admin_list_enforcement_cases(integer);
DROP FUNCTION IF EXISTS public.admin_review_security_event(bigint,text,text);
DROP FUNCTION IF EXISTS public.admin_list_security_events(integer);
DROP FUNCTION IF EXISTS public.get_admin_security_summary();
DROP FUNCTION IF EXISTS public.record_security_event(
    text,text,uuid,text,text,jsonb,text,timestamptz
);
DROP FUNCTION IF EXISTS public.fn_scan_long_running_sessions();
DROP FUNCTION IF EXISTS public.fn_queue_account_activation_notification();
DROP FUNCTION IF EXISTS public.fn_queue_safety_notification(
    text,text,uuid,text,bigint,bigint,text,text,jsonb,text
);
DROP FUNCTION IF EXISTS public.fn_insert_security_event(
    text,text,uuid,text,text,jsonb,text,timestamptz
);

DROP TABLE public.notification_outbox;
DROP TABLE public.account_enforcement_cases;
DROP TABLE public.security_events;

NOTIFY pgrst, 'reload schema';
