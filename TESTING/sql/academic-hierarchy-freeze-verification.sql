-- Read-only verification for the approved academic hierarchy freeze.

DO $verification$
BEGIN
    IF (SELECT count(*) FROM public.qualification_levels) <> 8 THEN
        RAISE EXCEPTION 'Expected exactly eight qualification levels.';
    END IF;

    IF (SELECT count(*) FROM public.training_programmes) <> 8 THEN
        RAISE EXCEPTION 'Expected exactly eight training programmes.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.training_programmes
        WHERE code = 'nia_life_broker'
    ) THEN
        RAISE EXCEPTION 'The standalone NIA Life Broker programme remains.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.training_programmes
        WHERE programme_category NOT IN (
            'professional_qualification', 'broker_exam',
            'surveyor_exam', 'specialized_diploma_exam'
        )
    ) THEN
        RAISE EXCEPTION 'An invalid programme category remains.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.programme_sections
        WHERE code NOT IN (
            'compulsory', 'compulsory_optional', 'optional_credit',
            'general_insurance', 'life_insurance', 'reinsurance',
            'broker', 'surveyor', 'spl_diploma'
        )
    ) THEN
        RAISE EXCEPTION 'An invalid programme section remains.';
    END IF;

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
            'A subject uses a section from another programme.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.subjects
        WHERE category IS NULL
           OR category <> pg_catalog.btrim(category)
           OR category NOT IN (
                'General Insurance',
                'Life Insurance',
                'Common (Life & Non-Life)',
                'Regulation and Compliance'
           )
    ) THEN
        RAISE EXCEPTION 'An invalid subject category remains.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.training_programmes
        WHERE code = 'nia_direct_general_health'
          AND name = 'Direct Broker – General, Life and Health Training'
          AND description = 'General, Life and Health Training'
    ) THEN
        RAISE EXCEPTION 'Direct Broker naming or description is incorrect.';
    END IF;
END;
$verification$;

SELECT
    qualification.code,
    qualification.name,
    qualification.display_order,
    qualification.is_active
FROM public.qualification_levels AS qualification
ORDER BY qualification.display_order, qualification.code;

SELECT
    authority.code AS authority_code,
    programme.code,
    programme.name,
    programme.programme_category,
    programme.display_order,
    programme.is_active
FROM public.training_programmes AS programme
JOIN public.exam_authorities AS authority
  ON authority.id = programme.exam_authority_id
ORDER BY authority.code, programme.display_order, programme.code;

SELECT
    programme.code AS programme_code,
    section.code,
    section.name,
    section.display_order,
    section.is_active
FROM public.programme_sections AS section
JOIN public.training_programmes AS programme
  ON programme.id = section.training_programme_id
ORDER BY programme.code, section.display_order, section.code;
