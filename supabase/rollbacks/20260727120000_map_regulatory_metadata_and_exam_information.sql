-- Roll back approved metadata mapping and examination-information access.
--
-- IC02 is removed only while it remains the inactive metadata-only row created
-- by the matching migration. Foreign keys will stop removal if later content
-- or learner records depend on it.

DROP FUNCTION IF EXISTS public.get_exam_information(text,text,text);
DROP TABLE IF EXISTS public.regulatory_academic_publications;

DELETE FROM public.subjects AS subject_record
WHERE pg_catalog.regexp_replace(
    pg_catalog.upper(subject_record.code),
    '[^A-Z0-9]',
    '',
    'g'
) = 'IC02'
  AND subject_record.is_active = false
  AND subject_record.is_demo_available = false
  AND subject_record.price = 0
  AND subject_record.syllabus_version = 'metadata_ready:2025-07-07';
