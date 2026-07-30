-- Remove the administration boundary introduced by the matching migration.
--
-- Subject, question, user-status, and examination-information records changed
-- through the portal are business data and are intentionally preserved.

DROP FUNCTION IF EXISTS public.admin_list_audit_events(integer);
DROP FUNCTION IF EXISTS public.admin_retire_exam_information(bigint);
DROP FUNCTION IF EXISTS public.admin_save_exam_information(jsonb);
DROP FUNCTION IF EXISTS public.admin_list_exam_information();
DROP FUNCTION IF EXISTS public.admin_set_user_status(uuid,text);
DROP FUNCTION IF EXISTS public.admin_list_users();
DROP FUNCTION IF EXISTS public.admin_save_question(jsonb);
DROP FUNCTION IF EXISTS public.admin_list_questions(bigint);
DROP FUNCTION IF EXISTS public.admin_save_subject(jsonb);
DROP FUNCTION IF EXISTS public.admin_list_subjects();
DROP FUNCTION IF EXISTS public.get_admin_portal_summary();
DROP FUNCTION IF EXISTS public.fn_is_admin();

DROP TABLE IF EXISTS public.admin_audit_events;

NOTIFY pgrst, 'reload schema';
