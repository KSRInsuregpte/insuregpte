-- Read-only InsureGPTE RPC audit.
-- Run this file alone in Supabase SQL Editor and export the result as CSV or JSON.

WITH expected(signature, function_name) AS (
    VALUES
        ('public.fn_create_user_profile()', 'fn_create_user_profile'),
        ('public.save_user_profile(uuid,text,text,text,text,text,text,text,text,text,text,text,jsonb)', 'save_user_profile'),
        ('public.hook_validate_user_registration(jsonb)', 'hook_validate_user_registration'),
        ('public.activate_verified_user()', 'activate_verified_user'),
        ('public.fn_enforce_active_auth_session()', 'fn_enforce_active_auth_session'),
        ('public.claim_active_client(uuid,boolean)', 'claim_active_client'),
        ('public.heartbeat_active_client(uuid)', 'heartbeat_active_client'),
        ('public.release_active_client(uuid)', 'release_active_client'),
        ('public.submit_quiz_answer(uuid,bigint,text)', 'submit_quiz_answer'),
        ('public.start_quiz_attempt(bigint,text)', 'start_quiz_attempt'),
        ('public.get_attempt_questions(uuid)', 'get_attempt_questions'),
        ('public.get_my_quiz_attempts()', 'get_my_quiz_attempts'),
        ('public.evaluate_quiz_answer(uuid,bigint,text)', 'evaluate_quiz_answer'),
        ('public.finalize_quiz_attempt(uuid)', 'finalize_quiz_attempt'),
        ('public.finalize_quiz_attempt_with_answers(uuid)', 'finalize_quiz_attempt_with_answers'),
        ('public.get_subject_catalogue()', 'get_subject_catalogue'),
        ('public.add_subject_to_cart(bigint)', 'add_subject_to_cart'),
        ('public.remove_subject_from_cart(bigint)', 'remove_subject_from_cart'),
        ('public.get_my_cart()', 'get_my_cart'),
        ('public.get_exam_information(text,text,text)', 'get_exam_information'),
        ('public.fn_is_admin()', 'fn_is_admin'),
        ('public.get_admin_portal_summary()', 'get_admin_portal_summary'),
        ('public.admin_list_subjects()', 'admin_list_subjects'),
        ('public.admin_save_subject(jsonb)', 'admin_save_subject'),
        ('public.admin_list_questions(bigint)', 'admin_list_questions'),
        ('public.admin_save_question(jsonb)', 'admin_save_question'),
        ('public.admin_list_users()', 'admin_list_users'),
        ('public.admin_set_user_status(uuid,text)', 'admin_set_user_status'),
        ('public.admin_list_exam_information()', 'admin_list_exam_information'),
        ('public.admin_save_exam_information(jsonb)', 'admin_save_exam_information'),
        ('public.admin_retire_exam_information(bigint)', 'admin_retire_exam_information'),
        ('public.admin_list_audit_events(integer)', 'admin_list_audit_events'),
        ('public.admin_bulk_import(text,jsonb)', 'admin_bulk_import'),
        ('public.admin_save_academic_content(text,jsonb)', 'admin_save_academic_content'),
        ('public.admin_save_entitlement(jsonb)', 'admin_save_entitlement'),
        ('public.get_subject_hierarchy(bigint)', 'get_subject_hierarchy'),
        ('public.get_modules_by_subject(bigint)', 'get_modules_by_subject'),
        ('public.get_chapters_by_module(integer)', 'get_chapters_by_module'),
        ('public.get_topics_by_chapter(integer)', 'get_topics_by_chapter'),
        ('public.get_topic_details(integer)', 'get_topic_details'),
        ('public.get_learning_resources(integer)', 'get_learning_resources'),
        ('public.get_flashcards(integer)', 'get_flashcards'),
        ('public.record_learning_activity(integer,text,bigint,integer,numeric)', 'record_learning_activity'),
        ('public.get_resume_learning(bigint)', 'get_resume_learning'),
        ('public.get_recent_activity(integer)', 'get_recent_activity'),
        ('public.get_topic_completion(integer)', 'get_topic_completion'),
        ('public.get_learning_statistics(bigint)', 'get_learning_statistics'),
        ('public.upsert_user_topic_progress(uuid,integer,text,numeric,integer)', 'upsert_user_topic_progress')
), resolved AS (
    SELECT signature, function_name,
        pg_catalog.to_regprocedure(signature) AS procedure_oid
    FROM expected
)
SELECT
    resolved.signature,
    resolved.function_name,
    resolved.procedure_oid IS NOT NULL AS exists,
    CASE WHEN resolved.procedure_oid IS NULL THEN NULL ELSE role_record.rolname END AS owner,
    CASE WHEN resolved.procedure_oid IS NULL THEN NULL ELSE procedure_record.prosecdef END AS security_definer,
    CASE WHEN resolved.procedure_oid IS NULL THEN NULL ELSE procedure_record.proconfig END AS settings,
    CASE WHEN resolved.procedure_oid IS NULL THEN NULL ELSE pg_catalog.has_function_privilege('anon', resolved.procedure_oid, 'EXECUTE') END AS anon_execute,
    CASE WHEN resolved.procedure_oid IS NULL THEN NULL ELSE pg_catalog.has_function_privilege('authenticated', resolved.procedure_oid, 'EXECUTE') END AS authenticated_execute,
    CASE WHEN resolved.procedure_oid IS NULL THEN NULL ELSE pg_catalog.has_function_privilege('service_role', resolved.procedure_oid, 'EXECUTE') END AS service_role_execute,
    CASE WHEN resolved.procedure_oid IS NULL THEN NULL ELSE pg_catalog.pg_get_function_result(resolved.procedure_oid) END AS return_type,
    CASE WHEN resolved.procedure_oid IS NULL THEN NULL ELSE pg_catalog.pg_get_functiondef(resolved.procedure_oid) END AS definition
FROM resolved
LEFT JOIN pg_catalog.pg_proc AS procedure_record
    ON procedure_record.oid = resolved.procedure_oid
LEFT JOIN pg_catalog.pg_roles AS role_record
    ON role_record.oid = procedure_record.proowner
ORDER BY resolved.function_name;
