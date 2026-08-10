-- Freeze the approved InsureGPTE academic hierarchy vocabulary.
-- This migration consolidates the former NIA Life Broker programme into
-- Direct Broker before removing it, so linked subjects and publications are
-- preserved.

LOCK TABLE public.qualification_levels IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.training_programmes IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.programme_sections IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.subjects IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.regulatory_academic_publications IN SHARE ROW EXCLUSIVE MODE;

DO $qualification_normalization$
DECLARE
    v_specialised_id integer;
    v_spl_diploma_id integer;
BEGIN
    SELECT id INTO v_specialised_id
    FROM public.qualification_levels
    WHERE pg_catalog.lower(code) = 'specialised_training';

    SELECT id INTO v_spl_diploma_id
    FROM public.qualification_levels
    WHERE pg_catalog.lower(code) = 'spl_diploma';

    IF v_specialised_id IS NOT NULL AND v_spl_diploma_id IS NULL THEN
        UPDATE public.qualification_levels
        SET code = 'spl_diploma',
            name = 'Spl. Dip Exam Preparation',
            description = 'III specialised diploma examination preparation.',
            display_order = 4,
            is_active = true
        WHERE id = v_specialised_id;
    ELSIF v_specialised_id IS NOT NULL THEN
        UPDATE public.subjects
        SET qualification_level_id = v_spl_diploma_id
        WHERE qualification_level_id = v_specialised_id;

        DELETE FROM public.qualification_levels
        WHERE id = v_specialised_id;
    END IF;
END;
$qualification_normalization$;

INSERT INTO public.qualification_levels (
    code,
    name,
    description,
    display_order,
    is_active
)
VALUES
    ('licentiate', 'Licentiate Exam Preparation',
     'III Licentiate examination preparation.', 1, true),
    ('associate', 'Associate Exam Preparation',
     'III Associate examination preparation.', 2, true),
    ('fellowship', 'Fellowship Exam Preparation',
     'III Fellowship examination preparation.', 3, true),
    ('spl_diploma', 'Spl. Dip Exam Preparation',
     'III specialised diploma examination preparation.', 4, true),
    ('surveyor', 'Surveyor Exam Preparation',
     'III Surveyor examination preparation.', 5, true),
    ('direct_broker', 'NIA - Direct Broker Exam Preparation',
     'General, Life and Health Training', 6, true),
    ('reinsurance_broker', 'NIA - Reinsurance Broker Exam Preparation',
     'NIA Reinsurance Broker examination preparation.', 7, true),
    ('composite_broker', 'NIA - Composite Broker Exam Preparation',
     'NIA Composite Broker examination preparation.', 8, true)
ON CONFLICT (code) DO UPDATE
SET name = EXCLUDED.name,
    description = EXCLUDED.description,
    display_order = EXCLUDED.display_order,
    is_active = EXCLUDED.is_active;

DO $programme_seed$
DECLARE
    v_iii_id integer;
BEGIN
    SELECT id INTO v_iii_id
    FROM public.exam_authorities
    WHERE pg_catalog.lower(code) = 'iii';

    IF v_iii_id IS NULL THEN
        RAISE EXCEPTION
            'The III examination authority must exist before freezing the hierarchy.';
    END IF;

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
    VALUES
        (v_iii_id, 'iii_spl_diploma', 'III - Spl. Dip Exam Preparation',
         'specialized_diploma_exam',
         'III specialised diploma examination preparation.',
         60, 75, null, null, false, 4, true),
        (v_iii_id, 'iii_surveyor', 'III Surveyor Exam Preparation',
         'surveyor_exam', 'III Surveyor examination preparation.',
         60, 75, null, null, false, 5, true)
    ON CONFLICT (code) DO UPDATE
    SET exam_authority_id = EXCLUDED.exam_authority_id,
        name = EXCLUDED.name,
        programme_category = EXCLUDED.programme_category,
        description = EXCLUDED.description,
        display_order = EXCLUDED.display_order,
        is_active = EXCLUDED.is_active;
END;
$programme_seed$;

UPDATE public.training_programmes
SET name = CASE code
        WHEN 'iii_licentiate' THEN 'III - Licentiate Exam Preparation'
        WHEN 'iii_associate' THEN 'III - Associate Exam Preparation'
        WHEN 'iii_fellowship' THEN 'III - Fellowship Exam Preparation'
        WHEN 'nia_direct_general_health' THEN
            'Direct Broker Training'
        WHEN 'nia_reinsurance_broker' THEN 'Reinsurance Broker Training'
        WHEN 'nia_composite_broker' THEN 'Composite Broker Training'
        ELSE name
    END,
    programme_category = CASE
        WHEN code IN (
            'iii_licentiate',
            'iii_associate',
            'iii_fellowship'
        ) THEN 'professional_qualification'
        WHEN code IN (
            'nia_direct_general_health',
            'nia_reinsurance_broker',
            'nia_composite_broker',
            'nia_life_broker'
        ) THEN 'broker_exam'
        ELSE programme_category
    END
WHERE code IN (
    'iii_licentiate',
    'iii_associate',
    'iii_fellowship',
    'nia_direct_general_health',
    'nia_life_broker',
    'nia_reinsurance_broker',
    'nia_composite_broker'
);

UPDATE public.training_programmes
SET description = 'General, Life and Health Training'
WHERE code = 'nia_direct_general_health';

DO $broker_consolidation$
DECLARE
    v_direct_id integer;
    v_life_id integer;
    v_old_section_id integer;
    v_target_section_id integer;
BEGIN
    SELECT id INTO v_direct_id
    FROM public.training_programmes
    WHERE code = 'nia_direct_general_health';

    SELECT id INTO v_life_id
    FROM public.training_programmes
    WHERE code = 'nia_life_broker';

    IF v_direct_id IS NULL THEN
        RAISE EXCEPTION
            'The NIA Direct Broker programme is required before consolidation.';
    END IF;

    IF v_life_id IS NOT NULL THEN
        SELECT id INTO v_old_section_id
        FROM public.programme_sections
        WHERE training_programme_id = v_life_id
          AND code = 'compulsory';

        SELECT id INTO v_target_section_id
        FROM public.programme_sections
        WHERE training_programme_id = v_direct_id
          AND code = 'compulsory';

        IF v_old_section_id IS NOT NULL AND v_target_section_id IS NOT NULL THEN
            UPDATE public.subjects
            SET programme_section_id = v_target_section_id
            WHERE programme_section_id = v_old_section_id;
            UPDATE public.regulatory_academic_publications
            SET programme_section_id = v_target_section_id
            WHERE programme_section_id = v_old_section_id;
            DELETE FROM public.programme_sections
            WHERE id = v_old_section_id;
        ELSIF v_old_section_id IS NOT NULL THEN
            UPDATE public.programme_sections
            SET training_programme_id = v_direct_id,
                name = 'Compulsory'
            WHERE id = v_old_section_id;
        END IF;

        SELECT id INTO v_old_section_id
        FROM public.programme_sections
        WHERE training_programme_id = v_life_id
          AND code = 'life_insurance';

        SELECT id INTO v_target_section_id
        FROM public.programme_sections
        WHERE training_programme_id = v_direct_id
          AND code = 'life_insurance';

        IF v_old_section_id IS NOT NULL AND v_target_section_id IS NOT NULL THEN
            UPDATE public.subjects
            SET programme_section_id = v_target_section_id
            WHERE programme_section_id = v_old_section_id;
            UPDATE public.regulatory_academic_publications
            SET programme_section_id = v_target_section_id
            WHERE programme_section_id = v_old_section_id;
            DELETE FROM public.programme_sections
            WHERE id = v_old_section_id;
        ELSIF v_old_section_id IS NOT NULL THEN
            UPDATE public.programme_sections
            SET training_programme_id = v_direct_id,
                name = 'Life Insurance'
            WHERE id = v_old_section_id;
        END IF;

        IF EXISTS (
            SELECT 1
            FROM public.programme_sections
            WHERE training_programme_id = v_life_id
        ) THEN
            RAISE EXCEPTION
                'The former Life Broker programme has an unapproved section.';
        END IF;

        UPDATE public.subjects
        SET training_programme_id = v_direct_id
        WHERE training_programme_id = v_life_id;

        UPDATE public.regulatory_academic_publications
        SET training_programme_id = v_direct_id
        WHERE training_programme_id = v_life_id;

        DELETE FROM public.training_programmes
        WHERE id = v_life_id;
    END IF;

    SELECT id INTO v_old_section_id
    FROM public.programme_sections
    WHERE training_programme_id = v_direct_id
      AND code = 'general_health';

    SELECT id INTO v_target_section_id
    FROM public.programme_sections
    WHERE training_programme_id = v_direct_id
      AND code = 'general_insurance';

    IF v_old_section_id IS NOT NULL AND v_target_section_id IS NOT NULL THEN
        UPDATE public.subjects
        SET programme_section_id = v_target_section_id
        WHERE programme_section_id = v_old_section_id;
        UPDATE public.regulatory_academic_publications
        SET programme_section_id = v_target_section_id
        WHERE programme_section_id = v_old_section_id;
        DELETE FROM public.programme_sections
        WHERE id = v_old_section_id;
    ELSIF v_old_section_id IS NOT NULL THEN
        UPDATE public.programme_sections
        SET code = 'general_insurance',
            name = 'General Insurance'
        WHERE id = v_old_section_id;
    END IF;
END;
$broker_consolidation$;

WITH approved_sections (
    programme_code,
    section_code,
    section_name,
    display_order
) AS (
    VALUES
        ('iii_licentiate', 'compulsory', 'Compulsory', 1),
        ('iii_licentiate', 'compulsory_optional', 'Compulsory Optional', 2),
        ('iii_licentiate', 'optional_credit', 'Optional Credit', 3),
        ('iii_licentiate', 'general_insurance', 'General Insurance', 4),
        ('iii_licentiate', 'life_insurance', 'Life Insurance', 5),
        ('iii_associate', 'compulsory', 'Compulsory', 1),
        ('iii_associate', 'compulsory_optional', 'Compulsory Optional', 2),
        ('iii_associate', 'optional_credit', 'Optional Credit', 3),
        ('iii_associate', 'general_insurance', 'General Insurance', 4),
        ('iii_associate', 'life_insurance', 'Life Insurance', 5),
        ('iii_fellowship', 'compulsory', 'Compulsory', 1),
        ('iii_fellowship', 'compulsory_optional', 'Compulsory Optional', 2),
        ('iii_fellowship', 'optional_credit', 'Optional Credit', 3),
        ('iii_fellowship', 'general_insurance', 'General Insurance', 4),
        ('iii_fellowship', 'life_insurance', 'Life Insurance', 5),
        ('iii_spl_diploma', 'compulsory', 'Compulsory', 1),
        ('iii_spl_diploma', 'spl_diploma', 'Spl_Diploma', 2),
        ('iii_surveyor', 'compulsory', 'Compulsory', 1),
        ('iii_surveyor', 'surveyor', 'Surveyor', 2),
        ('nia_direct_general_health', 'compulsory', 'Compulsory', 1),
        ('nia_direct_general_health', 'general_insurance', 'General Insurance', 2),
        ('nia_direct_general_health', 'life_insurance', 'Life Insurance', 3),
        ('nia_direct_general_health', 'broker', 'Broker', 4),
        ('nia_reinsurance_broker', 'compulsory', 'Compulsory', 1),
        ('nia_reinsurance_broker', 'reinsurance', 'Reinsurance', 2),
        ('nia_reinsurance_broker', 'broker', 'Broker', 3),
        ('nia_composite_broker', 'compulsory', 'Compulsory', 1),
        ('nia_composite_broker', 'general_insurance', 'General Insurance', 2),
        ('nia_composite_broker', 'life_insurance', 'Life Insurance', 3),
        ('nia_composite_broker', 'reinsurance', 'Reinsurance', 4),
        ('nia_composite_broker', 'broker', 'Broker', 5)
)
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
SELECT
    programme.id,
    approved.section_code,
    approved.section_name,
    'Approved InsureGPTE programme section.',
    null,
    null,
    approved.display_order,
    true
FROM approved_sections AS approved
JOIN public.training_programmes AS programme
  ON programme.code = approved.programme_code
WHERE NOT EXISTS (
    SELECT 1
    FROM public.programme_sections AS existing
    WHERE existing.training_programme_id = programme.id
      AND existing.code = approved.section_code
);

WITH approved_sections (
    programme_code,
    section_code,
    section_name,
    display_order
) AS (
    VALUES
        ('iii_licentiate', 'compulsory', 'Compulsory', 1),
        ('iii_licentiate', 'compulsory_optional', 'Compulsory Optional', 2),
        ('iii_licentiate', 'optional_credit', 'Optional Credit', 3),
        ('iii_licentiate', 'general_insurance', 'General Insurance', 4),
        ('iii_licentiate', 'life_insurance', 'Life Insurance', 5),
        ('iii_associate', 'compulsory', 'Compulsory', 1),
        ('iii_associate', 'compulsory_optional', 'Compulsory Optional', 2),
        ('iii_associate', 'optional_credit', 'Optional Credit', 3),
        ('iii_associate', 'general_insurance', 'General Insurance', 4),
        ('iii_associate', 'life_insurance', 'Life Insurance', 5),
        ('iii_fellowship', 'compulsory', 'Compulsory', 1),
        ('iii_fellowship', 'compulsory_optional', 'Compulsory Optional', 2),
        ('iii_fellowship', 'optional_credit', 'Optional Credit', 3),
        ('iii_fellowship', 'general_insurance', 'General Insurance', 4),
        ('iii_fellowship', 'life_insurance', 'Life Insurance', 5),
        ('iii_spl_diploma', 'compulsory', 'Compulsory', 1),
        ('iii_spl_diploma', 'spl_diploma', 'Spl_Diploma', 2),
        ('iii_surveyor', 'compulsory', 'Compulsory', 1),
        ('iii_surveyor', 'surveyor', 'Surveyor', 2),
        ('nia_direct_general_health', 'compulsory', 'Compulsory', 1),
        ('nia_direct_general_health', 'general_insurance', 'General Insurance', 2),
        ('nia_direct_general_health', 'life_insurance', 'Life Insurance', 3),
        ('nia_direct_general_health', 'broker', 'Broker', 4),
        ('nia_reinsurance_broker', 'compulsory', 'Compulsory', 1),
        ('nia_reinsurance_broker', 'reinsurance', 'Reinsurance', 2),
        ('nia_reinsurance_broker', 'broker', 'Broker', 3),
        ('nia_composite_broker', 'compulsory', 'Compulsory', 1),
        ('nia_composite_broker', 'general_insurance', 'General Insurance', 2),
        ('nia_composite_broker', 'life_insurance', 'Life Insurance', 3),
        ('nia_composite_broker', 'reinsurance', 'Reinsurance', 4),
        ('nia_composite_broker', 'broker', 'Broker', 5)
)
UPDATE public.programme_sections AS section
SET name = approved.section_name,
    display_order = approved.display_order,
    is_active = true
FROM approved_sections AS approved
JOIN public.training_programmes AS programme
  ON programme.code = approved.programme_code
WHERE section.training_programme_id = programme.id
  AND section.code = approved.section_code;

UPDATE public.subjects
SET category = CASE pg_catalog.lower(pg_catalog.btrim(category))
        WHEN 'general insurance' THEN 'General Insurance'
        WHEN 'life insurance' THEN 'Life Insurance'
        WHEN 'common' THEN 'Common (Life & Non-Life)'
        WHEN 'common subject' THEN 'Common (Life & Non-Life)'
        WHEN 'common (life & non-life)' THEN 'Common (Life & Non-Life)'
        WHEN 'foundation' THEN 'Common (Life & Non-Life)'
        WHEN 'regulation and compliance' THEN 'Regulation and Compliance'
        ELSE pg_catalog.btrim(category)
    END;

UPDATE public.subjects AS subject_record
SET qualification_level_id = qualification.id
FROM public.training_programmes AS programme
JOIN public.qualification_levels AS qualification
  ON qualification.code = CASE programme.code
      WHEN 'iii_licentiate' THEN 'licentiate'
      WHEN 'iii_associate' THEN 'associate'
      WHEN 'iii_fellowship' THEN 'fellowship'
      WHEN 'iii_spl_diploma' THEN 'spl_diploma'
      WHEN 'iii_surveyor' THEN 'surveyor'
      WHEN 'nia_direct_general_health' THEN 'direct_broker'
      WHEN 'nia_reinsurance_broker' THEN 'reinsurance_broker'
      WHEN 'nia_composite_broker' THEN 'composite_broker'
  END
WHERE subject_record.training_programme_id = programme.id;

DO $freeze_preflight$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM public.qualification_levels
        WHERE code NOT IN (
            'licentiate', 'associate', 'fellowship', 'spl_diploma',
            'surveyor', 'direct_broker', 'reinsurance_broker',
            'composite_broker'
        )
    ) THEN
        RAISE EXCEPTION 'An unapproved qualification level remains.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.training_programmes
        WHERE code NOT IN (
            'iii_licentiate', 'iii_associate', 'iii_fellowship',
            'iii_spl_diploma', 'iii_surveyor',
            'nia_direct_general_health', 'nia_reinsurance_broker',
            'nia_composite_broker'
        )
    ) THEN
        RAISE EXCEPTION 'An unapproved training programme remains.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.subjects
        WHERE category IS NULL
           OR pg_catalog.char_length(pg_catalog.btrim(category))
              NOT BETWEEN 2 AND 120
    ) THEN
        RAISE EXCEPTION 'An unapproved or blank subject category remains.';
    END IF;
END;
$freeze_preflight$;

ALTER TABLE public.qualification_levels
    DROP CONSTRAINT IF EXISTS chk_qualification_levels_frozen_code;
ALTER TABLE public.qualification_levels
    ADD CONSTRAINT chk_qualification_levels_frozen_code CHECK (
        code IN (
            'licentiate', 'associate', 'fellowship', 'spl_diploma',
            'surveyor', 'direct_broker', 'reinsurance_broker',
            'composite_broker'
        )
    );

ALTER TABLE public.training_programmes
    DROP CONSTRAINT IF EXISTS chk_training_programmes_frozen_code;
ALTER TABLE public.training_programmes
    ADD CONSTRAINT chk_training_programmes_frozen_code CHECK (
        code IN (
            'iii_licentiate', 'iii_associate', 'iii_fellowship',
            'iii_spl_diploma', 'iii_surveyor',
            'nia_direct_general_health', 'nia_reinsurance_broker',
            'nia_composite_broker'
        )
    );

ALTER TABLE public.training_programmes
    DROP CONSTRAINT IF EXISTS chk_training_programmes_frozen_category;
ALTER TABLE public.training_programmes
    ADD CONSTRAINT chk_training_programmes_frozen_category CHECK (
        programme_category IN (
            'professional_qualification',
            'broker_exam',
            'surveyor_exam',
            'specialized_diploma_exam'
        )
    );

ALTER TABLE public.programme_sections
    DROP CONSTRAINT IF EXISTS chk_programme_sections_frozen_code;
ALTER TABLE public.programme_sections
    ADD CONSTRAINT chk_programme_sections_frozen_code CHECK (
        code IN (
            'compulsory',
            'compulsory_optional',
            'optional_credit',
            'general_insurance',
            'life_insurance',
            'reinsurance',
            'broker',
            'surveyor',
            'spl_diploma'
        )
    );

ALTER TABLE public.subjects
    DROP CONSTRAINT IF EXISTS chk_subjects_frozen_category,
    DROP CONSTRAINT IF EXISTS chk_subjects_valid_category;
ALTER TABLE public.subjects
    ADD CONSTRAINT chk_subjects_valid_category CHECK (
        category IS NOT NULL
        AND category = pg_catalog.btrim(category)
        AND pg_catalog.char_length(category) BETWEEN 2 AND 120
    );
