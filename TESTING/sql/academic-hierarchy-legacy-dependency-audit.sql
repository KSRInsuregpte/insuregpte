-- READ-ONLY: identifies records attached to legacy hierarchy values.
-- This query does not insert, update, or delete data.

WITH legacy_related_subjects AS (
    SELECT
        subject_record.id AS subject_id,
        subject_record.code AS subject_code,
        subject_record.title AS subject_title,
        subject_record.category,
        subject_record.is_active,
        qualification.id AS qualification_id,
        qualification.code AS qualification_code,
        qualification.name AS qualification_name,
        programme.id AS programme_id,
        programme.code AS programme_code,
        programme.name AS programme_name,
        section.id AS section_id,
        section.code AS section_code,
        section.name AS section_name
    FROM public.subjects AS subject_record
    LEFT JOIN public.qualification_levels AS qualification
      ON qualification.id = subject_record.qualification_level_id
    LEFT JOIN public.training_programmes AS programme
      ON programme.id = subject_record.training_programme_id
    LEFT JOIN public.programme_sections AS section
      ON section.id = subject_record.programme_section_id
    WHERE qualification.code IN (
              'specialised_training',
              'iii_optional_credit'
          )
       OR programme.code IN (
              'iii_optional_credit',
              'nia_life_broker'
          )
),
legacy_related_publications AS (
    SELECT
        publication.id AS information_id,
        publication.source_document_id,
        publication.title,
        publication.subject_id,
        programme.id AS programme_id,
        programme.code AS programme_code,
        programme.name AS programme_name,
        section.id AS section_id,
        section.code AS section_code,
        section.name AS section_name,
        publication.is_active
    FROM public.regulatory_academic_publications AS publication
    LEFT JOIN public.training_programmes AS programme
      ON programme.id = publication.training_programme_id
    LEFT JOIN public.programme_sections AS section
      ON section.id = publication.programme_section_id
    WHERE programme.code IN (
              'iii_optional_credit',
              'nia_life_broker'
          )
),
subject_snapshot AS (
    SELECT
        '01_legacy_related_subjects'::text AS audit_section,
        pg_catalog.jsonb_build_object(
            'count', pg_catalog.count(*),
            'records', COALESCE(
                pg_catalog.jsonb_agg(
                    pg_catalog.to_jsonb(legacy_related_subjects)
                    ORDER BY subject_code, subject_id
                ),
                '[]'::jsonb
            )
        ) AS details
    FROM legacy_related_subjects
),
publication_snapshot AS (
    SELECT
        '02_legacy_related_exam_information'::text AS audit_section,
        pg_catalog.jsonb_build_object(
            'count', pg_catalog.count(*),
            'records', COALESCE(
                pg_catalog.jsonb_agg(
                    pg_catalog.to_jsonb(legacy_related_publications)
                    ORDER BY information_id
                ),
                '[]'::jsonb
            )
        ) AS details
    FROM legacy_related_publications
),
section_usage_snapshot AS (
    SELECT
        '03_legacy_section_usage'::text AS audit_section,
        COALESCE(
            pg_catalog.jsonb_agg(
                pg_catalog.jsonb_build_object(
                    'section_id', section.id,
                    'section_code', section.code,
                    'section_name', section.name,
                    'programme_id', programme.id,
                    'programme_code', programme.code,
                    'subject_count', (
                        SELECT pg_catalog.count(*)
                        FROM public.subjects AS subject_record
                        WHERE subject_record.programme_section_id = section.id
                    ),
                    'exam_information_count', (
                        SELECT pg_catalog.count(*)
                        FROM public.regulatory_academic_publications
                            AS publication
                        WHERE publication.programme_section_id = section.id
                    )
                )
                ORDER BY programme.code, section.display_order, section.id
            ),
            '[]'::jsonb
        ) AS details
    FROM public.programme_sections AS section
    JOIN public.training_programmes AS programme
      ON programme.id = section.training_programme_id
    WHERE programme.code IN (
        'iii_optional_credit',
        'nia_life_broker'
    )
),
unapproved_category_snapshot AS (
    SELECT
        '04_unapproved_subject_categories'::text AS audit_section,
        pg_catalog.jsonb_build_object(
            'count', pg_catalog.count(*),
            'records', COALESCE(
                pg_catalog.jsonb_agg(
                    pg_catalog.jsonb_build_object(
                        'category', category_record.category,
                        'subject_count', category_record.subject_count,
                        'subject_codes', category_record.subject_codes
                    ) ORDER BY category_record.category
                ),
                '[]'::jsonb
            )
        ) AS details
    FROM (
        SELECT
            subject_record.category,
            pg_catalog.count(*) AS subject_count,
            pg_catalog.jsonb_agg(
                subject_record.code ORDER BY subject_record.code
            ) AS subject_codes
        FROM public.subjects AS subject_record
        WHERE subject_record.category IS NULL
           OR pg_catalog.btrim(subject_record.category) NOT IN (
                'General Insurance',
                'Life Insurance',
                'Common (Life & Non-Life)',
                'Regulation and Compliance'
           )
        GROUP BY subject_record.category
    ) AS category_record
)
SELECT * FROM subject_snapshot
UNION ALL
SELECT * FROM publication_snapshot
UNION ALL
SELECT * FROM section_usage_snapshot
UNION ALL
SELECT * FROM unapproved_category_snapshot
ORDER BY audit_section;
