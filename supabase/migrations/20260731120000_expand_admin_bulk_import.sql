-- Expand the existing administrator CSV import across the approved academic,
-- learning, examination-information, and entitlement records.
--
-- No table is created. Existing academic and learning tables, the existing
-- examination-information save RPC, and the existing per-record audit table
-- are reused.
--
-- Safe operational rollback:
--   supabase/rollbacks/20260731120000_expand_admin_bulk_import.sql

BEGIN;

DO $guard$
DECLARE
    v_relation text;
    v_signature text;
BEGIN
    FOREACH v_relation IN ARRAY ARRAY[
        'public.qualification_levels',
        'public.exam_authorities',
        'public.training_programmes',
        'public.programme_sections',
        'public.subjects',
        'public.subject_modules',
        'public.subject_chapters',
        'public.subject_topics',
        'public.learning_resource_types',
        'public.learning_resources',
        'public.flashcards',
        'public.user_entitlements',
        'public.regulatory_academic_publications',
        'public.admin_audit_events'
    ]
    LOOP
        IF pg_catalog.to_regclass(v_relation) IS NULL THEN
            RAISE EXCEPTION
                'Required existing relation % is missing.', v_relation;
        END IF;
    END LOOP;

    FOREACH v_signature IN ARRAY ARRAY[
        'public.fn_is_admin()',
        'public.admin_bulk_import(text,jsonb)',
        'public.admin_save_exam_information(jsonb)'
    ]
    LOOP
        IF pg_catalog.to_regprocedure(v_signature) IS NULL THEN
            RAISE EXCEPTION
                'Required existing function % is missing.', v_signature;
        END IF;
    END LOOP;

    IF pg_catalog.to_regprocedure(
        'public.admin_save_academic_content(text,jsonb)'
    ) IS NOT NULL
       OR pg_catalog.to_regprocedure(
           'public.admin_save_entitlement(jsonb)'
       ) IS NOT NULL THEN
        RAISE EXCEPTION
            'Expanded administrator save functions already exist; review before deploying duplicates.';
    END IF;
END;
$guard$;

-- Official notices use the existing governed publication table. The added
-- value does not introduce a new information table or change prior values.
ALTER TABLE public.regulatory_academic_publications
DROP CONSTRAINT regulatory_academic_publications_document_type_check;

ALTER TABLE public.regulatory_academic_publications
ADD CONSTRAINT regulatory_academic_publications_document_type_check
CHECK (
    document_type = ANY (
        ARRAY[
            'handbook'::text,
            'syllabus'::text,
            'credit_points'::text,
            'subject_amendment'::text,
            'withdrawal_notice'::text,
            'official_notice'::text,
            'schedule'::text,
            'centre_list'::text,
            'language_list'::text
        ]
    )
);

CREATE OR REPLACE FUNCTION public.admin_save_exam_information(
    p_information jsonb
)
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
        pg_catalog.btrim(COALESCE(
            p_information ->> 'source_document_id',
            ''
        ));
    v_exam_authority_id integer :=
        NULLIF(p_information ->> 'exam_authority_id', '')::integer;
    v_subject_id integer :=
        NULLIF(p_information ->> 'subject_id', '')::integer;
    v_training_programme_id integer :=
        NULLIF(p_information ->> 'training_programme_id', '')::integer;
    v_programme_section_id integer :=
        NULLIF(p_information ->> 'programme_section_id', '')::integer;
    v_session_code text :=
        NULLIF(pg_catalog.btrim(p_information ->> 'session_code'), '');
    v_document_type text := pg_catalog.lower(
        pg_catalog.btrim(COALESCE(
            p_information ->> 'document_type',
            ''
        ))
    );
    v_title text :=
        pg_catalog.btrim(COALESCE(p_information ->> 'title', ''));
    v_geographic_scope text := pg_catalog.lower(
        pg_catalog.btrim(COALESCE(
            p_information ->> 'geographic_scope',
            'all'
        ))
    );
    v_official_url text :=
        NULLIF(pg_catalog.btrim(p_information ->> 'official_url'), '');
    v_discovery_url text :=
        NULLIF(pg_catalog.btrim(p_information ->> 'discovery_url'), '');
    v_published_on date :=
        NULLIF(p_information ->> 'published_on', '')::date;
    v_effective_from date :=
        NULLIF(p_information ->> 'effective_from', '')::date;
    v_valid_until date :=
        NULLIF(p_information ->> 'valid_until', '')::date;
    v_content_usage text := pg_catalog.lower(
        pg_catalog.btrim(COALESCE(
            p_information ->> 'content_usage',
            'metadata_only'
        ))
    );
    v_verification_status text := pg_catalog.lower(
        pg_catalog.btrim(COALESCE(
            p_information ->> 'verification_status',
            'official_url_verified'
        ))
    );
    v_verified_on date := COALESCE(
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

    IF pg_catalog.char_length(v_source_document_id)
        NOT BETWEEN 3 AND 180 THEN
        RAISE EXCEPTION
            'Enter a stable source document identifier.';
    END IF;
    IF v_exam_authority_id IS NULL
       OR NOT EXISTS (
           SELECT 1
           FROM public.exam_authorities AS authority
           WHERE authority.id = v_exam_authority_id
       ) THEN
        RAISE EXCEPTION
            'Select an available examination authority.';
    END IF;
    IF pg_catalog.char_length(v_title) NOT BETWEEN 5 AND 240 THEN
        RAISE EXCEPTION
            'Enter an information title between 5 and 240 characters.';
    END IF;
    IF v_document_type NOT IN (
        'handbook',
        'syllabus',
        'credit_points',
        'subject_amendment',
        'withdrawal_notice',
        'official_notice',
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
        RAISE EXCEPTION
            'Select a valid content-usage classification.';
    END IF;
    IF v_verification_status NOT IN (
        'official_url_verified',
        'visual_source_verified',
        'document_date_verified'
    ) THEN
        RAISE EXCEPTION
            'Select a valid verification status.';
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
    IF v_document_type IN (
        'schedule',
        'centre_list',
        'language_list'
    )
       AND (v_session_code IS NULL OR v_valid_until IS NULL) THEN
        RAISE EXCEPTION
            'Session code and valid-until date are required for session information.';
    END IF;

    IF v_subject_id IS NOT NULL
       AND NOT EXISTS (
           SELECT 1
           FROM public.subjects AS subject_record
           WHERE subject_record.id = v_subject_id
       ) THEN
        RAISE EXCEPTION 'The selected subject was not found.';
    END IF;
    IF v_training_programme_id IS NOT NULL
       AND NOT EXISTS (
           SELECT 1
           FROM public.training_programmes AS programme
           WHERE programme.id = v_training_programme_id
             AND programme.exam_authority_id = v_exam_authority_id
       ) THEN
        RAISE EXCEPTION
            'The selected programme does not belong to the examination authority.';
    END IF;
    IF v_programme_section_id IS NOT NULL
       AND (
           v_training_programme_id IS NULL
           OR NOT EXISTS (
               SELECT 1
               FROM public.programme_sections AS section
               WHERE section.id = v_programme_section_id
                 AND section.training_programme_id =
                    v_training_programme_id
           )
       ) THEN
        RAISE EXCEPTION
            'The selected section does not belong to the programme.';
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
        RAISE EXCEPTION
            'That source document identifier is already in use.';
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
            updated_at = pg_catalog.clock_timestamp()
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
        pg_catalog.jsonb_build_object(
            'source_document_id', v_source_document_id,
            'document_type', v_document_type,
            'session_code', v_session_code,
            'is_active', v_is_active
        )
    );

    RETURN v_information_id;
END;
$function$;

CREATE FUNCTION public.admin_save_academic_content(
    p_entity text,
    p_record jsonb
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_actor uuid := auth.uid();
    v_entity text := pg_catalog.lower(
        pg_catalog.btrim(COALESCE(p_entity, ''))
    );
    v_record_id integer;
    v_record_key text;
    v_action text;
    v_is_active boolean :=
        COALESCE((p_record ->> 'is_active')::boolean, false);
    v_display_order integer :=
        COALESCE(NULLIF(p_record ->> 'display_order', '')::integer, 1);
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;

    IF pg_catalog.jsonb_typeof(p_record) <> 'object' THEN
        RAISE EXCEPTION 'The academic record must be a JSON object.';
    END IF;

    IF v_display_order < 1 THEN
        RAISE EXCEPTION 'display_order must be at least 1.';
    END IF;

    CASE v_entity
        WHEN 'qualification_levels' THEN
            DECLARE
                v_code text := pg_catalog.lower(
                    pg_catalog.btrim(COALESCE(p_record ->> 'code', ''))
                );
                v_name text :=
                    pg_catalog.btrim(COALESCE(p_record ->> 'name', ''));
                v_description text :=
                    NULLIF(pg_catalog.btrim(p_record ->> 'description'), '');
            BEGIN
                IF v_code !~ '^[a-z0-9][a-z0-9_-]{1,79}$' THEN
                    RAISE EXCEPTION
                        'Enter a qualification code containing 2-80 letters, numbers, underscores, or hyphens.';
                END IF;
                IF pg_catalog.char_length(v_name) NOT BETWEEN 2 AND 160 THEN
                    RAISE EXCEPTION
                        'Qualification name must contain 2-160 characters.';
                END IF;

                SELECT qualification.id
                INTO v_record_id
                FROM public.qualification_levels AS qualification
                WHERE pg_catalog.lower(qualification.code) = v_code
                FOR UPDATE;

                IF v_record_id IS NULL THEN
                    INSERT INTO public.qualification_levels (
                        code,
                        name,
                        description,
                        display_order,
                        is_active
                    )
                    VALUES (
                        v_code,
                        v_name,
                        v_description,
                        v_display_order,
                        v_is_active
                    )
                    RETURNING id INTO v_record_id;
                    v_action := 'create';
                ELSE
                    UPDATE public.qualification_levels AS qualification
                    SET name = v_name,
                        description = v_description,
                        display_order = v_display_order,
                        is_active = v_is_active
                    WHERE qualification.id = v_record_id;
                    v_action := 'update';
                END IF;
                v_record_key := v_code;
            END;

        WHEN 'exam_authorities' THEN
            DECLARE
                v_code text := pg_catalog.lower(
                    pg_catalog.btrim(COALESCE(p_record ->> 'code', ''))
                );
                v_name text :=
                    pg_catalog.btrim(COALESCE(p_record ->> 'name', ''));
                v_short_name text :=
                    pg_catalog.btrim(COALESCE(
                        p_record ->> 'short_name',
                        ''
                    ));
                v_description text :=
                    NULLIF(pg_catalog.btrim(p_record ->> 'description'), '');
                v_official_website text :=
                    NULLIF(pg_catalog.btrim(
                        p_record ->> 'official_website'
                    ), '');
                v_disclaimer_text text :=
                    NULLIF(pg_catalog.btrim(
                        p_record ->> 'disclaimer_text'
                    ), '');
            BEGIN
                IF v_code !~ '^[a-z0-9][a-z0-9_-]{1,79}$' THEN
                    RAISE EXCEPTION
                        'Enter an authority code containing 2-80 letters, numbers, underscores, or hyphens.';
                END IF;
                IF pg_catalog.char_length(v_name) NOT BETWEEN 2 AND 180
                   OR pg_catalog.char_length(v_short_name)
                        NOT BETWEEN 2 AND 40 THEN
                    RAISE EXCEPTION
                        'Enter a valid authority name and short name.';
                END IF;
                IF v_official_website IS NOT NULL
                   AND v_official_website !~* '^https://' THEN
                    RAISE EXCEPTION
                        'official_website must use HTTPS.';
                END IF;

                SELECT authority.id
                INTO v_record_id
                FROM public.exam_authorities AS authority
                WHERE pg_catalog.lower(authority.code) = v_code
                FOR UPDATE;

                IF v_record_id IS NULL THEN
                    INSERT INTO public.exam_authorities (
                        code,
                        name,
                        short_name,
                        description,
                        official_website,
                        disclaimer_text,
                        display_order,
                        is_active
                    )
                    VALUES (
                        v_code,
                        v_name,
                        v_short_name,
                        v_description,
                        v_official_website,
                        v_disclaimer_text,
                        v_display_order,
                        v_is_active
                    )
                    RETURNING id INTO v_record_id;
                    v_action := 'create';
                ELSE
                    UPDATE public.exam_authorities AS authority
                    SET name = v_name,
                        short_name = v_short_name,
                        description = v_description,
                        official_website = v_official_website,
                        disclaimer_text = v_disclaimer_text,
                        display_order = v_display_order,
                        is_active = v_is_active,
                        updated_at = pg_catalog.clock_timestamp()
                    WHERE authority.id = v_record_id;
                    v_action := 'update';
                END IF;
                v_record_key := v_code;
            END;

        WHEN 'training_programmes' THEN
            DECLARE
                v_authority_code text := pg_catalog.lower(
                    pg_catalog.btrim(COALESCE(
                        p_record ->> 'authority_code',
                        ''
                    ))
                );
                v_authority_id integer;
                v_code text := pg_catalog.lower(
                    pg_catalog.btrim(COALESCE(p_record ->> 'code', ''))
                );
                v_name text :=
                    pg_catalog.btrim(COALESCE(p_record ->> 'name', ''));
                v_programme_category text := pg_catalog.lower(
                    pg_catalog.btrim(COALESCE(
                        p_record ->> 'programme_category',
                        ''
                    ))
                );
                v_description text :=
                    NULLIF(pg_catalog.btrim(p_record ->> 'description'), '');
                v_official_pass numeric :=
                    NULLIF(
                        p_record ->> 'official_pass_percentage',
                        ''
                    )::numeric;
                v_recommended_readiness numeric :=
                    NULLIF(
                        p_record ->> 'recommended_readiness_percentage',
                        ''
                    )::numeric;
                v_question_count integer :=
                    NULLIF(p_record ->> 'exam_question_count', '')::integer;
                v_duration integer :=
                    NULLIF(
                        p_record ->> 'exam_duration_minutes',
                        ''
                    )::integer;
                v_negative_marking boolean :=
                    NULLIF(p_record ->> 'negative_marking', '')::boolean;
            BEGIN
                SELECT authority.id
                INTO v_authority_id
                FROM public.exam_authorities AS authority
                WHERE pg_catalog.lower(authority.code) = v_authority_code;

                IF v_authority_id IS NULL THEN
                    RAISE EXCEPTION
                        'authority_code does not match an existing examination authority.';
                END IF;
                IF v_code !~ '^[a-z0-9][a-z0-9_-]{1,79}$'
                   OR pg_catalog.char_length(v_name) NOT BETWEEN 2 AND 180
                   OR v_programme_category = '' THEN
                    RAISE EXCEPTION
                        'Enter a valid programme code, name, and category.';
                END IF;
                IF v_official_pass NOT BETWEEN 0.01 AND 100
                   OR v_recommended_readiness NOT BETWEEN 0.01 AND 100 THEN
                    RAISE EXCEPTION
                        'Programme percentages must be greater than zero and no more than 100.';
                END IF;
                IF (v_question_count IS NOT NULL AND v_question_count < 1)
                   OR (v_duration IS NOT NULL AND v_duration < 1) THEN
                    RAISE EXCEPTION
                        'Optional exam counts and durations must be positive.';
                END IF;

                SELECT programme.id
                INTO v_record_id
                FROM public.training_programmes AS programme
                WHERE pg_catalog.lower(programme.code) = v_code
                FOR UPDATE;

                IF v_record_id IS NULL THEN
                    INSERT INTO public.training_programmes (
                        exam_authority_id,
                        code,
                        name,
                        programme_category,
                        description,
                        official_pass_percentage,
                        recommended_readiness_percentage,
                        exam_question_count,
                        exam_duration_minutes,
                        negative_marking,
                        display_order,
                        is_active
                    )
                    VALUES (
                        v_authority_id,
                        v_code,
                        v_name,
                        v_programme_category,
                        v_description,
                        v_official_pass,
                        v_recommended_readiness,
                        v_question_count,
                        v_duration,
                        v_negative_marking,
                        v_display_order,
                        v_is_active
                    )
                    RETURNING id INTO v_record_id;
                    v_action := 'create';
                ELSE
                    UPDATE public.training_programmes AS programme
                    SET exam_authority_id = v_authority_id,
                        name = v_name,
                        programme_category = v_programme_category,
                        description = v_description,
                        official_pass_percentage = v_official_pass,
                        recommended_readiness_percentage =
                            v_recommended_readiness,
                        exam_question_count = v_question_count,
                        exam_duration_minutes = v_duration,
                        negative_marking = v_negative_marking,
                        display_order = v_display_order,
                        is_active = v_is_active,
                        updated_at = pg_catalog.clock_timestamp()
                    WHERE programme.id = v_record_id;
                    v_action := 'update';
                END IF;
                v_record_key := v_code;
            END;

        WHEN 'programme_sections' THEN
            DECLARE
                v_programme_code text := pg_catalog.lower(
                    pg_catalog.btrim(COALESCE(
                        p_record ->> 'programme_code',
                        ''
                    ))
                );
                v_programme_id integer;
                v_code text := pg_catalog.lower(
                    pg_catalog.btrim(COALESCE(p_record ->> 'code', ''))
                );
                v_name text :=
                    pg_catalog.btrim(COALESCE(p_record ->> 'name', ''));
                v_description text :=
                    NULLIF(pg_catalog.btrim(p_record ->> 'description'), '');
                v_exam_count integer :=
                    NULLIF(p_record ->> 'exam_question_count', '')::integer;
                v_practice_count integer := NULLIF(
                    p_record ->> 'recommended_practice_question_count',
                    ''
                )::integer;
            BEGIN
                SELECT programme.id
                INTO v_programme_id
                FROM public.training_programmes AS programme
                WHERE pg_catalog.lower(programme.code) =
                    v_programme_code;

                IF v_programme_id IS NULL THEN
                    RAISE EXCEPTION
                        'programme_code does not match an existing programme.';
                END IF;
                IF v_code !~ '^[a-z0-9][a-z0-9_-]{1,79}$'
                   OR pg_catalog.char_length(v_name) NOT BETWEEN 2 AND 180 THEN
                    RAISE EXCEPTION
                        'Enter a valid programme-section code and name.';
                END IF;
                IF (v_exam_count IS NOT NULL AND v_exam_count < 1)
                   OR (v_practice_count IS NOT NULL
                       AND v_practice_count < 1) THEN
                    RAISE EXCEPTION
                        'Optional question counts must be positive.';
                END IF;

                SELECT section.id
                INTO v_record_id
                FROM public.programme_sections AS section
                WHERE section.training_programme_id = v_programme_id
                  AND pg_catalog.lower(section.code) = v_code
                FOR UPDATE;

                IF v_record_id IS NULL THEN
                    INSERT INTO public.programme_sections (
                        training_programme_id,
                        code,
                        name,
                        description,
                        exam_question_count,
                        recommended_practice_question_count,
                        display_order,
                        is_active
                    )
                    VALUES (
                        v_programme_id,
                        v_code,
                        v_name,
                        v_description,
                        v_exam_count,
                        v_practice_count,
                        v_display_order,
                        v_is_active
                    )
                    RETURNING id INTO v_record_id;
                    v_action := 'create';
                ELSE
                    UPDATE public.programme_sections AS section
                    SET name = v_name,
                        description = v_description,
                        exam_question_count = v_exam_count,
                        recommended_practice_question_count =
                            v_practice_count,
                        display_order = v_display_order,
                        is_active = v_is_active,
                        updated_at = pg_catalog.clock_timestamp()
                    WHERE section.id = v_record_id;
                    v_action := 'update';
                END IF;
                v_record_key := v_programme_code || ':' || v_code;
            END;

        WHEN 'modules' THEN
            DECLARE
                v_subject_code text := pg_catalog.upper(
                    pg_catalog.btrim(COALESCE(
                        p_record ->> 'subject_code',
                        ''
                    ))
                );
                v_subject_id integer;
                v_code text := pg_catalog.lower(
                    pg_catalog.btrim(COALESCE(p_record ->> 'code', ''))
                );
                v_title text :=
                    pg_catalog.btrim(COALESCE(p_record ->> 'title', ''));
                v_description text :=
                    NULLIF(pg_catalog.btrim(p_record ->> 'description'), '');
            BEGIN
                SELECT subject_record.id
                INTO v_subject_id
                FROM public.subjects AS subject_record
                WHERE pg_catalog.upper(subject_record.code) =
                    v_subject_code;

                IF v_subject_id IS NULL THEN
                    RAISE EXCEPTION
                        'subject_code does not match an existing subject.';
                END IF;
                IF v_code !~ '^[a-z0-9][a-z0-9_-]{1,79}$'
                   OR pg_catalog.char_length(v_title)
                        NOT BETWEEN 2 AND 240 THEN
                    RAISE EXCEPTION
                        'Enter a valid module code and title.';
                END IF;

                SELECT module_record.id
                INTO v_record_id
                FROM public.subject_modules AS module_record
                WHERE module_record.subject_id = v_subject_id
                  AND pg_catalog.lower(module_record.code) = v_code
                FOR UPDATE;

                IF v_record_id IS NULL THEN
                    INSERT INTO public.subject_modules (
                        subject_id,
                        code,
                        title,
                        description,
                        display_order,
                        is_active
                    )
                    VALUES (
                        v_subject_id,
                        v_code,
                        v_title,
                        v_description,
                        v_display_order,
                        v_is_active
                    )
                    RETURNING id INTO v_record_id;
                    v_action := 'create';
                ELSE
                    UPDATE public.subject_modules AS module_record
                    SET title = v_title,
                        description = v_description,
                        display_order = v_display_order,
                        is_active = v_is_active,
                        updated_at = pg_catalog.clock_timestamp()
                    WHERE module_record.id = v_record_id;
                    v_action := 'update';
                END IF;
                v_record_key := v_subject_code || ':' || v_code;
            END;

        WHEN 'chapters' THEN
            DECLARE
                v_subject_code text := pg_catalog.upper(
                    pg_catalog.btrim(COALESCE(
                        p_record ->> 'subject_code',
                        ''
                    ))
                );
                v_module_code text := pg_catalog.lower(
                    pg_catalog.btrim(COALESCE(
                        p_record ->> 'module_code',
                        ''
                    ))
                );
                v_subject_id integer;
                v_module_id integer;
                v_code text := pg_catalog.lower(
                    pg_catalog.btrim(COALESCE(p_record ->> 'code', ''))
                );
                v_chapter_number integer :=
                    NULLIF(p_record ->> 'chapter_number', '')::integer;
                v_title text :=
                    pg_catalog.btrim(COALESCE(p_record ->> 'title', ''));
                v_description text :=
                    NULLIF(pg_catalog.btrim(p_record ->> 'description'), '');
            BEGIN
                SELECT subject_record.id, module_record.id
                INTO v_subject_id, v_module_id
                FROM public.subjects AS subject_record
                JOIN public.subject_modules AS module_record
                  ON module_record.subject_id = subject_record.id
                WHERE pg_catalog.upper(subject_record.code) =
                    v_subject_code
                  AND pg_catalog.lower(module_record.code) =
                    v_module_code;

                IF v_subject_id IS NULL OR v_module_id IS NULL THEN
                    RAISE EXCEPTION
                        'subject_code and module_code do not match an existing module path.';
                END IF;
                IF v_code !~ '^[a-z0-9][a-z0-9_-]{1,79}$'
                   OR v_chapter_number IS NULL
                   OR v_chapter_number < 1
                   OR pg_catalog.char_length(v_title)
                        NOT BETWEEN 2 AND 240 THEN
                    RAISE EXCEPTION
                        'Enter a valid chapter code, number, and title.';
                END IF;

                SELECT chapter.id
                INTO v_record_id
                FROM public.subject_chapters AS chapter
                WHERE chapter.subject_id = v_subject_id
                  AND pg_catalog.lower(chapter.code) = v_code
                FOR UPDATE;

                IF EXISTS (
                    SELECT 1
                    FROM public.subject_chapters AS chapter
                    WHERE chapter.module_id = v_module_id
                      AND chapter.chapter_number = v_chapter_number
                      AND (
                          v_record_id IS NULL
                          OR chapter.id <> v_record_id
                      )
                ) THEN
                    RAISE EXCEPTION
                        'chapter_number is already used in that module.';
                END IF;

                IF v_record_id IS NULL THEN
                    INSERT INTO public.subject_chapters (
                        subject_id,
                        module_id,
                        chapter_number,
                        code,
                        title,
                        description,
                        display_order,
                        is_active
                    )
                    VALUES (
                        v_subject_id,
                        v_module_id,
                        v_chapter_number,
                        v_code,
                        v_title,
                        v_description,
                        v_display_order,
                        v_is_active
                    )
                    RETURNING id INTO v_record_id;
                    v_action := 'create';
                ELSE
                    UPDATE public.subject_chapters AS chapter
                    SET module_id = v_module_id,
                        chapter_number = v_chapter_number,
                        title = v_title,
                        description = v_description,
                        display_order = v_display_order,
                        is_active = v_is_active,
                        updated_at = pg_catalog.clock_timestamp()
                    WHERE chapter.id = v_record_id;
                    v_action := 'update';
                END IF;
                v_record_key := v_subject_code || ':' || v_code;
            END;

        WHEN 'topics' THEN
            DECLARE
                v_subject_code text := pg_catalog.upper(
                    pg_catalog.btrim(COALESCE(
                        p_record ->> 'subject_code',
                        ''
                    ))
                );
                v_module_code text := pg_catalog.lower(
                    pg_catalog.btrim(COALESCE(
                        p_record ->> 'module_code',
                        ''
                    ))
                );
                v_chapter_code text := pg_catalog.lower(
                    pg_catalog.btrim(COALESCE(
                        p_record ->> 'chapter_code',
                        ''
                    ))
                );
                v_subject_id integer;
                v_module_id integer;
                v_chapter_id integer;
                v_code text := pg_catalog.lower(
                    pg_catalog.btrim(COALESCE(p_record ->> 'code', ''))
                );
                v_topic_number integer :=
                    NULLIF(p_record ->> 'topic_number', '')::integer;
                v_title text :=
                    pg_catalog.btrim(COALESCE(p_record ->> 'title', ''));
                v_description text :=
                    NULLIF(pg_catalog.btrim(p_record ->> 'description'), '');
                v_learning_objective text := NULLIF(
                    pg_catalog.btrim(p_record ->> 'learning_objective'),
                    ''
                );
                v_practical_relevance text := NULLIF(
                    pg_catalog.btrim(p_record ->> 'practical_relevance'),
                    ''
                );
                v_estimated_minutes integer := NULLIF(
                    p_record ->> 'estimated_study_minutes',
                    ''
                )::integer;
                v_difficulty text := pg_catalog.lower(
                    pg_catalog.btrim(COALESCE(
                        p_record ->> 'difficulty_level',
                        ''
                    ))
                );
                v_is_exam_relevant boolean := COALESCE(
                    (p_record ->> 'is_exam_relevant')::boolean,
                    true
                );
            BEGIN
                SELECT
                    subject_record.id,
                    module_record.id,
                    chapter.id
                INTO
                    v_subject_id,
                    v_module_id,
                    v_chapter_id
                FROM public.subjects AS subject_record
                JOIN public.subject_modules AS module_record
                  ON module_record.subject_id = subject_record.id
                JOIN public.subject_chapters AS chapter
                  ON chapter.subject_id = subject_record.id
                 AND chapter.module_id = module_record.id
                WHERE pg_catalog.upper(subject_record.code) =
                    v_subject_code
                  AND pg_catalog.lower(module_record.code) =
                    v_module_code
                  AND pg_catalog.lower(chapter.code) =
                    v_chapter_code;

                IF v_subject_id IS NULL
                   OR v_module_id IS NULL
                   OR v_chapter_id IS NULL THEN
                    RAISE EXCEPTION
                        'The supplied subject, module, and chapter codes do not form an existing path.';
                END IF;
                IF v_code !~ '^[a-z0-9][a-z0-9_-]{1,79}$'
                   OR v_topic_number IS NULL
                   OR v_topic_number < 1
                   OR pg_catalog.char_length(v_title)
                        NOT BETWEEN 2 AND 240 THEN
                    RAISE EXCEPTION
                        'Enter a valid topic code, number, and title.';
                END IF;
                IF v_difficulty NOT IN (
                    'foundation',
                    'intermediate',
                    'advanced'
                ) THEN
                    RAISE EXCEPTION
                        'difficulty_level must be foundation, intermediate, or advanced.';
                END IF;
                IF v_estimated_minutes IS NOT NULL
                   AND v_estimated_minutes < 1 THEN
                    RAISE EXCEPTION
                        'estimated_study_minutes must be positive when supplied.';
                END IF;

                SELECT topic.id
                INTO v_record_id
                FROM public.subject_topics AS topic
                WHERE topic.subject_id = v_subject_id
                  AND pg_catalog.lower(topic.code) = v_code
                FOR UPDATE;

                IF EXISTS (
                    SELECT 1
                    FROM public.subject_topics AS topic
                    WHERE topic.chapter_id = v_chapter_id
                      AND topic.topic_number = v_topic_number
                      AND (
                          v_record_id IS NULL
                          OR topic.id <> v_record_id
                      )
                ) THEN
                    RAISE EXCEPTION
                        'topic_number is already used in that chapter.';
                END IF;

                IF v_record_id IS NULL THEN
                    INSERT INTO public.subject_topics (
                        subject_id,
                        module_id,
                        chapter_id,
                        topic_number,
                        code,
                        title,
                        description,
                        learning_objective,
                        practical_relevance,
                        estimated_study_minutes,
                        difficulty_level,
                        display_order,
                        is_exam_relevant,
                        is_active
                    )
                    VALUES (
                        v_subject_id,
                        v_module_id,
                        v_chapter_id,
                        v_topic_number,
                        v_code,
                        v_title,
                        v_description,
                        v_learning_objective,
                        v_practical_relevance,
                        v_estimated_minutes,
                        v_difficulty,
                        v_display_order,
                        v_is_exam_relevant,
                        v_is_active
                    )
                    RETURNING id INTO v_record_id;
                    v_action := 'create';
                ELSE
                    UPDATE public.subject_topics AS topic
                    SET module_id = v_module_id,
                        chapter_id = v_chapter_id,
                        topic_number = v_topic_number,
                        title = v_title,
                        description = v_description,
                        learning_objective = v_learning_objective,
                        practical_relevance = v_practical_relevance,
                        estimated_study_minutes = v_estimated_minutes,
                        difficulty_level = v_difficulty,
                        display_order = v_display_order,
                        is_exam_relevant = v_is_exam_relevant,
                        is_active = v_is_active,
                        updated_at = pg_catalog.clock_timestamp()
                    WHERE topic.id = v_record_id;
                    v_action := 'update';
                END IF;
                v_record_key := v_subject_code || ':' || v_code;
            END;

        WHEN 'learning_resource_types' THEN
            DECLARE
                v_code text := pg_catalog.upper(
                    pg_catalog.btrim(COALESCE(p_record ->> 'code', ''))
                );
                v_name text :=
                    pg_catalog.btrim(COALESCE(p_record ->> 'name', ''));
                v_description text :=
                    NULLIF(pg_catalog.btrim(p_record ->> 'description'), '');
                v_icon_name text :=
                    NULLIF(pg_catalog.btrim(p_record ->> 'icon_name'), '');
            BEGIN
                IF v_code !~ '^[A-Z0-9][A-Z0-9_-]{1,79}$'
                   OR pg_catalog.char_length(v_name) NOT BETWEEN 2 AND 160 THEN
                    RAISE EXCEPTION
                        'Enter a valid learning-resource type code and name.';
                END IF;

                SELECT resource_type.id
                INTO v_record_id
                FROM public.learning_resource_types AS resource_type
                WHERE pg_catalog.upper(resource_type.code) = v_code
                FOR UPDATE;

                IF v_record_id IS NULL THEN
                    INSERT INTO public.learning_resource_types (
                        code,
                        name,
                        description,
                        icon_name,
                        display_order,
                        is_active
                    )
                    VALUES (
                        v_code,
                        v_name,
                        v_description,
                        v_icon_name,
                        v_display_order,
                        v_is_active
                    )
                    RETURNING id INTO v_record_id;
                    v_action := 'create';
                ELSE
                    UPDATE public.learning_resource_types AS resource_type
                    SET name = v_name,
                        description = v_description,
                        icon_name = v_icon_name,
                        display_order = v_display_order,
                        is_active = v_is_active,
                        updated_at = pg_catalog.clock_timestamp()
                    WHERE resource_type.id = v_record_id;
                    v_action := 'update';
                END IF;
                v_record_key := v_code;
            END;

        WHEN 'learning_resources' THEN
            DECLARE
                v_subject_code text := pg_catalog.upper(
                    pg_catalog.btrim(COALESCE(
                        p_record ->> 'subject_code',
                        ''
                    ))
                );
                v_module_code text := pg_catalog.lower(
                    pg_catalog.btrim(COALESCE(
                        p_record ->> 'module_code',
                        ''
                    ))
                );
                v_chapter_code text := pg_catalog.lower(
                    pg_catalog.btrim(COALESCE(
                        p_record ->> 'chapter_code',
                        ''
                    ))
                );
                v_topic_code text := pg_catalog.lower(
                    pg_catalog.btrim(COALESCE(
                        p_record ->> 'topic_code',
                        ''
                    ))
                );
                v_resource_type_code text := pg_catalog.upper(
                    pg_catalog.btrim(COALESCE(
                        p_record ->> 'resource_type_code',
                        ''
                    ))
                );
                v_subject_id integer;
                v_module_id integer;
                v_chapter_id integer;
                v_topic_id integer;
                v_resource_type_id integer;
                v_code text := pg_catalog.upper(
                    pg_catalog.btrim(COALESCE(p_record ->> 'code', ''))
                );
                v_title text :=
                    pg_catalog.btrim(COALESCE(p_record ->> 'title', ''));
                v_short_description text := NULLIF(
                    pg_catalog.btrim(p_record ->> 'short_description'),
                    ''
                );
                v_content text :=
                    NULLIF(pg_catalog.btrim(p_record ->> 'content'), '');
                v_external_url text :=
                    NULLIF(pg_catalog.btrim(p_record ->> 'external_url'), '');
                v_attachment_path text := NULLIF(
                    pg_catalog.btrim(p_record ->> 'attachment_path'),
                    ''
                );
                v_author_name text :=
                    NULLIF(pg_catalog.btrim(p_record ->> 'author_name'), '');
                v_version integer :=
                    COALESCE(
                        NULLIF(p_record ->> 'version_no', '')::integer,
                        1
                    );
                v_estimated_minutes integer := NULLIF(
                    p_record ->> 'estimated_read_minutes',
                    ''
                )::integer;
                v_is_exam_relevant boolean := COALESCE(
                    (p_record ->> 'is_exam_relevant')::boolean,
                    true
                );
                v_is_premium boolean := COALESCE(
                    (p_record ->> 'is_premium')::boolean,
                    false
                );
            BEGIN
                SELECT
                    subject_record.id,
                    module_record.id,
                    chapter.id,
                    topic.id
                INTO
                    v_subject_id,
                    v_module_id,
                    v_chapter_id,
                    v_topic_id
                FROM public.subjects AS subject_record
                JOIN public.subject_modules AS module_record
                  ON module_record.subject_id = subject_record.id
                JOIN public.subject_chapters AS chapter
                  ON chapter.subject_id = subject_record.id
                 AND chapter.module_id = module_record.id
                JOIN public.subject_topics AS topic
                  ON topic.subject_id = subject_record.id
                 AND topic.module_id = module_record.id
                 AND topic.chapter_id = chapter.id
                WHERE pg_catalog.upper(subject_record.code) =
                    v_subject_code
                  AND pg_catalog.lower(module_record.code) =
                    v_module_code
                  AND pg_catalog.lower(chapter.code) =
                    v_chapter_code
                  AND pg_catalog.lower(topic.code) = v_topic_code;

                SELECT resource_type.id
                INTO v_resource_type_id
                FROM public.learning_resource_types AS resource_type
                WHERE pg_catalog.upper(resource_type.code) =
                    v_resource_type_code;

                IF v_subject_id IS NULL
                   OR v_module_id IS NULL
                   OR v_chapter_id IS NULL
                   OR v_topic_id IS NULL THEN
                    RAISE EXCEPTION
                        'The supplied subject, module, chapter, and topic codes do not form an existing path.';
                END IF;
                IF v_resource_type_id IS NULL THEN
                    RAISE EXCEPTION
                        'resource_type_code does not match an existing resource type.';
                END IF;
                IF v_code !~ '^[A-Z0-9][A-Z0-9_:-]{1,119}$'
                   OR pg_catalog.char_length(v_title)
                        NOT BETWEEN 2 AND 240 THEN
                    RAISE EXCEPTION
                        'Enter a valid learning-resource code and title.';
                END IF;
                IF v_content IS NULL
                   AND v_external_url IS NULL
                   AND v_attachment_path IS NULL THEN
                    RAISE EXCEPTION
                        'Supply content, external_url, or attachment_path.';
                END IF;
                IF v_external_url IS NOT NULL
                   AND v_external_url !~* '^https://' THEN
                    RAISE EXCEPTION
                        'external_url must use HTTPS.';
                END IF;
                IF v_version < 1
                   OR (
                       v_estimated_minutes IS NOT NULL
                       AND v_estimated_minutes < 1
                   ) THEN
                    RAISE EXCEPTION
                        'Version and optional reading time must be positive.';
                END IF;

                SELECT resource.id
                INTO v_record_id
                FROM public.learning_resources AS resource
                WHERE pg_catalog.upper(resource.code) = v_code
                FOR UPDATE;

                IF v_record_id IS NULL THEN
                    INSERT INTO public.learning_resources (
                        subject_id,
                        module_id,
                        chapter_id,
                        topic_id,
                        resource_type_id,
                        code,
                        title,
                        short_description,
                        content,
                        external_url,
                        attachment_path,
                        author_name,
                        version_no,
                        estimated_read_minutes,
                        display_order,
                        is_exam_relevant,
                        is_premium,
                        is_active
                    )
                    VALUES (
                        v_subject_id,
                        v_module_id,
                        v_chapter_id,
                        v_topic_id,
                        v_resource_type_id,
                        v_code,
                        v_title,
                        v_short_description,
                        v_content,
                        v_external_url,
                        v_attachment_path,
                        v_author_name,
                        v_version,
                        v_estimated_minutes,
                        v_display_order,
                        v_is_exam_relevant,
                        v_is_premium,
                        v_is_active
                    )
                    RETURNING id INTO v_record_id;
                    v_action := 'create';
                ELSE
                    UPDATE public.learning_resources AS resource
                    SET subject_id = v_subject_id,
                        module_id = v_module_id,
                        chapter_id = v_chapter_id,
                        topic_id = v_topic_id,
                        resource_type_id = v_resource_type_id,
                        title = v_title,
                        short_description = v_short_description,
                        content = v_content,
                        external_url = v_external_url,
                        attachment_path = v_attachment_path,
                        author_name = v_author_name,
                        version_no = v_version,
                        estimated_read_minutes = v_estimated_minutes,
                        display_order = v_display_order,
                        is_exam_relevant = v_is_exam_relevant,
                        is_premium = v_is_premium,
                        is_active = v_is_active,
                        updated_at = pg_catalog.clock_timestamp()
                    WHERE resource.id = v_record_id;
                    v_action := 'update';
                END IF;
                v_record_key := v_code;
            END;

        WHEN 'flashcards' THEN
            DECLARE
                v_subject_code text := pg_catalog.upper(
                    pg_catalog.btrim(COALESCE(
                        p_record ->> 'subject_code',
                        ''
                    ))
                );
                v_module_code text := pg_catalog.lower(
                    pg_catalog.btrim(COALESCE(
                        p_record ->> 'module_code',
                        ''
                    ))
                );
                v_chapter_code text := pg_catalog.lower(
                    pg_catalog.btrim(COALESCE(
                        p_record ->> 'chapter_code',
                        ''
                    ))
                );
                v_topic_code text := pg_catalog.lower(
                    pg_catalog.btrim(COALESCE(
                        p_record ->> 'topic_code',
                        ''
                    ))
                );
                v_subject_id integer;
                v_module_id integer;
                v_chapter_id integer;
                v_topic_id integer;
                v_code text := pg_catalog.upper(
                    pg_catalog.btrim(COALESCE(p_record ->> 'code', ''))
                );
                v_question text :=
                    pg_catalog.btrim(COALESCE(p_record ->> 'question', ''));
                v_answer text :=
                    pg_catalog.btrim(COALESCE(p_record ->> 'answer', ''));
                v_explanation text :=
                    NULLIF(pg_catalog.btrim(p_record ->> 'explanation'), '');
                v_difficulty text := pg_catalog.lower(
                    pg_catalog.btrim(COALESCE(
                        p_record ->> 'difficulty_level',
                        ''
                    ))
                );
                v_is_exam_relevant boolean := COALESCE(
                    (p_record ->> 'is_exam_relevant')::boolean,
                    true
                );
            BEGIN
                SELECT
                    subject_record.id,
                    module_record.id,
                    chapter.id,
                    topic.id
                INTO
                    v_subject_id,
                    v_module_id,
                    v_chapter_id,
                    v_topic_id
                FROM public.subjects AS subject_record
                JOIN public.subject_modules AS module_record
                  ON module_record.subject_id = subject_record.id
                JOIN public.subject_chapters AS chapter
                  ON chapter.subject_id = subject_record.id
                 AND chapter.module_id = module_record.id
                JOIN public.subject_topics AS topic
                  ON topic.subject_id = subject_record.id
                 AND topic.module_id = module_record.id
                 AND topic.chapter_id = chapter.id
                WHERE pg_catalog.upper(subject_record.code) =
                    v_subject_code
                  AND pg_catalog.lower(module_record.code) =
                    v_module_code
                  AND pg_catalog.lower(chapter.code) =
                    v_chapter_code
                  AND pg_catalog.lower(topic.code) = v_topic_code;

                IF v_subject_id IS NULL
                   OR v_module_id IS NULL
                   OR v_chapter_id IS NULL
                   OR v_topic_id IS NULL THEN
                    RAISE EXCEPTION
                        'The supplied subject, module, chapter, and topic codes do not form an existing path.';
                END IF;
                IF v_code !~ '^[A-Z0-9][A-Z0-9_:-]{1,119}$'
                   OR pg_catalog.char_length(v_question)
                        NOT BETWEEN 2 AND 5000
                   OR pg_catalog.char_length(v_answer)
                        NOT BETWEEN 1 AND 10000 THEN
                    RAISE EXCEPTION
                        'Enter a valid flashcard code, question, and answer.';
                END IF;
                IF v_difficulty NOT IN (
                    'foundation',
                    'intermediate',
                    'advanced'
                ) THEN
                    RAISE EXCEPTION
                        'difficulty_level must be foundation, intermediate, or advanced.';
                END IF;

                SELECT flashcard.id
                INTO v_record_id
                FROM public.flashcards AS flashcard
                WHERE pg_catalog.upper(flashcard.code) = v_code
                FOR UPDATE;

                IF v_record_id IS NULL THEN
                    INSERT INTO public.flashcards (
                        subject_id,
                        module_id,
                        chapter_id,
                        topic_id,
                        code,
                        question,
                        answer,
                        explanation,
                        display_order,
                        difficulty_level,
                        is_exam_relevant,
                        is_active
                    )
                    VALUES (
                        v_subject_id,
                        v_module_id,
                        v_chapter_id,
                        v_topic_id,
                        v_code,
                        v_question,
                        v_answer,
                        v_explanation,
                        v_display_order,
                        v_difficulty,
                        v_is_exam_relevant,
                        v_is_active
                    )
                    RETURNING id INTO v_record_id;
                    v_action := 'create';
                ELSE
                    UPDATE public.flashcards AS flashcard
                    SET subject_id = v_subject_id,
                        module_id = v_module_id,
                        chapter_id = v_chapter_id,
                        topic_id = v_topic_id,
                        question = v_question,
                        answer = v_answer,
                        explanation = v_explanation,
                        display_order = v_display_order,
                        difficulty_level = v_difficulty,
                        is_exam_relevant = v_is_exam_relevant,
                        is_active = v_is_active,
                        updated_at = pg_catalog.clock_timestamp()
                    WHERE flashcard.id = v_record_id;
                    v_action := 'update';
                END IF;
                v_record_key := v_code;
            END;

        ELSE
            RAISE EXCEPTION
                'Select a supported academic or learning-content type.';
    END CASE;

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
        v_entity,
        v_record_key,
        pg_catalog.jsonb_build_object(
            'record_id', v_record_id,
            'is_active', v_is_active
        )
    );

    RETURN v_record_id::text;
END;
$function$;

CREATE FUNCTION public.admin_save_entitlement(p_entitlement jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_actor uuid := auth.uid();
    v_entitlement_id uuid :=
        NULLIF(p_entitlement ->> 'id', '')::uuid;
    v_email text := pg_catalog.lower(
        pg_catalog.btrim(COALESCE(p_entitlement ->> 'email', ''))
    );
    v_subject_code text := pg_catalog.upper(
        pg_catalog.btrim(COALESCE(
            p_entitlement ->> 'subject_code',
            ''
        ))
    );
    v_user_id uuid;
    v_subject_id integer;
    v_access_type text := pg_catalog.lower(
        pg_catalog.btrim(COALESCE(
            p_entitlement ->> 'access_type',
            ''
        ))
    );
    v_status text := pg_catalog.lower(
        pg_catalog.btrim(COALESCE(p_entitlement ->> 'status', ''))
    );
    v_valid_from timestamptz := COALESCE(
        NULLIF(p_entitlement ->> 'valid_from', '')::timestamptz,
        pg_catalog.clock_timestamp()
    );
    v_valid_until timestamptz :=
        NULLIF(p_entitlement ->> 'valid_until', '')::timestamptz;
    v_source_reference text := NULLIF(
        pg_catalog.btrim(p_entitlement ->> 'source_reference'),
        ''
    );
    v_existing_user_id uuid;
    v_existing_subject_id integer;
    v_existing_access_type text;
    v_action text;
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;

    SELECT auth_user.id
    INTO v_user_id
    FROM auth.users AS auth_user
    JOIN public.profiles AS profile_record
      ON profile_record.id = auth_user.id
    WHERE pg_catalog.lower(auth_user.email) = v_email
      AND profile_record.status = 'active';

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION
            'email must match an existing active registered user.';
    END IF;

    SELECT subject_record.id
    INTO v_subject_id
    FROM public.subjects AS subject_record
    WHERE pg_catalog.upper(subject_record.code) = v_subject_code;

    IF v_subject_id IS NULL THEN
        RAISE EXCEPTION
            'subject_code does not match an existing subject.';
    END IF;

    IF v_access_type NOT IN (
        'complimentary',
        'promotional',
        'admin_grant'
    ) THEN
        RAISE EXCEPTION
            'Admin upload may grant only complimentary, promotional, or admin_grant access.';
    END IF;
    IF v_status NOT IN ('active', 'expired', 'revoked', 'pending') THEN
        RAISE EXCEPTION
            'status must be active, expired, revoked, or pending.';
    END IF;
    IF v_valid_until IS NOT NULL
       AND v_valid_until <= v_valid_from THEN
        RAISE EXCEPTION
            'valid_until must be later than valid_from.';
    END IF;
    IF v_source_reference IS NULL
       OR pg_catalog.char_length(v_source_reference)
            NOT BETWEEN 3 AND 180 THEN
        RAISE EXCEPTION
            'A 3-180 character source_reference is required.';
    END IF;

    IF v_entitlement_id IS NULL THEN
        IF EXISTS (
            SELECT 1
            FROM public.user_entitlements AS entitlement
            WHERE entitlement.user_id = v_user_id
              AND entitlement.subject_id = v_subject_id
              AND entitlement.status IN ('active', 'pending')
        ) THEN
            RAISE EXCEPTION
                'That user already has an active or pending entitlement for the subject.';
        END IF;

        INSERT INTO public.user_entitlements (
            user_id,
            subject_id,
            access_type,
            status,
            valid_from,
            valid_until,
            source_reference
        )
        VALUES (
            v_user_id,
            v_subject_id,
            v_access_type,
            v_status,
            v_valid_from,
            v_valid_until,
            v_source_reference
        )
        RETURNING id INTO v_entitlement_id;
        v_action := 'create';
    ELSE
        SELECT
            entitlement.user_id,
            entitlement.subject_id,
            entitlement.access_type
        INTO
            v_existing_user_id,
            v_existing_subject_id,
            v_existing_access_type
        FROM public.user_entitlements AS entitlement
        WHERE entitlement.id = v_entitlement_id
        FOR UPDATE;

        IF v_existing_user_id IS NULL THEN
            RAISE EXCEPTION 'The selected entitlement was not found.';
        END IF;
        IF v_existing_access_type IN ('purchase', 'subscription') THEN
            RAISE EXCEPTION
                'Payment or subscription entitlements cannot be changed by CSV upload.';
        END IF;
        IF v_existing_user_id <> v_user_id
           OR v_existing_subject_id <> v_subject_id THEN
            RAISE EXCEPTION
                'An existing entitlement cannot be reassigned to another user or subject.';
        END IF;

        UPDATE public.user_entitlements AS entitlement
        SET access_type = v_access_type,
            status = v_status,
            valid_from = v_valid_from,
            valid_until = v_valid_until,
            source_reference = v_source_reference,
            updated_at = pg_catalog.clock_timestamp()
        WHERE entitlement.id = v_entitlement_id;
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
        'entitlement',
        v_entitlement_id::text,
        pg_catalog.jsonb_build_object(
            'subject_code', v_subject_code,
            'access_type', v_access_type,
            'status', v_status,
            'valid_from', v_valid_from,
            'valid_until', v_valid_until,
            'source_reference', v_source_reference
        )
    );

    RETURN v_entitlement_id;
END;
$function$;

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
    v_record_key text;
    v_subject_id integer;
    v_user_id uuid;
    v_email text;
    v_authority_id integer;
    v_programme_id integer;
    v_section_id integer;
    v_error_message text;
    v_record_keys jsonb := '[]'::jsonb;
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;

    IF v_entity NOT IN (
        'users',
        'subjects',
        'questions',
        'qualification_levels',
        'exam_authorities',
        'training_programmes',
        'programme_sections',
        'modules',
        'chapters',
        'topics',
        'learning_resource_types',
        'learning_resources',
        'flashcards',
        'exam_information',
        'entitlements'
    ) THEN
        RAISE EXCEPTION 'Select a supported administrator upload type.';
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
                    v_record_key := v_record_id::text;

                WHEN 'questions' THEN
                    SELECT subject_record.id
                    INTO v_subject_id
                    FROM public.subjects AS subject_record
                    WHERE pg_catalog.upper(subject_record.code) =
                        pg_catalog.upper(pg_catalog.btrim(
                            COALESCE(v_row ->> 'subject_code', '')
                        ));

                    IF v_subject_id IS NULL THEN
                        RAISE EXCEPTION
                            'subject_code does not match an existing subject.';
                    END IF;

                    v_payload := (v_row - 'subject_code')
                        || pg_catalog.jsonb_build_object(
                            'subject_id',
                            v_subject_id
                        );
                    v_record_id :=
                        public.admin_save_question(v_payload);
                    v_record_key := v_record_id::text;

                WHEN 'users' THEN
                    v_email := pg_catalog.lower(pg_catalog.btrim(
                        COALESCE(v_row ->> 'email', '')
                    ));
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
                    v_record_key := v_user_id::text;

                WHEN 'exam_information' THEN
                    SELECT authority.id
                    INTO v_authority_id
                    FROM public.exam_authorities AS authority
                    WHERE pg_catalog.lower(authority.code) =
                        pg_catalog.lower(pg_catalog.btrim(
                            COALESCE(v_row ->> 'authority_code', '')
                        ));

                    IF v_authority_id IS NULL THEN
                        RAISE EXCEPTION
                            'authority_code does not match an existing examination authority.';
                    END IF;

                    v_subject_id := NULL;
                    IF NULLIF(pg_catalog.btrim(
                        v_row ->> 'subject_code'
                    ), '') IS NOT NULL THEN
                        SELECT subject_record.id
                        INTO v_subject_id
                        FROM public.subjects AS subject_record
                        WHERE pg_catalog.upper(subject_record.code) =
                            pg_catalog.upper(pg_catalog.btrim(
                                v_row ->> 'subject_code'
                            ));
                        IF v_subject_id IS NULL THEN
                            RAISE EXCEPTION
                                'subject_code does not match an existing subject.';
                        END IF;
                    END IF;

                    v_programme_id := NULL;
                    IF NULLIF(pg_catalog.btrim(
                        v_row ->> 'programme_code'
                    ), '') IS NOT NULL THEN
                        SELECT programme.id
                        INTO v_programme_id
                        FROM public.training_programmes AS programme
                        WHERE pg_catalog.lower(programme.code) =
                            pg_catalog.lower(pg_catalog.btrim(
                                v_row ->> 'programme_code'
                            ))
                          AND programme.exam_authority_id =
                            v_authority_id;
                        IF v_programme_id IS NULL THEN
                            RAISE EXCEPTION
                                'programme_code does not belong to the supplied authority.';
                        END IF;
                    END IF;

                    v_section_id := NULL;
                    IF NULLIF(pg_catalog.btrim(
                        v_row ->> 'section_code'
                    ), '') IS NOT NULL THEN
                        IF v_programme_id IS NULL THEN
                            RAISE EXCEPTION
                                'programme_code is required when section_code is supplied.';
                        END IF;
                        SELECT section.id
                        INTO v_section_id
                        FROM public.programme_sections AS section
                        WHERE section.training_programme_id =
                            v_programme_id
                          AND pg_catalog.lower(section.code) =
                            pg_catalog.lower(pg_catalog.btrim(
                                v_row ->> 'section_code'
                            ));
                        IF v_section_id IS NULL THEN
                            RAISE EXCEPTION
                                'section_code does not belong to the supplied programme.';
                        END IF;
                    END IF;

                    v_payload := (
                        v_row
                        - 'authority_code'
                        - 'subject_code'
                        - 'programme_code'
                        - 'section_code'
                    ) || pg_catalog.jsonb_build_object(
                        'exam_authority_id',
                        v_authority_id,
                        'subject_id',
                        v_subject_id,
                        'training_programme_id',
                        v_programme_id,
                        'programme_section_id',
                        v_section_id
                    );
                    v_record_id :=
                        public.admin_save_exam_information(v_payload);
                    v_record_key := v_record_id::text;

                WHEN 'entitlements' THEN
                    v_record_key :=
                        public.admin_save_entitlement(v_row)::text;

                ELSE
                    v_record_key :=
                        public.admin_save_academic_content(
                            v_entity,
                            v_row
                        );
            END CASE;

            v_record_keys := v_record_keys
                || pg_catalog.jsonb_build_array(v_record_key);
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

ALTER FUNCTION public.admin_save_academic_content(text, jsonb)
OWNER TO postgres;
ALTER FUNCTION public.admin_save_entitlement(jsonb)
OWNER TO postgres;
ALTER FUNCTION public.admin_bulk_import(text, jsonb)
OWNER TO postgres;

REVOKE ALL ON FUNCTION
    public.admin_save_academic_content(text, jsonb)
FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.admin_save_entitlement(jsonb)
FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.admin_bulk_import(text, jsonb)
FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION
    public.admin_save_academic_content(text, jsonb)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_save_entitlement(jsonb)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_bulk_import(text, jsonb)
TO authenticated;

COMMENT ON FUNCTION
    public.admin_save_academic_content(text, jsonb) IS
    'Creates or updates approved academic and learning records by stable codes after active-administrator and hierarchy validation, with one audit event per record.';
COMMENT ON FUNCTION public.admin_save_entitlement(jsonb) IS
    'Creates or updates non-payment administrator grants for existing active users without changing payment or subscription entitlements.';
COMMENT ON FUNCTION public.admin_bulk_import(text, jsonb) IS
    'Atomically applies up to 250 reviewed administrator CSV rows through existing or dedicated audited save functions.';

NOTIFY pgrst, 'reload schema';

COMMIT;
