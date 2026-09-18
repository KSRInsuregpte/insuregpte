-- Verify the demo answer-position rebalance and scoring-text integrity.
WITH demo_questions AS (
    SELECT
        q.id,
        s.code AS subject_code,
        q.correct_option,
        q.option_a,
        q.option_b,
        q.option_c,
        q.option_d
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
    ) AS duplicate_option_rows,
    COUNT(*) FILTER (
        WHERE correct_option NOT IN (option_a, option_b, option_c, option_d)
    ) AS invalid_correct_answer_rows
FROM demo_questions
GROUP BY subject_code
ORDER BY subject_code;
