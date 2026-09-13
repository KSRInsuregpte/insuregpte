-- Read-only audit for the 30 active advanced demo questions in IC01, IC11,
-- and IC14. It identifies answer-position skew, duplicate options, and
-- unusually imbalanced option lengths before any content is changed.

WITH demo_questions AS (
    SELECT
        q.id,
        s.code AS subject_code,
        q.correct_option,
        q.option_a,
        q.option_b,
        q.option_c,
        q.option_d,
        q.question_text
    FROM public.questions AS q
    JOIN public.subjects AS s ON s.id = q.subject_id
    WHERE s.code IN ('IC01', 'IC11', 'IC14')
      AND q.is_active = true
      AND q.difficulty_level = 'advanced'
)
SELECT
    subject_code,
    COUNT(*) AS question_count,
    COUNT(*) FILTER (WHERE correct_option = option_a) AS correct_a,
    COUNT(*) FILTER (WHERE correct_option = option_b) AS correct_b,
    COUNT(*) FILTER (WHERE correct_option = option_c) AS correct_c,
    COUNT(*) FILTER (WHERE correct_option = option_d) AS correct_d,
    COUNT(*) FILTER (
        WHERE option_a IN (option_b, option_c, option_d)
           OR option_b IN (option_c, option_d)
           OR option_c = option_d
    ) AS duplicate_option_rows
FROM demo_questions
GROUP BY subject_code
ORDER BY subject_code;

WITH demo_questions AS (
    SELECT
        q.id,
        s.code AS subject_code,
        q.correct_option,
        q.option_a,
        q.option_b,
        q.option_c,
        q.option_d,
        q.question_text
    FROM public.questions AS q
    JOIN public.subjects AS s ON s.id = q.subject_id
    WHERE s.code IN ('IC01', 'IC11', 'IC14')
      AND q.is_active = true
      AND q.difficulty_level = 'advanced'
)
SELECT
    id,
    subject_code,
    LEFT(question_text, 100) AS question_preview,
    correct_option,
    LENGTH(option_a) AS option_a_length,
    LENGTH(option_b) AS option_b_length,
    LENGTH(option_c) AS option_c_length,
    LENGTH(option_d) AS option_d_length,
    GREATEST(
        LENGTH(option_a), LENGTH(option_b), LENGTH(option_c), LENGTH(option_d)
    ) - LEAST(
        LENGTH(option_a), LENGTH(option_b), LENGTH(option_c), LENGTH(option_d)
    ) AS option_length_spread
FROM demo_questions
WHERE option_a IN (option_b, option_c, option_d)
   OR option_b IN (option_c, option_d)
   OR option_c = option_d
   OR GREATEST(
        LENGTH(option_a), LENGTH(option_b), LENGTH(option_c), LENGTH(option_d)
      ) - LEAST(
        LENGTH(option_a), LENGTH(option_b), LENGTH(option_c), LENGTH(option_d)
      ) > 120
ORDER BY subject_code, id;
