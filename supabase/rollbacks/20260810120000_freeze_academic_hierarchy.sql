-- Safe rollback: remove the frozen vocabulary constraints while preserving
-- all normalized hierarchy data and the lossless Life-to-Direct consolidation.

ALTER TABLE public.subjects
    DROP CONSTRAINT IF EXISTS chk_subjects_frozen_category,
    DROP CONSTRAINT IF EXISTS chk_subjects_valid_category;
ALTER TABLE public.programme_sections
    DROP CONSTRAINT IF EXISTS chk_programme_sections_frozen_code;
ALTER TABLE public.training_programmes
    DROP CONSTRAINT IF EXISTS chk_training_programmes_frozen_category;
ALTER TABLE public.training_programmes
    DROP CONSTRAINT IF EXISTS chk_training_programmes_frozen_code;
ALTER TABLE public.qualification_levels
    DROP CONSTRAINT IF EXISTS chk_qualification_levels_frozen_code;

-- The former NIA Life Broker programme is intentionally not recreated.
-- Its linked records were consolidated into Direct Broker, and reversing that
-- relationship automatically would risk assigning shared records incorrectly.
