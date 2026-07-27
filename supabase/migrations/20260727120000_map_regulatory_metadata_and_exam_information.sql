-- Map approved trial metadata to the existing academic hierarchy and expose
-- current examination-session information through one audited RPC.
--
-- This migration intentionally reuses qualification_levels, exam_authorities,
-- training_programmes, programme_sections, and subjects. The pre-deployment
-- audit confirmed that no academic source-publication table or proposed RPC
-- already exists.
--
-- Prerequisite:
--   Review TESTING/sql/regulatory-academic-hierarchy-audit.sql output.
--
-- Rollback:
--   supabase/rollbacks/20260727120000_map_regulatory_metadata_and_exam_information.sql

DO $guard$
DECLARE
    v_required_table text;
    v_code text;
    v_count integer;
BEGIN
    FOREACH v_required_table IN ARRAY ARRAY[
        'qualification_levels',
        'exam_authorities',
        'training_programmes',
        'programme_sections',
        'subjects'
    ]
    LOOP
        IF pg_catalog.to_regclass(
            pg_catalog.format('public.%I', v_required_table)
        ) IS NULL THEN
            RAISE EXCEPTION 'Required table public.% is missing',
                v_required_table;
        END IF;
    END LOOP;

    IF pg_catalog.to_regclass(
        'public.regulatory_academic_publications'
    ) IS NOT NULL THEN
        RAISE EXCEPTION
            'regulatory_academic_publications already exists; audit before deployment';
    END IF;

    IF pg_catalog.to_regprocedure(
        'public.get_exam_information(text,text,text)'
    ) IS NOT NULL THEN
        RAISE EXCEPTION
            'get_exam_information(text,text,text) already exists; audit before deployment';
    END IF;

    FOREACH v_code IN ARRAY ARRAY['IC01', 'IC11', 'IC14']
    LOOP
        SELECT COUNT(*)
        INTO v_count
        FROM public.subjects AS subject_record
        WHERE pg_catalog.regexp_replace(
            pg_catalog.upper(subject_record.code),
            '[^A-Z0-9]',
            '',
            'g'
        ) = v_code;

        IF v_count <> 1 THEN
            RAISE EXCEPTION
                'Expected exactly one existing % subject; found %',
                v_code,
                v_count;
        END IF;
    END LOOP;

    SELECT COUNT(*)
    INTO v_count
    FROM public.subjects AS subject_record
    WHERE pg_catalog.regexp_replace(
        pg_catalog.upper(subject_record.code),
        '[^A-Z0-9]',
        '',
        'g'
    ) = 'IC02';

    IF v_count <> 0 THEN
        RAISE EXCEPTION
            'IC02 changed since the reviewed audit; audit before deployment';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.subjects AS subject_record
        WHERE pg_catalog.regexp_replace(
            pg_catalog.upper(subject_record.code),
            '[^A-Z0-9]',
            '',
            'g'
        ) IN ('IC23', 'IC82')
          AND subject_record.is_active = true
    ) THEN
        RAISE EXCEPTION
            'Withdrawn IC23 or IC82 is active; resolve before deployment';
    END IF;
END;
$guard$;

DO $hierarchy_mapping$
DECLARE
    v_authority_id integer;
    v_level_id integer;
    v_programme_id integer;
    v_subject_count integer;
BEGIN
    SELECT authority.id
    INTO STRICT v_authority_id
    FROM public.exam_authorities AS authority
    WHERE pg_catalog.lower(authority.code) = 'iii';

    SELECT qualification.id
    INTO STRICT v_level_id
    FROM public.qualification_levels AS qualification
    WHERE pg_catalog.lower(qualification.code) = 'licentiate';

    SELECT programme.id
    INTO STRICT v_programme_id
    FROM public.training_programmes AS programme
    WHERE pg_catalog.lower(programme.code) = 'iii_licentiate'
      AND programme.exam_authority_id = v_authority_id;

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
    SELECT
        'IC02',
        'Practice of Life Insurance',
        v_level_id,
        'Official metadata registered. Learning and question content require review before activation.',
        'Life Insurance',
        'metadata_ready:2025-07-07',
        2,
        10,
        0,
        'INR',
        false,
        false,
        v_programme_id,
        null
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.subjects AS subject_record
        WHERE pg_catalog.regexp_replace(
            pg_catalog.upper(subject_record.code),
            '[^A-Z0-9]',
            '',
            'g'
        ) = 'IC02'
    );

    UPDATE public.subjects AS subject_record
    SET qualification_level_id = v_level_id,
        training_programme_id = v_programme_id
    WHERE pg_catalog.regexp_replace(
        pg_catalog.upper(subject_record.code),
        '[^A-Z0-9]',
        '',
        'g'
    ) IN ('IC01', 'IC02', 'IC11', 'IC14')
      AND (
          subject_record.qualification_level_id IS DISTINCT FROM v_level_id
          OR subject_record.training_programme_id IS DISTINCT FROM v_programme_id
      );

    SELECT COUNT(*)
    INTO v_subject_count
    FROM public.subjects AS subject_record
    WHERE pg_catalog.regexp_replace(
        pg_catalog.upper(subject_record.code),
        '[^A-Z0-9]',
        '',
        'g'
    ) IN ('IC01', 'IC02', 'IC11', 'IC14')
      AND subject_record.qualification_level_id = v_level_id
      AND subject_record.training_programme_id = v_programme_id;

    IF v_subject_count <> 4 THEN
        RAISE EXCEPTION
            'Pilot metadata hierarchy mapping is incomplete';
    END IF;
END;
$hierarchy_mapping$;

CREATE TABLE public.regulatory_academic_publications (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_document_id text NOT NULL,
    exam_authority_id integer NOT NULL
        REFERENCES public.exam_authorities(id),
    subject_id integer
        REFERENCES public.subjects(id),
    training_programme_id integer
        REFERENCES public.training_programmes(id),
    programme_section_id integer
        REFERENCES public.programme_sections(id),
    session_code text,
    document_type text NOT NULL CHECK (
        document_type IN (
            'handbook',
            'syllabus',
            'credit_points',
            'subject_amendment',
            'withdrawal_notice',
            'schedule',
            'centre_list',
            'language_list'
        )
    ),
    title text NOT NULL,
    geographic_scope text NOT NULL DEFAULT 'all' CHECK (
        geographic_scope IN ('all', 'india', 'overseas')
    ),
    official_url text,
    discovery_url text,
    published_on date,
    effective_from date,
    valid_until date,
    content_usage text NOT NULL CHECK (
        content_usage IN ('metadata_only', 'reference_only')
    ),
    verification_status text NOT NULL CHECK (
        verification_status IN (
            'official_url_verified',
            'visual_source_verified',
            'document_date_verified'
        )
    ),
    verified_on date NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT pg_catalog.now(),
    updated_at timestamp with time zone NOT NULL DEFAULT pg_catalog.now(),
    CHECK (
        valid_until IS NULL
        OR published_on IS NULL
        OR valid_until >= published_on
    ),
    CHECK (
        document_type NOT IN (
            'schedule',
            'centre_list',
            'language_list'
        )
        OR (
            NULLIF(pg_catalog.btrim(session_code), '') IS NOT NULL
            AND valid_until IS NOT NULL
        )
    )
);

CREATE UNIQUE INDEX uq_regulatory_academic_publications_document_subject
ON public.regulatory_academic_publications (
    source_document_id,
    COALESCE(subject_id, 0)
);

CREATE INDEX idx_regulatory_academic_publications_current_session
ON public.regulatory_academic_publications (
    exam_authority_id,
    session_code,
    valid_until
)
WHERE is_active = true;

ALTER TABLE public.regulatory_academic_publications ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.regulatory_academic_publications FROM PUBLIC;
REVOKE ALL ON TABLE public.regulatory_academic_publications FROM anon;
REVOKE ALL ON TABLE public.regulatory_academic_publications FROM authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE
ON TABLE public.regulatory_academic_publications TO service_role;

WITH source_rows (
    source_document_id,
    subject_code,
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
    verified_on
) AS (
    VALUES
        (
            'iii-examination-handbook-2026', null, null, 'handbook',
            'Examination Handbook', 'all',
            'https://www.insuranceinstituteofindia.com/documents/d/guest/examination-handbook-new',
            null, null, null, null, 'reference_only',
            'official_url_verified', date '2026-07-26'
        ),
        (
            'iii-professional-syllabus-2025-07-07', 'IC01', null, 'syllabus',
            'Professional Examination syllabus and subject contents', 'all',
            'https://www.insuranceinstituteofindia.com/documents/d/guest/1-professional-examination-only-contents-updated-on-7-7-2025',
            null, date '2025-07-07', null, null, 'reference_only',
            'official_url_verified', date '2026-07-26'
        ),
        (
            'iii-professional-syllabus-2025-07-07', 'IC02', null, 'syllabus',
            'Professional Examination syllabus and subject contents', 'all',
            'https://www.insuranceinstituteofindia.com/documents/d/guest/1-professional-examination-only-contents-updated-on-7-7-2025',
            null, date '2025-07-07', null, null, 'reference_only',
            'official_url_verified', date '2026-07-26'
        ),
        (
            'iii-professional-syllabus-2025-07-07', 'IC11', null, 'syllabus',
            'Professional Examination syllabus and subject contents', 'all',
            'https://www.insuranceinstituteofindia.com/documents/d/guest/1-professional-examination-only-contents-updated-on-7-7-2025',
            null, date '2025-07-07', null, null, 'reference_only',
            'official_url_verified', date '2026-07-26'
        ),
        (
            'iii-professional-syllabus-2025-07-07', 'IC14', null, 'syllabus',
            'Professional Examination syllabus and subject contents', 'all',
            'https://www.insuranceinstituteofindia.com/documents/d/guest/1-professional-examination-only-contents-updated-on-7-7-2025',
            null, date '2025-07-07', null, null, 'reference_only',
            'official_url_verified', date '2026-07-26'
        ),
        (
            'iii-credit-points-2025-03-27', 'IC01', null, 'credit_points',
            'Credit Point System', 'all',
            'https://www.insuranceinstituteofindia.com/documents/d/guest/credit-point-system',
            null, date '2025-03-27', null, null, 'metadata_only',
            'official_url_verified', date '2026-07-26'
        ),
        (
            'iii-credit-points-2025-03-27', 'IC02', null, 'credit_points',
            'Credit Point System', 'all',
            'https://www.insuranceinstituteofindia.com/documents/d/guest/credit-point-system',
            null, date '2025-03-27', null, null, 'metadata_only',
            'official_url_verified', date '2026-07-26'
        ),
        (
            'iii-credit-points-2025-03-27', 'IC11', null, 'credit_points',
            'Credit Point System', 'all',
            'https://www.insuranceinstituteofindia.com/documents/d/guest/credit-point-system',
            null, date '2025-03-27', null, null, 'metadata_only',
            'official_url_verified', date '2026-07-26'
        ),
        (
            'iii-credit-points-2025-03-27', 'IC14', null, 'credit_points',
            'Credit Point System', 'all',
            'https://www.insuranceinstituteofindia.com/documents/d/guest/credit-point-system',
            null, date '2025-03-27', null, null, 'metadata_only',
            'official_url_verified', date '2026-07-26'
        ),
        (
            'iii-amendment-ic01-2025-05-22', 'IC01', null, 'subject_amendment',
            'IC01 Principles of Insurance amendment', 'all',
            null, 'https://www.insuranceinstituteofindia.com/sitemap',
            date '2025-05-22', null, null, 'reference_only',
            'document_date_verified', date '2026-07-26'
        ),
        (
            'iii-amendment-ic02-2024-12-19', 'IC02', null, 'subject_amendment',
            'IC02 Practice of Life Insurance amendment', 'all',
            null, 'https://www.insuranceinstituteofindia.com/sitemap',
            date '2024-12-19', null, null, 'reference_only',
            'document_date_verified', date '2026-07-26'
        ),
        (
            'iii-amendment-ic14-2023-08-07', 'IC14', null, 'subject_amendment',
            'IC14 Regulations of Insurance Business amendment', 'all',
            null, 'https://www.insuranceinstituteofindia.com/sitemap',
            date '2023-08-07', null, null, 'reference_only',
            'document_date_verified', date '2026-07-26'
        ),
        (
            'iii-withdrawal-ic23-ic82-2021-11-29', null, null,
            'withdrawal_notice', 'Discontinuation of IC23 and IC82', 'all',
            null, 'https://www.insuranceinstituteofindia.com/sitemap',
            date '2021-11-29', date '2022-09-01', null, 'metadata_only',
            'visual_source_verified', date '2026-07-26'
        ),
        (
            'iii-yearly-examination-schedule-2026', null, 'III-2026',
            'schedule', 'Online Examination Schedule for the Year 2026', 'all',
            'https://www.insuranceinstituteofindia.com/documents/d/guest/yearly-schedule-2026-ticker-15-12-2025-',
            null, date '2025-12-15', null, date '2026-12-31',
            'metadata_only', 'official_url_verified', date '2026-07-26'
        ),
        (
            'iii-september-2026-examination-schedule', null, 'III-2026-09',
            'schedule', 'Online Examination Schedule for September 2026', 'all',
            'https://www.insuranceinstituteofindia.com/documents/d/guest/online-examination-schedule-for-sep-2026',
            null, date '2026-07-01', null, date '2026-09-30',
            'metadata_only', 'official_url_verified', date '2026-07-26'
        ),
        (
            'iii-september-2026-indian-centres', null, 'III-2026-09',
            'centre_list', 'September 2026 Online Examination Indian Centers List',
            'india', null,
            'https://www.insuranceinstituteofindia.com/sitemap',
            null, null, date '2026-09-30', 'metadata_only',
            'visual_source_verified', date '2026-07-26'
        ),
        (
            'iii-september-2026-overseas-centres', null, 'III-2026-09',
            'centre_list', 'September 2026 Online Examination Overseas Centers List',
            'overseas', null,
            'https://www.insuranceinstituteofindia.com/sitemap',
            date '2026-07-06', null, date '2026-09-30', 'metadata_only',
            'visual_source_verified', date '2026-07-26'
        ),
        (
            'iii-september-2026-bilingual-subjects', null, 'III-2026-09',
            'language_list', 'September 2026 Bilingual Subject List', 'all',
            null, 'https://www.insuranceinstituteofindia.com/sitemap',
            null, null, date '2026-09-30', 'metadata_only',
            'visual_source_verified', date '2026-07-26'
        )
)
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
    verified_on
)
SELECT
    source.source_document_id,
    authority.id,
    subject_record.id,
    subject_record.training_programme_id,
    subject_record.programme_section_id,
    source.session_code,
    source.document_type,
    source.title,
    source.geographic_scope,
    source.official_url,
    source.discovery_url,
    source.published_on,
    source.effective_from,
    source.valid_until,
    source.content_usage,
    source.verification_status,
    source.verified_on
FROM source_rows AS source
JOIN public.exam_authorities AS authority
  ON pg_catalog.lower(authority.code) = 'iii'
LEFT JOIN public.subjects AS subject_record
  ON source.subject_code IS NOT NULL
 AND pg_catalog.regexp_replace(
        pg_catalog.upper(subject_record.code),
        '[^A-Z0-9]',
        '',
        'g'
     ) = source.subject_code
WHERE source.subject_code IS NULL
   OR subject_record.id IS NOT NULL;

CREATE FUNCTION public.get_exam_information(
    p_authority_code text DEFAULT null,
    p_session_code text DEFAULT null,
    p_subject_code text DEFAULT null
)
RETURNS TABLE (
    authority_code text,
    authority_name text,
    session_code text,
    information_type text,
    title text,
    geographic_scope text,
    official_url text,
    discovery_url text,
    published_on date,
    valid_until date,
    subject_code text,
    training_programme_code text,
    programme_section_code text,
    source_document_id text,
    verification_status text,
    verified_on date
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
    SELECT
        authority.code,
        authority.name,
        source.session_code,
        source.document_type,
        source.title,
        source.geographic_scope,
        source.official_url,
        source.discovery_url,
        source.published_on,
        source.valid_until,
        subject_record.code,
        programme.code,
        section.code,
        source.source_document_id,
        source.verification_status,
        source.verified_on
    FROM public.regulatory_academic_publications AS source
    JOIN public.exam_authorities AS authority
      ON authority.id = source.exam_authority_id
    LEFT JOIN public.subjects AS subject_record
      ON subject_record.id = source.subject_id
    LEFT JOIN public.training_programmes AS programme
      ON programme.id = source.training_programme_id
    LEFT JOIN public.programme_sections AS section
      ON section.id = source.programme_section_id
    WHERE source.is_active = true
      AND source.document_type IN (
          'schedule',
          'centre_list',
          'language_list'
      )
      AND source.valid_until >= CURRENT_DATE
      AND (
          NULLIF(pg_catalog.btrim(p_authority_code), '') IS NULL
          OR pg_catalog.lower(authority.code) =
             pg_catalog.lower(pg_catalog.btrim(p_authority_code))
      )
      AND (
          NULLIF(pg_catalog.btrim(p_session_code), '') IS NULL
          OR pg_catalog.upper(source.session_code) =
             pg_catalog.upper(pg_catalog.btrim(p_session_code))
      )
      AND (
          NULLIF(pg_catalog.btrim(p_subject_code), '') IS NULL
          OR EXISTS (
              SELECT 1
              FROM public.subjects AS requested_subject
              WHERE pg_catalog.regexp_replace(
                  pg_catalog.upper(requested_subject.code),
                  '[^A-Z0-9]',
                  '',
                  'g'
              ) = pg_catalog.regexp_replace(
                  pg_catalog.upper(pg_catalog.btrim(p_subject_code)),
                  '[^A-Z0-9]',
                  '',
                  'g'
              )
          )
      )
      AND (
          NULLIF(pg_catalog.btrim(p_subject_code), '') IS NULL
          OR source.subject_id IS NULL
          OR pg_catalog.regexp_replace(
                 pg_catalog.upper(subject_record.code),
                 '[^A-Z0-9]',
                 '',
                 'g'
             ) = pg_catalog.regexp_replace(
                 pg_catalog.upper(pg_catalog.btrim(p_subject_code)),
                 '[^A-Z0-9]',
                 '',
                 'g'
             )
      )
    ORDER BY
        source.valid_until,
        source.session_code,
        CASE source.document_type
            WHEN 'schedule' THEN 1
            WHEN 'centre_list' THEN 2
            WHEN 'language_list' THEN 3
            ELSE 4
        END,
        source.geographic_scope,
        source.title;
$function$;

COMMENT ON TABLE public.regulatory_academic_publications IS
    'Audited official-source metadata mapped to the existing academic hierarchy; excludes archived source files and copyrighted content.';

COMMENT ON FUNCTION public.get_exam_information(text,text,text) IS
    'Returns current verified examination schedules, centre lists, and language notices for authenticated learners.';

REVOKE ALL
ON FUNCTION public.get_exam_information(text,text,text)
FROM PUBLIC;
REVOKE ALL
ON FUNCTION public.get_exam_information(text,text,text)
FROM anon;
GRANT EXECUTE
ON FUNCTION public.get_exam_information(text,text,text)
TO authenticated;
GRANT EXECUTE
ON FUNCTION public.get_exam_information(text,text,text)
TO service_role;
