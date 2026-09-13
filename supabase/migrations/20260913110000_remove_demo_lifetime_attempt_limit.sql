-- Remove the lifetime demo-attempt cap.
-- The five-minute cooldown remains enforced by 20260913100000.

UPDATE public.quiz_mode_config
SET maximum_attempts = 2147483647
WHERE test_mode = 'demo';

COMMENT ON COLUMN public.quiz_mode_config.maximum_attempts IS
    'Maximum attempts for the mode. Demo uses the integer ceiling and is governed by its cooldown policy.';
