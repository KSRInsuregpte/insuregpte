-- READ-ONLY: safe to run before the academic hierarchy migrations.
-- Expected output: one result grid with audit_section and details columns.

WITH qualification_snapshot AS (
    SELECT
        '01_qualification_levels'::text AS audit_section,
        pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
                'id', qualification.id,
                'code', qualification.code,
                'name', qualification.name,
                'is_active', qualification.is_active
            )
            ORDER BY qualification.display_order, qualification.id
        ) AS details
    FROM public.qualification_levels AS qualification
),
programme_snapshot AS (
    SELECT
        '02_training_programmes'::text AS audit_section,
        pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
                'id', programme.id,
                'code', programme.code,
                'name', programme.name,
                'description', programme.description,
                'category', programme.programme_category,
                'is_active', programme.is_active
            )
            ORDER BY programme.display_order, programme.id
        ) AS details
    FROM public.training_programmes AS programme
),
section_snapshot AS (
    SELECT
        '03_programme_sections'::text AS audit_section,
        pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
                'id', section.id,
                'programme_id', section.training_programme_id,
                'programme_code', programme.code,
                'code', section.code,
                'name', section.name,
                'is_active', section.is_active
            )
            ORDER BY programme.code, section.display_order, section.id
        ) AS details
    FROM public.programme_sections AS section
    JOIN public.training_programmes AS programme
      ON programme.id = section.training_programme_id
),
subject_mismatch_snapshot AS (
    SELECT
        '04_subject_section_mismatches'::text AS audit_section,
        pg_catalog.jsonb_build_object(
            'count', pg_catalog.count(*),
            'subjects', COALESCE(
                pg_catalog.jsonb_agg(
                    pg_catalog.jsonb_build_object(
                        'subject_id', subject_record.id,
                        'subject_code', subject_record.code,
                        'subject_programme_id',
                            subject_record.training_programme_id,
                        'section_id', section.id,
                        'section_programme_id',
                            section.training_programme_id,
                        'section_code', section.code,
                        'section_name', section.name
                    )
                    ORDER BY subject_record.code
                ),
                '[]'::jsonb
            )
        ) AS details
    FROM public.subjects AS subject_record
    JOIN public.programme_sections AS section
      ON section.id = subject_record.programme_section_id
    WHERE subject_record.training_programme_id IS NOT NULL
      AND section.training_programme_id
          IS DISTINCT FROM subject_record.training_programme_id
),
publication_mismatch_snapshot AS (
    SELECT
        '05_exam_information_section_mismatches'::text AS audit_section,
        pg_catalog.jsonb_build_object(
            'count', pg_catalog.count(*),
            'records', COALESCE(
                pg_catalog.jsonb_agg(
                    pg_catalog.jsonb_build_object(
                        'information_id', publication.id,
                        'source_document_id', publication.source_document_id,
                        'programme_id', publication.training_programme_id,
                        'section_id', section.id,
                        'section_programme_id',
                            section.training_programme_id,
                        'section_code', section.code
                    )
                    ORDER BY publication.id
                ),
                '[]'::jsonb
            )
        ) AS details
    FROM public.regulatory_academic_publications AS publication
    JOIN public.programme_sections AS section
      ON section.id = publication.programme_section_id
    WHERE publication.training_programme_id IS NOT NULL
      AND section.training_programme_id
          IS DISTINCT FROM publication.training_programme_id
)
SELECT * FROM qualification_snapshot
UNION ALL
SELECT * FROM programme_snapshot
UNION ALL
SELECT * FROM section_snapshot
UNION ALL
SELECT * FROM subject_mismatch_snapshot
UNION ALL
SELECT * FROM publication_mismatch_snapshot
ORDER BY audit_section;
