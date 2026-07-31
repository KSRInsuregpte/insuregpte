-- Remove the expanded administrator bulk-upload routes while preserving every
-- record already imported. The original Users / Subjects / Questions bulk
-- coordinator remains available.

BEGIN;

CREATE OR REPLACE FUNCTION public.admin_bulk_import(
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
                RAISE EXCEPTION
                    'Each bulk import row must be an object.';
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
                        RAISE EXCEPTION
                            'An existing user email is required.';
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
                        || pg_catalog.jsonb_build_array(
                            v_user_id::text
                        );
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

ALTER FUNCTION public.admin_bulk_import(text, jsonb)
OWNER TO postgres;
REVOKE ALL ON FUNCTION public.admin_bulk_import(text, jsonb)
FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.admin_bulk_import(text, jsonb)
TO authenticated;

DROP FUNCTION IF EXISTS public.admin_save_entitlement(jsonb);
DROP FUNCTION IF EXISTS
    public.admin_save_academic_content(text, jsonb);

DO $restore_official_notice$
DECLARE
    v_definition text;
    v_restored_definition text;
BEGIN
    IF EXISTS (
        SELECT 1
        FROM public.regulatory_academic_publications AS publication
        WHERE publication.document_type = 'official_notice'
    ) THEN
        RAISE NOTICE
            'Official-notice records exist; their compatible constraint and save contract were retained.';
        RETURN;
    END IF;

    ALTER TABLE public.regulatory_academic_publications
    DROP CONSTRAINT
        regulatory_academic_publications_document_type_check;

    ALTER TABLE public.regulatory_academic_publications
    ADD CONSTRAINT
        regulatory_academic_publications_document_type_check
    CHECK (
        document_type = ANY (
            ARRAY[
                'handbook'::text,
                'syllabus'::text,
                'credit_points'::text,
                'subject_amendment'::text,
                'withdrawal_notice'::text,
                'schedule'::text,
                'centre_list'::text,
                'language_list'::text
            ]
        )
    );

    SELECT pg_catalog.pg_get_functiondef(
        pg_catalog.to_regprocedure(
            'public.admin_save_exam_information(jsonb)'
        )
    )
    INTO v_definition;

    v_restored_definition := pg_catalog.replace(
        v_definition,
        E'        ''official_notice'',\n',
        ''
    );

    IF v_restored_definition = v_definition THEN
        RAISE EXCEPTION
            'Unable to restore the prior examination-information document-type validation.';
    END IF;

    EXECUTE v_restored_definition;
END;
$restore_official_notice$;

COMMENT ON FUNCTION public.admin_bulk_import(text, jsonb) IS
    'Atomically applies up to 250 administrator-reviewed user-status, subject, or MCQ CSV rows through the existing audited save RPCs.';

NOTIFY pgrst, 'reload schema';

COMMIT;
