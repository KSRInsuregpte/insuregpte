-- Add one atomic administrator bulk-import coordinator.
--
-- Existing subjects, questions, profiles, auth identities, administrator
-- audit history, and single-record administrator RPCs are reused. No table is
-- created and no existing function signature is changed.
--
-- The browser validates and previews CSV rows for usability. This function is
-- the authoritative security boundary and applies the whole file in one
-- transaction by delegating each row to the existing audited save RPC.
--
-- Safe operational rollback:
--   supabase/rollbacks/20260730150000_add_admin_bulk_import.sql

BEGIN;

DO $guard$
DECLARE
    v_signature text;
    v_definition text;
BEGIN
    IF pg_catalog.to_regclass('public.subjects') IS NULL
       OR pg_catalog.to_regclass('public.questions') IS NULL
       OR pg_catalog.to_regclass('public.profiles') IS NULL
       OR pg_catalog.to_regclass('public.admin_audit_events') IS NULL THEN
        RAISE EXCEPTION
            'Deploy the academic, profile, and administrator migrations before bulk import.';
    END IF;

    FOREACH v_signature IN ARRAY ARRAY[
        'public.fn_is_admin()',
        'public.admin_save_subject(jsonb)',
        'public.admin_save_question(jsonb)',
        'public.admin_set_user_status(uuid,text)'
    ]
    LOOP
        IF pg_catalog.to_regprocedure(v_signature) IS NULL THEN
            RAISE EXCEPTION 'Required existing function % is missing.',
                v_signature;
        END IF;
    END LOOP;

    SELECT pg_catalog.pg_get_functiondef(
        pg_catalog.to_regprocedure(
            'public.admin_save_question(jsonb)'
        )
    )
    INTO v_definition;

    IF v_definition NOT LIKE '%v_correct_answer%'
       OR v_definition NOT LIKE
          '%correct_option = v_correct_answer%' THEN
        RAISE EXCEPTION
            'Deploy the administrator question-answer storage repair before bulk import.';
    END IF;

    IF pg_catalog.to_regprocedure(
        'public.admin_bulk_import(text,jsonb)'
    ) IS NOT NULL THEN
        RAISE EXCEPTION
            'admin_bulk_import(text,jsonb) already exists; review before deploying a duplicate.';
    END IF;
END;
$guard$;

CREATE FUNCTION public.admin_bulk_import(
    p_entity text,
    p_rows jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_entity text := pg_catalog.lower(
        pg_catalog.btrim(COALESCE(p_entity, ''))
    );
    v_row_count integer;
    v_row_number integer;
    v_row jsonb;
    v_payload jsonb;
    v_record_id bigint;
    v_subject_id integer;
    v_user_id uuid;
    v_email text;
    v_error_message text;
    v_record_keys jsonb := '[]'::jsonb;
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;

    IF v_entity NOT IN ('users', 'subjects', 'questions') THEN
        RAISE EXCEPTION
            'Select users, subjects, or questions for bulk import.';
    END IF;

    IF p_rows IS NULL
       OR pg_catalog.jsonb_typeof(p_rows) <> 'array' THEN
        RAISE EXCEPTION 'Bulk import rows must be supplied as a JSON array.';
    END IF;

    v_row_count := pg_catalog.jsonb_array_length(p_rows);
    IF v_row_count NOT BETWEEN 1 AND 250 THEN
        RAISE EXCEPTION
            'A bulk import must contain between 1 and 250 rows.';
    END IF;

    FOR v_row, v_row_number IN
        SELECT row_data.value, row_data.ordinality::integer
        FROM pg_catalog.jsonb_array_elements(p_rows)
            WITH ORDINALITY AS row_data(value, ordinality)
    LOOP
        BEGIN
            IF pg_catalog.jsonb_typeof(v_row) <> 'object' THEN
                RAISE EXCEPTION 'Each bulk import row must be an object.';
            END IF;

            CASE v_entity
                WHEN 'subjects' THEN
                    v_record_id := public.admin_save_subject(v_row);
                    v_record_keys := v_record_keys
                        || pg_catalog.jsonb_build_array(v_record_id);

                WHEN 'questions' THEN
                    SELECT subject_record.id
                    INTO v_subject_id
                    FROM public.subjects AS subject_record
                    WHERE pg_catalog.upper(subject_record.code) =
                        pg_catalog.upper(
                                pg_catalog.btrim(
                                COALESCE(
                                    v_row ->> 'subject_code',
                                    ''
                                )
                            )
                        );

                    IF v_subject_id IS NULL THEN
                        RAISE EXCEPTION
                            'The subject_code does not match an existing subject.';
                    END IF;

                    v_payload := (v_row - 'subject_code')
                        || pg_catalog.jsonb_build_object(
                            'subject_id',
                            v_subject_id
                        );
                    v_record_id := public.admin_save_question(v_payload);
                    v_record_keys := v_record_keys
                        || pg_catalog.jsonb_build_array(v_record_id);

                WHEN 'users' THEN
                    v_email := pg_catalog.lower(
                        pg_catalog.btrim(
                            COALESCE(v_row ->> 'email', '')
                        )
                    );
                    IF v_email = '' THEN
                        RAISE EXCEPTION 'An existing user email is required.';
                    END IF;

                    SELECT auth_user.id
                    INTO v_user_id
                    FROM auth.users AS auth_user
                    JOIN public.profiles AS profile_record
                      ON profile_record.id = auth_user.id
                    WHERE pg_catalog.lower(auth_user.email) = v_email;

                    IF v_user_id IS NULL THEN
                        RAISE EXCEPTION
                            'The email does not match an existing registered user.';
                    END IF;

                    PERFORM public.admin_set_user_status(
                        v_user_id,
                        v_row ->> 'status'
                    );
                    v_record_keys := v_record_keys
                        || pg_catalog.jsonb_build_array(v_user_id::text);
            END CASE;
        EXCEPTION
            WHEN OTHERS THEN
                GET STACKED DIAGNOSTICS
                    v_error_message = MESSAGE_TEXT;
                RAISE EXCEPTION
                    'Bulk import CSV row % failed: %',
                    v_row_number + 1,
                    v_error_message;
        END;
    END LOOP;

    RETURN pg_catalog.jsonb_build_object(
        'entity',
        v_entity,
        'processed_count',
        v_row_count,
        'record_keys',
        v_record_keys
    );
END;
$function$;

ALTER FUNCTION public.admin_bulk_import(text, jsonb) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.admin_bulk_import(text, jsonb)
FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.admin_bulk_import(text, jsonb)
TO authenticated;

COMMENT ON FUNCTION public.admin_bulk_import(text, jsonb) IS
    'Atomically applies up to 250 administrator-reviewed user-status, subject, or MCQ CSV rows through the existing audited save RPCs.';

NOTIFY pgrst, 'reload schema';

COMMIT;
