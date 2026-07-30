-- Build the audited InsureGPTE administration boundary.
--
-- This migration reuses profiles, subjects, questions, the academic hierarchy,
-- auth.users, and regulatory_academic_publications. It creates only the
-- missing administrative audit-history table and exposes administrator-only
-- RPCs. Browser roles receive no direct table access.
--
-- Rollback:
--   supabase/rollbacks/20260727180000_build_admin_portal.sql

DO $guard$
DECLARE
    v_required_table text;
    v_function_signature text;
BEGIN
    FOREACH v_required_table IN ARRAY ARRAY[
        'profiles',
        'subjects',
        'questions',
        'qualification_levels',
        'exam_authorities',
        'training_programmes',
        'programme_sections',
        'regulatory_academic_publications'
    ]
    LOOP
        IF pg_catalog.to_regclass(
            pg_catalog.format('public.%I', v_required_table)
        ) IS NULL THEN
            RAISE EXCEPTION 'Required table public.% is missing',
                v_required_table;
        END IF;
    END LOOP;

    IF pg_catalog.to_regclass('public.admin_audit_events') IS NOT NULL THEN
        RAISE EXCEPTION
            'public.admin_audit_events already exists; audit before deployment';
    END IF;

    FOREACH v_function_signature IN ARRAY ARRAY[
        'public.fn_is_admin()',
        'public.get_admin_portal_summary()',
        'public.admin_list_subjects()',
        'public.admin_save_subject(jsonb)',
        'public.admin_list_questions(bigint)',
        'public.admin_save_question(jsonb)',
        'public.admin_list_users()',
        'public.admin_set_user_status(uuid,text)',
        'public.admin_list_exam_information()',
        'public.admin_save_exam_information(jsonb)',
        'public.admin_retire_exam_information(bigint)',
        'public.admin_list_audit_events(integer)'
    ]
    LOOP
        IF pg_catalog.to_regprocedure(v_function_signature) IS NOT NULL THEN
            RAISE EXCEPTION
                'Function % already exists; audit before deployment',
                v_function_signature;
        END IF;
    END LOOP;

    IF NOT EXISTS (
        SELECT 1
        FROM public.profiles AS profile_record
        WHERE profile_record.role = 'admin'
          AND profile_record.status = 'active'
    ) THEN
        RAISE EXCEPTION
            'At least one active administrator profile is required';
    END IF;
END;
$guard$;

CREATE TABLE public.admin_audit_events (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    action text NOT NULL,
    entity_type text NOT NULL,
    entity_key text NOT NULL,
    change_summary jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT admin_audit_events_action_check
        CHECK (action IN ('create', 'update', 'status_change', 'retire')),
    CONSTRAINT admin_audit_events_entity_type_check
        CHECK (entity_type IN ('subject', 'question', 'user', 'exam_information')),
    CONSTRAINT admin_audit_events_change_summary_check
        CHECK (jsonb_typeof(change_summary) = 'object')
);

CREATE INDEX admin_audit_events_created_at_idx
ON public.admin_audit_events (created_at DESC);

CREATE INDEX admin_audit_events_entity_idx
ON public.admin_audit_events (entity_type, entity_key, created_at DESC);

ALTER TABLE public.admin_audit_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.admin_audit_events
FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON SEQUENCE public.admin_audit_events_id_seq
FROM PUBLIC, anon, authenticated, service_role;

-- Subject and question maintenance is now available only through the guarded
-- administrator RPCs. Existing learner/catalogue/quiz access already uses
-- SECURITY DEFINER RPCs and does not require direct browser-table privileges.
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

CREATE FUNCTION public.fn_is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
    SELECT EXISTS (
        SELECT 1
        FROM public.profiles AS profile_record
        WHERE profile_record.id = auth.uid()
          AND profile_record.role = 'admin'
          AND profile_record.status = 'active'
    );
$function$;

CREATE FUNCTION public.get_admin_portal_summary()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_result jsonb;
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;

    SELECT jsonb_build_object(
        'counts',
        jsonb_build_object(
            'subjects', (
                SELECT COUNT(*) FROM public.subjects
            ),
            'active_subjects', (
                SELECT COUNT(*)
                FROM public.subjects AS subject_record
                WHERE subject_record.is_active = true
            ),
            'questions', (
                SELECT COUNT(*) FROM public.questions
            ),
            'active_questions', (
                SELECT COUNT(*)
                FROM public.questions AS question_record
                WHERE question_record.is_active = true
            ),
            'users', (
                SELECT COUNT(*) FROM public.profiles
            ),
            'active_users', (
                SELECT COUNT(*)
                FROM public.profiles AS profile_record
                WHERE profile_record.status = 'active'
            ),
            'exam_information', (
                SELECT COUNT(*)
                FROM public.regulatory_academic_publications
            ),
            'current_exam_information', (
                SELECT COUNT(*)
                FROM public.regulatory_academic_publications AS publication
                WHERE publication.is_active = true
                  AND (
                      publication.valid_until IS NULL
                      OR publication.valid_until >= CURRENT_DATE
                  )
            )
        ),
        'qualification_levels',
        COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', qualification.id,
                    'code', qualification.code,
                    'name', qualification.name
                )
                ORDER BY qualification.display_order, qualification.name
            )
            FROM public.qualification_levels AS qualification
            WHERE qualification.is_active = true
        ), '[]'::jsonb),
        'exam_authorities',
        COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', authority.id,
                    'code', authority.code,
                    'name', authority.name,
                    'short_name', authority.short_name
                )
                ORDER BY authority.name
            )
            FROM public.exam_authorities AS authority
            WHERE authority.is_active = true
        ), '[]'::jsonb),
        'training_programmes',
        COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', programme.id,
                    'exam_authority_id', programme.exam_authority_id,
                    'code', programme.code,
                    'name', programme.name,
                    'programme_category', programme.programme_category
                )
                ORDER BY programme.name
            )
            FROM public.training_programmes AS programme
            WHERE programme.is_active = true
        ), '[]'::jsonb),
        'programme_sections',
        COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', section.id,
                    'training_programme_id', section.training_programme_id,
                    'code', section.code,
                    'name', section.name
                )
                ORDER BY section.name
            )
            FROM public.programme_sections AS section
            WHERE section.is_active = true
        ), '[]'::jsonb)
    )
    INTO v_result;

    RETURN v_result;
END;
$function$;

CREATE FUNCTION public.admin_list_subjects()
RETURNS TABLE (
    subject_id bigint,
    subject_code text,
    subject_title text,
    subject_description text,
    qualification_level_id bigint,
    qualification_level text,
    training_programme_id bigint,
    training_programme text,
    programme_section_id bigint,
    programme_section text,
    category text,
    syllabus_version text,
    display_order integer,
    demo_question_limit integer,
    price numeric,
    currency_code text,
    is_demo_available boolean,
    is_active boolean,
    active_question_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;

    RETURN QUERY
    SELECT
        subject_record.id::bigint,
        subject_record.code,
        subject_record.title,
        subject_record.description,
        qualification.id::bigint,
        qualification.name,
        programme.id::bigint,
        programme.name,
        section.id::bigint,
        section.name,
        subject_record.category,
        subject_record.syllabus_version,
        subject_record.display_order,
        subject_record.demo_question_limit,
        subject_record.price,
        subject_record.currency_code,
        subject_record.is_demo_available,
        subject_record.is_active,
        (
            SELECT COUNT(*)
            FROM public.questions AS question_record
            WHERE question_record.subject_id = subject_record.id
              AND question_record.is_active = true
        )
    FROM public.subjects AS subject_record
    LEFT JOIN public.qualification_levels AS qualification
      ON qualification.id = subject_record.qualification_level_id
    LEFT JOIN public.training_programmes AS programme
      ON programme.id = subject_record.training_programme_id
    LEFT JOIN public.programme_sections AS section
      ON section.id = subject_record.programme_section_id
    ORDER BY subject_record.display_order, subject_record.code;
END;
$function$;

CREATE FUNCTION public.admin_save_subject(p_subject jsonb)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_actor uuid := auth.uid();
    v_subject_id integer;
    v_code text := UPPER(BTRIM(COALESCE(p_subject ->> 'code', '')));
    v_title text := BTRIM(COALESCE(p_subject ->> 'title', ''));
    v_description text := NULLIF(BTRIM(p_subject ->> 'description'), '');
    v_qualification_level_id integer :=
        NULLIF(p_subject ->> 'qualification_level_id', '')::integer;
    v_training_programme_id integer :=
        NULLIF(p_subject ->> 'training_programme_id', '')::integer;
    v_programme_section_id integer :=
        NULLIF(p_subject ->> 'programme_section_id', '')::integer;
    v_category text := NULLIF(BTRIM(p_subject ->> 'category'), '');
    v_syllabus_version text :=
        NULLIF(BTRIM(p_subject ->> 'syllabus_version'), '');
    v_display_order integer :=
        COALESCE(NULLIF(p_subject ->> 'display_order', '')::integer, 1);
    v_demo_question_limit integer :=
        COALESCE(NULLIF(p_subject ->> 'demo_question_limit', '')::integer, 10);
    v_price numeric :=
        COALESCE(NULLIF(p_subject ->> 'price', '')::numeric, 0);
    v_currency_code text :=
        UPPER(BTRIM(COALESCE(p_subject ->> 'currency_code', 'INR')));
    v_is_demo_available boolean :=
        COALESCE((p_subject ->> 'is_demo_available')::boolean, false);
    v_is_active boolean :=
        COALESCE((p_subject ->> 'is_active')::boolean, false);
    v_action text;
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;

    v_subject_id := NULLIF(p_subject ->> 'id', '')::integer;

    IF v_code !~ '^[A-Z0-9][A-Z0-9-]{1,19}$' THEN
        RAISE EXCEPTION
            'Use 2-20 uppercase letters, numbers, or hyphens for the subject code.';
    END IF;
    IF CHAR_LENGTH(v_title) NOT BETWEEN 2 AND 160 THEN
        RAISE EXCEPTION 'Enter a subject title between 2 and 160 characters.';
    END IF;
    IF v_display_order < 1 THEN
        RAISE EXCEPTION 'Display order must be at least 1.';
    END IF;
    IF v_demo_question_limit NOT BETWEEN 0 AND 50 THEN
        RAISE EXCEPTION 'Demo question limit must be between 0 and 50.';
    END IF;
    IF v_price < 0 THEN
        RAISE EXCEPTION 'Subject price cannot be negative.';
    END IF;
    IF v_currency_code !~ '^[A-Z]{3}$' THEN
        RAISE EXCEPTION 'Currency code must contain three letters.';
    END IF;

    IF v_qualification_level_id IS NOT NULL
       AND NOT EXISTS (
           SELECT 1
           FROM public.qualification_levels AS qualification
           WHERE qualification.id = v_qualification_level_id
       ) THEN
        RAISE EXCEPTION 'The selected qualification level is unavailable.';
    END IF;

    IF v_training_programme_id IS NOT NULL
       AND NOT EXISTS (
           SELECT 1
           FROM public.training_programmes AS programme
           WHERE programme.id = v_training_programme_id
       ) THEN
        RAISE EXCEPTION 'The selected training programme is unavailable.';
    END IF;

    IF v_programme_section_id IS NOT NULL
       AND NOT EXISTS (
           SELECT 1
           FROM public.programme_sections AS section
           WHERE section.id = v_programme_section_id
             AND (
                 v_training_programme_id IS NULL
                 OR section.training_programme_id = v_training_programme_id
             )
       ) THEN
        RAISE EXCEPTION 'The selected programme section is unavailable.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.subjects AS subject_record
        WHERE UPPER(subject_record.code) = v_code
          AND (v_subject_id IS NULL OR subject_record.id <> v_subject_id)
    ) THEN
        RAISE EXCEPTION 'That subject code is already in use.';
    END IF;

    IF v_subject_id IS NULL THEN
        IF v_is_active THEN
            RAISE EXCEPTION
                'Create a new subject as inactive, add its reviewed questions, then activate it.';
        END IF;

        INSERT INTO public.subjects (
            code,
            title,
            qualification_level_id,
            description,
            category,
            syllabus_version,
            display_order,
            demo_question_limit,
            price,
            currency_code,
            is_demo_available,
            is_active,
            training_programme_id,
            programme_section_id
        )
        VALUES (
            v_code,
            v_title,
            v_qualification_level_id,
            v_description,
            v_category,
            v_syllabus_version,
            v_display_order,
            v_demo_question_limit,
            v_price,
            v_currency_code,
            v_is_demo_available,
            false,
            v_training_programme_id,
            v_programme_section_id
        )
        RETURNING id INTO v_subject_id;

        v_action := 'create';
    ELSE
        IF NOT EXISTS (
            SELECT 1
            FROM public.subjects AS subject_record
            WHERE subject_record.id = v_subject_id
        ) THEN
            RAISE EXCEPTION 'The selected subject was not found.';
        END IF;

        IF v_is_active
           AND NOT EXISTS (
               SELECT 1
               FROM public.questions AS question_record
               WHERE question_record.subject_id = v_subject_id
                 AND question_record.is_active = true
           ) THEN
            RAISE EXCEPTION
                'Add at least one active reviewed question before activating the subject.';
        END IF;

        UPDATE public.subjects AS subject_record
        SET code = v_code,
            title = v_title,
            qualification_level_id = v_qualification_level_id,
            description = v_description,
            category = v_category,
            syllabus_version = v_syllabus_version,
            display_order = v_display_order,
            demo_question_limit = v_demo_question_limit,
            price = v_price,
            currency_code = v_currency_code,
            is_demo_available = v_is_demo_available,
            is_active = v_is_active,
            training_programme_id = v_training_programme_id,
            programme_section_id = v_programme_section_id,
            updated_at = clock_timestamp()
        WHERE subject_record.id = v_subject_id;

        v_action := 'update';
    END IF;

    INSERT INTO public.admin_audit_events (
        actor_user_id,
        action,
        entity_type,
        entity_key,
        change_summary
    )
    VALUES (
        v_actor,
        v_action,
        'subject',
        v_subject_id::text,
        jsonb_build_object(
            'code', v_code,
            'is_active', v_is_active,
            'is_demo_available', v_is_demo_available,
            'price', v_price,
            'currency_code', v_currency_code
        )
    );

    RETURN v_subject_id::bigint;
END;
$function$;

CREATE FUNCTION public.admin_list_questions(
    p_subject_id bigint DEFAULT null
)
RETURNS TABLE (
    question_id bigint,
    subject_id bigint,
    subject_code text,
    question_text text,
    option_a text,
    option_b text,
    option_c text,
    option_d text,
    correct_option text,
    explanation text,
    difficulty_level text,
    question_type text,
    marks numeric,
    negative_marks numeric,
    display_order integer,
    is_active boolean,
    updated_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;

    IF p_subject_id IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        question_record.id::bigint,
        question_record.subject_id::bigint,
        subject_record.code,
        question_record.question_text,
        question_record.option_a,
        question_record.option_b,
        question_record.option_c,
        question_record.option_d,
        question_record.correct_option,
        question_record.explanation,
        question_record.difficulty_level,
        question_record.question_type,
        question_record.marks,
        question_record.negative_marks,
        question_record.display_order,
        question_record.is_active,
        question_record.updated_at
    FROM public.questions AS question_record
    JOIN public.subjects AS subject_record
      ON subject_record.id = question_record.subject_id
    WHERE question_record.subject_id = p_subject_id::integer
    ORDER BY question_record.display_order, question_record.id;
END;
$function$;

CREATE FUNCTION public.admin_save_question(p_question jsonb)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_actor uuid := auth.uid();
    v_question_id integer :=
        NULLIF(p_question ->> 'id', '')::integer;
    v_subject_id integer :=
        NULLIF(p_question ->> 'subject_id', '')::integer;
    v_question_text text :=
        BTRIM(COALESCE(p_question ->> 'question_text', ''));
    v_option_a text := BTRIM(COALESCE(p_question ->> 'option_a', ''));
    v_option_b text := BTRIM(COALESCE(p_question ->> 'option_b', ''));
    v_option_c text := BTRIM(COALESCE(p_question ->> 'option_c', ''));
    v_option_d text := BTRIM(COALESCE(p_question ->> 'option_d', ''));
    v_correct_option text :=
        UPPER(BTRIM(COALESCE(p_question ->> 'correct_option', '')));
    v_explanation text :=
        BTRIM(COALESCE(p_question ->> 'explanation', ''));
    v_requested_difficulty text :=
        LOWER(BTRIM(COALESCE(p_question ->> 'difficulty_level', '')));
    v_difficulty_level text;
    v_marks numeric :=
        COALESCE(NULLIF(p_question ->> 'marks', '')::numeric, 1);
    v_negative_marks numeric :=
        COALESCE(NULLIF(p_question ->> 'negative_marks', '')::numeric, 0);
    v_display_order integer :=
        COALESCE(NULLIF(p_question ->> 'display_order', '')::integer, 1);
    v_is_active boolean :=
        COALESCE((p_question ->> 'is_active')::boolean, true);
    v_action text;
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;

    v_difficulty_level := CASE v_requested_difficulty
        WHEN 'easy' THEN 'foundation'
        WHEN 'moderate' THEN 'intermediate'
        WHEN 'hard' THEN 'advanced'
        WHEN 'foundation' THEN 'foundation'
        WHEN 'intermediate' THEN 'intermediate'
        WHEN 'advanced' THEN 'advanced'
        ELSE NULL
    END;

    IF v_subject_id IS NULL
       OR NOT EXISTS (
           SELECT 1
           FROM public.subjects AS subject_record
           WHERE subject_record.id = v_subject_id
       ) THEN
        RAISE EXCEPTION 'Select an available subject.';
    END IF;
    IF CHAR_LENGTH(v_question_text) NOT BETWEEN 10 AND 5000 THEN
        RAISE EXCEPTION
            'Question text must contain between 10 and 5000 characters.';
    END IF;
    IF LEAST(
        CHAR_LENGTH(v_option_a),
        CHAR_LENGTH(v_option_b),
        CHAR_LENGTH(v_option_c),
        CHAR_LENGTH(v_option_d)
    ) < 1 THEN
        RAISE EXCEPTION 'All four answer options are required.';
    END IF;
    IF v_option_a = v_option_b
       OR v_option_a = v_option_c
       OR v_option_a = v_option_d
       OR v_option_b = v_option_c
       OR v_option_b = v_option_d
       OR v_option_c = v_option_d THEN
        RAISE EXCEPTION 'Answer options must be different from one another.';
    END IF;
    IF v_correct_option NOT IN ('A', 'B', 'C', 'D') THEN
        RAISE EXCEPTION 'Select the correct answer from A, B, C, or D.';
    END IF;
    IF CHAR_LENGTH(v_explanation) NOT BETWEEN 5 AND 10000 THEN
        RAISE EXCEPTION
            'Add an explanation containing at least 5 characters.';
    END IF;
    IF v_difficulty_level IS NULL THEN
        RAISE EXCEPTION 'Select Easy, Moderate, or Hard difficulty.';
    END IF;
    IF v_marks <= 0 OR v_negative_marks < 0 THEN
        RAISE EXCEPTION
            'Marks must be positive and negative marks cannot be below zero.';
    END IF;
    IF v_display_order < 1 THEN
        RAISE EXCEPTION 'Display order must be at least 1.';
    END IF;

    IF v_question_id IS NULL THEN
        INSERT INTO public.questions (
            subject_id,
            question_text,
            correct_option,
            explanation,
            option_a,
            option_b,
            option_c,
            option_d,
            difficulty_level,
            question_type,
            marks,
            negative_marks,
            display_order,
            is_active
        )
        VALUES (
            v_subject_id,
            v_question_text,
            v_correct_option,
            v_explanation,
            v_option_a,
            v_option_b,
            v_option_c,
            v_option_d,
            v_difficulty_level,
            'MCQ',
            v_marks,
            v_negative_marks,
            v_display_order,
            v_is_active
        )
        RETURNING id INTO v_question_id;

        v_action := 'create';
    ELSE
        UPDATE public.questions AS question_record
        SET subject_id = v_subject_id,
            question_text = v_question_text,
            correct_option = v_correct_option,
            explanation = v_explanation,
            option_a = v_option_a,
            option_b = v_option_b,
            option_c = v_option_c,
            option_d = v_option_d,
            difficulty_level = v_difficulty_level,
            question_type = 'MCQ',
            marks = v_marks,
            negative_marks = v_negative_marks,
            display_order = v_display_order,
            is_active = v_is_active,
            updated_at = clock_timestamp()
        WHERE question_record.id = v_question_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'The selected question was not found.';
        END IF;

        v_action := 'update';
    END IF;

    INSERT INTO public.admin_audit_events (
        actor_user_id,
        action,
        entity_type,
        entity_key,
        change_summary
    )
    VALUES (
        v_actor,
        v_action,
        'question',
        v_question_id::text,
        jsonb_build_object(
            'subject_id', v_subject_id,
            'difficulty_level', v_difficulty_level,
            'is_active', v_is_active
        )
    );

    RETURN v_question_id::bigint;
END;
$function$;

CREATE FUNCTION public.admin_list_users()
RETURNS TABLE (
    user_id uuid,
    email text,
    first_name text,
    last_name text,
    mobile text,
    status text,
    role text,
    email_verified_at timestamptz,
    created_at timestamptz,
    last_sign_in_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;

    RETURN QUERY
    SELECT
        profile_record.id,
        auth_user.email::text,
        profile_record.first_name,
        profile_record.last_name,
        profile_record.mobile,
        profile_record.status,
        profile_record.role,
        COALESCE(
            profile_record.email_verified_at,
            auth_user.email_confirmed_at
        ),
        auth_user.created_at,
        auth_user.last_sign_in_at
    FROM public.profiles AS profile_record
    JOIN auth.users AS auth_user
      ON auth_user.id = profile_record.id
    ORDER BY auth_user.created_at DESC;
END;
$function$;

CREATE FUNCTION public.admin_set_user_status(
    p_user_id uuid,
    p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_actor uuid := auth.uid();
    v_status text := LOWER(BTRIM(COALESCE(p_status, '')));
    v_previous_status text;
    v_role text;
    v_email_confirmed_at timestamptz;
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;

    IF v_status NOT IN ('active', 'verification_pending') THEN
        RAISE EXCEPTION
            'This screen supports activation and verification-pending status only.';
    END IF;

    SELECT
        profile_record.status,
        profile_record.role,
        auth_user.email_confirmed_at
    INTO
        v_previous_status,
        v_role,
        v_email_confirmed_at
    FROM public.profiles AS profile_record
    JOIN auth.users AS auth_user
      ON auth_user.id = profile_record.id
    WHERE profile_record.id = p_user_id
    FOR UPDATE OF profile_record;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'The selected user was not found.';
    END IF;

    IF v_role = 'admin' AND v_status <> 'active' THEN
        RAISE EXCEPTION
            'Administrator accounts cannot be made verification-pending here.';
    END IF;

    IF v_status = 'active' AND v_email_confirmed_at IS NULL THEN
        RAISE EXCEPTION
            'The user must verify their email before activation.';
    END IF;

    UPDATE public.profiles AS profile_record
    SET status = v_status,
        email_verified_at = CASE
            WHEN v_status = 'active' THEN v_email_confirmed_at
            ELSE profile_record.email_verified_at
        END
    WHERE profile_record.id = p_user_id;

    IF v_previous_status IS DISTINCT FROM v_status THEN
        INSERT INTO public.admin_audit_events (
            actor_user_id,
            action,
            entity_type,
            entity_key,
            change_summary
        )
        VALUES (
            v_actor,
            'status_change',
            'user',
            p_user_id::text,
            jsonb_build_object(
                'previous_status', v_previous_status,
                'new_status', v_status
            )
        );
    END IF;
END;
$function$;

CREATE FUNCTION public.admin_list_exam_information()
RETURNS TABLE (
    information_id bigint,
    source_document_id text,
    exam_authority_id bigint,
    authority_code text,
    authority_name text,
    subject_id bigint,
    subject_code text,
    training_programme_id bigint,
    training_programme text,
    programme_section_id bigint,
    programme_section text,
    session_code text,
    document_type text,
    title text,
    geographic_scope text,
    official_url text,
    discovery_url text,
    published_on date,
    effective_from date,
    valid_until date,
    content_usage text,
    verification_status text,
    verified_on date,
    is_active boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;

    RETURN QUERY
    SELECT
        publication.id,
        publication.source_document_id,
        authority.id::bigint,
        authority.code,
        authority.name,
        subject_record.id::bigint,
        subject_record.code,
        programme.id::bigint,
        programme.name,
        section.id::bigint,
        section.name,
        publication.session_code,
        publication.document_type,
        publication.title,
        publication.geographic_scope,
        publication.official_url,
        publication.discovery_url,
        publication.published_on,
        publication.effective_from,
        publication.valid_until,
        publication.content_usage,
        publication.verification_status,
        publication.verified_on,
        publication.is_active
    FROM public.regulatory_academic_publications AS publication
    JOIN public.exam_authorities AS authority
      ON authority.id = publication.exam_authority_id
    LEFT JOIN public.subjects AS subject_record
      ON subject_record.id = publication.subject_id
    LEFT JOIN public.training_programmes AS programme
      ON programme.id = publication.training_programme_id
    LEFT JOIN public.programme_sections AS section
      ON section.id = publication.programme_section_id
    ORDER BY
        publication.is_active DESC,
        publication.valid_until DESC NULLS LAST,
        publication.id DESC;
END;
$function$;

CREATE FUNCTION public.admin_save_exam_information(p_information jsonb)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_actor uuid := auth.uid();
    v_information_id bigint :=
        NULLIF(p_information ->> 'id', '')::bigint;
    v_source_document_id text :=
        BTRIM(COALESCE(p_information ->> 'source_document_id', ''));
    v_exam_authority_id integer :=
        NULLIF(p_information ->> 'exam_authority_id', '')::integer;
    v_subject_id integer :=
        NULLIF(p_information ->> 'subject_id', '')::integer;
    v_training_programme_id integer :=
        NULLIF(p_information ->> 'training_programme_id', '')::integer;
    v_programme_section_id integer :=
        NULLIF(p_information ->> 'programme_section_id', '')::integer;
    v_session_code text :=
        NULLIF(BTRIM(p_information ->> 'session_code'), '');
    v_document_type text :=
        LOWER(BTRIM(COALESCE(p_information ->> 'document_type', '')));
    v_title text := BTRIM(COALESCE(p_information ->> 'title', ''));
    v_geographic_scope text :=
        LOWER(BTRIM(COALESCE(
            p_information ->> 'geographic_scope',
            'all'
        )));
    v_official_url text :=
        NULLIF(BTRIM(p_information ->> 'official_url'), '');
    v_discovery_url text :=
        NULLIF(BTRIM(p_information ->> 'discovery_url'), '');
    v_published_on date :=
        NULLIF(p_information ->> 'published_on', '')::date;
    v_effective_from date :=
        NULLIF(p_information ->> 'effective_from', '')::date;
    v_valid_until date :=
        NULLIF(p_information ->> 'valid_until', '')::date;
    v_content_usage text :=
        LOWER(BTRIM(COALESCE(
            p_information ->> 'content_usage',
            'metadata_only'
        )));
    v_verification_status text :=
        LOWER(BTRIM(COALESCE(
            p_information ->> 'verification_status',
            'official_url_verified'
        )));
    v_verified_on date :=
        COALESCE(
            NULLIF(p_information ->> 'verified_on', '')::date,
            CURRENT_DATE
        );
    v_is_active boolean :=
        COALESCE((p_information ->> 'is_active')::boolean, true);
    v_action text;
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;

    IF CHAR_LENGTH(v_source_document_id) NOT BETWEEN 3 AND 180 THEN
        RAISE EXCEPTION 'Enter a stable source document identifier.';
    END IF;
    IF v_exam_authority_id IS NULL
       OR NOT EXISTS (
           SELECT 1
           FROM public.exam_authorities AS authority
           WHERE authority.id = v_exam_authority_id
       ) THEN
        RAISE EXCEPTION 'Select an available examination authority.';
    END IF;
    IF CHAR_LENGTH(v_title) NOT BETWEEN 5 AND 240 THEN
        RAISE EXCEPTION
            'Enter an information title between 5 and 240 characters.';
    END IF;
    IF v_document_type NOT IN (
        'handbook',
        'syllabus',
        'credit_points',
        'subject_amendment',
        'withdrawal_notice',
        'schedule',
        'centre_list',
        'language_list'
    ) THEN
        RAISE EXCEPTION 'Select an available document type.';
    END IF;
    IF v_geographic_scope NOT IN ('all', 'india', 'overseas') THEN
        RAISE EXCEPTION 'Select a valid geographic scope.';
    END IF;
    IF v_content_usage NOT IN ('metadata_only', 'reference_only') THEN
        RAISE EXCEPTION 'Select a valid content-usage classification.';
    END IF;
    IF v_verification_status NOT IN (
        'official_url_verified',
        'visual_source_verified',
        'document_date_verified'
    ) THEN
        RAISE EXCEPTION 'Select a valid verification status.';
    END IF;
    IF v_official_url IS NULL OR v_official_url !~* '^https://' THEN
        RAISE EXCEPTION 'Enter the official HTTPS source URL.';
    END IF;
    IF v_discovery_url IS NOT NULL
       AND v_discovery_url !~* '^https://' THEN
        RAISE EXCEPTION 'The discovery URL must use HTTPS.';
    END IF;
    IF v_valid_until IS NOT NULL
       AND v_published_on IS NOT NULL
       AND v_valid_until < v_published_on THEN
        RAISE EXCEPTION
            'Valid-until date cannot be earlier than the publication date.';
    END IF;
    IF v_document_type IN ('schedule', 'centre_list', 'language_list')
       AND (v_session_code IS NULL OR v_valid_until IS NULL) THEN
        RAISE EXCEPTION
            'Session code and valid-until date are required for session information.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.regulatory_academic_publications AS publication
        WHERE publication.source_document_id = v_source_document_id
          AND (
              v_information_id IS NULL
              OR publication.id <> v_information_id
          )
    ) THEN
        RAISE EXCEPTION 'That source document identifier is already in use.';
    END IF;

    IF v_information_id IS NULL THEN
        INSERT INTO public.regulatory_academic_publications (
            source_document_id,
            exam_authority_id,
            subject_id,
            training_programme_id,
            programme_section_id,
            session_code,
            document_type,
            title,
            geographic_scope,
            official_url,
            discovery_url,
            published_on,
            effective_from,
            valid_until,
            content_usage,
            verification_status,
            verified_on,
            is_active
        )
        VALUES (
            v_source_document_id,
            v_exam_authority_id,
            v_subject_id,
            v_training_programme_id,
            v_programme_section_id,
            v_session_code,
            v_document_type,
            v_title,
            v_geographic_scope,
            v_official_url,
            v_discovery_url,
            v_published_on,
            v_effective_from,
            v_valid_until,
            v_content_usage,
            v_verification_status,
            v_verified_on,
            v_is_active
        )
        RETURNING id INTO v_information_id;

        v_action := 'create';
    ELSE
        UPDATE public.regulatory_academic_publications AS publication
        SET source_document_id = v_source_document_id,
            exam_authority_id = v_exam_authority_id,
            subject_id = v_subject_id,
            training_programme_id = v_training_programme_id,
            programme_section_id = v_programme_section_id,
            session_code = v_session_code,
            document_type = v_document_type,
            title = v_title,
            geographic_scope = v_geographic_scope,
            official_url = v_official_url,
            discovery_url = v_discovery_url,
            published_on = v_published_on,
            effective_from = v_effective_from,
            valid_until = v_valid_until,
            content_usage = v_content_usage,
            verification_status = v_verification_status,
            verified_on = v_verified_on,
            is_active = v_is_active,
            updated_at = clock_timestamp()
        WHERE publication.id = v_information_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'The selected examination information was not found.';
        END IF;

        v_action := 'update';
    END IF;

    INSERT INTO public.admin_audit_events (
        actor_user_id,
        action,
        entity_type,
        entity_key,
        change_summary
    )
    VALUES (
        v_actor,
        v_action,
        'exam_information',
        v_information_id::text,
        jsonb_build_object(
            'source_document_id', v_source_document_id,
            'document_type', v_document_type,
            'session_code', v_session_code,
            'is_active', v_is_active
        )
    );

    RETURN v_information_id;
END;
$function$;

CREATE FUNCTION public.admin_retire_exam_information(
    p_information_id bigint
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_actor uuid := auth.uid();
    v_source_document_id text;
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;

    UPDATE public.regulatory_academic_publications AS publication
    SET is_active = false,
        updated_at = clock_timestamp()
    WHERE publication.id = p_information_id
      AND publication.is_active = true
    RETURNING publication.source_document_id
    INTO v_source_document_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'The selected information was not found or is already retired.';
    END IF;

    INSERT INTO public.admin_audit_events (
        actor_user_id,
        action,
        entity_type,
        entity_key,
        change_summary
    )
    VALUES (
        v_actor,
        'retire',
        'exam_information',
        p_information_id::text,
        jsonb_build_object(
            'source_document_id', v_source_document_id,
            'is_active', false
        )
    );
END;
$function$;

CREATE FUNCTION public.admin_list_audit_events(
    p_limit integer DEFAULT 100
)
RETURNS TABLE (
    event_id bigint,
    actor_email text,
    action text,
    entity_type text,
    entity_key text,
    change_summary jsonb,
    created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;

    RETURN QUERY
    SELECT
        audit_event.id,
        auth_user.email::text,
        audit_event.action,
        audit_event.entity_type,
        audit_event.entity_key,
        audit_event.change_summary,
        audit_event.created_at
    FROM public.admin_audit_events AS audit_event
    JOIN auth.users AS auth_user
      ON auth_user.id = audit_event.actor_user_id
    ORDER BY audit_event.created_at DESC
    LIMIT LEAST(GREATEST(COALESCE(p_limit, 100), 1), 200);
END;
$function$;

COMMENT ON TABLE public.admin_audit_events IS
    'Administrator action history containing identifiers and non-sensitive change summaries only.';
COMMENT ON FUNCTION public.fn_is_admin() IS
    'Returns true only for the current authenticated active administrator.';
COMMENT ON FUNCTION public.admin_set_user_status(uuid,text) IS
    'Allows an administrator to manage email-verification activation status without changing Auth credentials or roles.';
COMMENT ON FUNCTION public.admin_save_question(jsonb) IS
    'Creates or updates current MCQ question-bank records and maps Easy, Moderate, and Hard to the stored difficulty levels.';

REVOKE ALL ON FUNCTION public.fn_is_admin()
FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.get_admin_portal_summary()
FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.admin_list_subjects()
FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.admin_save_subject(jsonb)
FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.admin_list_questions(bigint)
FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.admin_save_question(jsonb)
FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.admin_list_users()
FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.admin_set_user_status(uuid,text)
FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.admin_list_exam_information()
FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.admin_save_exam_information(jsonb)
FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.admin_retire_exam_information(bigint)
FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.admin_list_audit_events(integer)
FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.fn_is_admin()
TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_portal_summary()
TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_subjects()
TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_save_subject(jsonb)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_questions(bigint)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_save_question(jsonb)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_users()
TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_user_status(uuid,text)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_exam_information()
TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_save_exam_information(jsonb)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_retire_exam_information(bigint)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_audit_events(integer)
TO authenticated;

NOTIFY pgrst, 'reload schema';
