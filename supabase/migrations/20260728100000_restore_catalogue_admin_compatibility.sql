-- Restore the intended RPC-only learner boundary after the admin hardening
-- migration.
--
-- This migration does not create or replace any table or RPC. It verifies
-- that the catalogue and demo migrations were deployed first, restores the
-- approved function ownership and execution grants, and keeps direct browser
-- access to subjects and questions revoked.
--
-- Required deployment order:
--   1. 20260725120000_launch_subject_catalogue.sql
--   2. 20260725121000_gate_quiz_access_and_enable_demo.sql
--   3. 20260727120000_map_regulatory_metadata_and_exam_information.sql
--   4. 20260727180000_build_admin_portal.sql
--   5. this migration
--
-- Rollback:
--   supabase/rollbacks/
--     20260728100000_restore_catalogue_admin_compatibility.sql

DO $guard$
DECLARE
    v_signature text;
    v_function_oid regprocedure;
BEGIN
    FOREACH v_signature IN ARRAY ARRAY[
        'public.get_subject_catalogue()',
        'public.add_subject_to_cart(bigint)',
        'public.remove_subject_from_cart(bigint)',
        'public.get_my_cart()',
        'public.get_my_quiz_attempts()',
        'public.start_quiz_attempt(bigint,text)',
        'public.fn_is_admin()'
    ]
    LOOP
        v_function_oid := pg_catalog.to_regprocedure(v_signature);

        IF v_function_oid IS NULL THEN
            RAISE EXCEPTION
                'Required RPC % is missing. Deploy the catalogue and demo migrations before this compatibility migration.',
                v_signature;
        END IF;

        IF v_signature IN (
            'public.get_subject_catalogue()',
            'public.add_subject_to_cart(bigint)',
            'public.remove_subject_from_cart(bigint)',
            'public.get_my_cart()'
        ) AND NOT (
            SELECT procedure_record.prosecdef
            FROM pg_catalog.pg_proc AS procedure_record
            WHERE procedure_record.oid = v_function_oid
        ) THEN
            RAISE EXCEPTION
                'Required catalogue RPC % is not SECURITY DEFINER',
                v_signature;
        END IF;
    END LOOP;

    IF NOT EXISTS (
        SELECT 1
        FROM public.quiz_mode_config AS mode_record
        WHERE mode_record.test_mode = 'demo'
          AND mode_record.is_active = true
    ) THEN
        RAISE EXCEPTION
            'The active demo quiz configuration is missing. Deploy 20260725121000_gate_quiz_access_and_enable_demo.sql first.';
    END IF;
END;
$guard$;

ALTER FUNCTION public.get_subject_catalogue() OWNER TO postgres;
ALTER FUNCTION public.add_subject_to_cart(bigint) OWNER TO postgres;
ALTER FUNCTION public.remove_subject_from_cart(bigint) OWNER TO postgres;
ALTER FUNCTION public.get_my_cart() OWNER TO postgres;

REVOKE ALL ON FUNCTION public.get_subject_catalogue()
FROM PUBLIC, service_role;
GRANT EXECUTE ON FUNCTION public.get_subject_catalogue()
TO anon, authenticated;

REVOKE ALL ON FUNCTION public.add_subject_to_cart(bigint)
FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.add_subject_to_cart(bigint)
TO authenticated;

REVOKE ALL ON FUNCTION public.remove_subject_from_cart(bigint)
FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.remove_subject_from_cart(bigint)
TO authenticated;

REVOKE ALL ON FUNCTION public.get_my_cart()
FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_my_cart()
TO authenticated;

-- Preserve the administrator hardening boundary. Production and preview
-- frontends must use the approved RPCs instead of direct table access.
REVOKE ALL ON TABLE public.subjects
FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.questions
FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.subjects_id_seq
FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.questions_id_seq
FROM PUBLIC, anon, authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE
ON TABLE public.subjects TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE
ON TABLE public.questions TO service_role;
GRANT USAGE, SELECT ON SEQUENCE public.subjects_id_seq
TO service_role;
GRANT USAGE, SELECT ON SEQUENCE public.questions_id_seq
TO service_role;

NOTIFY pgrst, 'reload schema';
