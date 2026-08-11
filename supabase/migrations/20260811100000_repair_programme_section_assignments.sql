-- Repair legacy programme-section references that point to another programme.
-- Run after 20260810120000_freeze_academic_hierarchy.sql.

DO $guard$
BEGIN
    IF pg_catalog.to_regclass('public.subjects') IS NULL
       OR pg_catalog.to_regclass('public.training_programmes') IS NULL
       OR pg_catalog.to_regclass('public.programme_sections') IS NULL
       OR pg_catalog.to_regclass(
           'public.regulatory_academic_publications'
       ) IS NULL THEN
        RAISE EXCEPTION 'The academic hierarchy tables are unavailable.';
    END IF;
END;
$guard$;

LOCK TABLE public.programme_sections IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.subjects IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.regulatory_academic_publications
    IN SHARE ROW EXCLUSIVE MODE;

UPDATE public.subjects AS subject_record
SET programme_section_id = target_section.id,
    updated_at = pg_catalog.clock_timestamp()
FROM public.programme_sections AS current_section
JOIN public.programme_sections AS target_section
  ON target_section.code = current_section.code
WHERE current_section.id = subject_record.programme_section_id
  AND subject_record.training_programme_id IS NOT NULL
  AND current_section.training_programme_id
      IS DISTINCT FROM subject_record.training_programme_id
  AND target_section.training_programme_id
      = subject_record.training_programme_id;

UPDATE public.regulatory_academic_publications AS publication
SET programme_section_id = target_section.id,
    updated_at = pg_catalog.clock_timestamp()
FROM public.programme_sections AS current_section
JOIN public.programme_sections AS target_section
  ON target_section.code = current_section.code
WHERE current_section.id = publication.programme_section_id
  AND publication.training_programme_id IS NOT NULL
  AND current_section.training_programme_id
      IS DISTINCT FROM publication.training_programme_id
  AND target_section.training_programme_id
      = publication.training_programme_id;

DO $verify$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM public.subjects AS subject_record
        JOIN public.programme_sections AS section
          ON section.id = subject_record.programme_section_id
        WHERE subject_record.training_programme_id IS NOT NULL
          AND section.training_programme_id
              IS DISTINCT FROM subject_record.training_programme_id
    ) THEN
        RAISE EXCEPTION
            'A subject remains linked to a section from another programme.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.regulatory_academic_publications AS publication
        JOIN public.programme_sections AS section
          ON section.id = publication.programme_section_id
        WHERE publication.training_programme_id IS NOT NULL
          AND section.training_programme_id
              IS DISTINCT FROM publication.training_programme_id
    ) THEN
        RAISE EXCEPTION
            'Exam information remains linked to a section from another programme.';
    END IF;
END;
$verify$;

NOTIFY pgrst, 'reload schema';
