-- Read-only question-quality audit.
-- Review the result sets before changing any question-bank records.

WITH normalized_questions AS (
    SELECT
        question_record.id,
        question_record.subject_id,
        subject_record.code AS subject_code,
        subject_record.title AS subject_title,
        question_record.question_text,
        NULLIF(pg_catalog.btrim(question_record.question_text), '') AS question_text_trimmed,
        NULLIF(pg_catalog.btrim(question_record.option_a), '') AS option_a,
        NULLIF(pg_catalog.btrim(question_record.option_b), '') AS option_b,
        NULLIF(pg_catalog.btrim(question_record.option_c), '') AS option_c,
        NULLIF(pg_catalog.btrim(question_record.option_d), '') AS option_d,
        NULLIF(pg_catalog.btrim(question_record.correct_option), '') AS correct_option,
        NULLIF(pg_catalog.btrim(question_record.explanation), '') AS explanation,
        question_record.difficulty_level,
        question_record.is_active
    FROM public.questions AS question_record
    JOIN public.subjects AS subject_record
      ON subject_record.id = question_record.subject_id
    WHERE question_record.is_active = true
),
normalized_values AS (
    SELECT
        normalized_questions.*,
        lower(option_a) AS option_a_key,
        lower(option_b) AS option_b_key,
        lower(option_c) AS option_c_key,
        lower(option_d) AS option_d_key,
        lower(correct_option) AS correct_option_key,
        lower(question_text_trimmed) AS question_text_key
    FROM normalized_questions
)
SELECT
    subject_code,
    COUNT(*) AS active_question_count,
    COUNT(*) FILTER (
        WHERE question_text_trimmed IS NULL
           OR option_a IS NULL
           OR option_b IS NULL
           OR option_c IS NULL
           OR option_d IS NULL
           OR correct_option IS NULL
           OR explanation IS NULL
    ) AS incomplete_rows,
    COUNT(*) FILTER (
        WHERE correct_option_key NOT IN (
            option_a_key, option_b_key, option_c_key, option_d_key
        )
    ) AS invalid_correct_answer_rows,
    COUNT(*) FILTER (
        WHERE option_a_key IN (option_b_key, option_c_key, option_d_key)
           OR option_b_key IN (option_c_key, option_d_key)
           OR option_c_key = option_d_key
    ) AS duplicate_option_rows,
    COUNT(*) FILTER (
        WHERE GREATEST(
            length(option_a), length(option_b), length(option_c), length(option_d)
        ) - LEAST(
            length(option_a), length(option_b), length(option_c), length(option_d)
        ) > 120
    ) AS high_option_length_spread_rows,
    COUNT(*) FILTER (WHERE correct_option_key = option_a_key) AS correct_a,
    COUNT(*) FILTER (WHERE correct_option_key = option_b_key) AS correct_b,
    COUNT(*) FILTER (WHERE correct_option_key = option_c_key) AS correct_c,
    COUNT(*) FILTER (WHERE correct_option_key = option_d_key) AS correct_d
FROM normalized_values
GROUP BY subject_code
ORDER BY subject_code;

-- Flag answer-length bias. A correct answer that is materially longer than
-- every distractor can reveal the answer without understanding the question.
WITH normalized_questions AS (
    SELECT
        question_record.id,
        subject_record.code AS subject_code,
        NULLIF(pg_catalog.btrim(question_record.option_a), '') AS option_a,
        NULLIF(pg_catalog.btrim(question_record.option_b), '') AS option_b,
        NULLIF(pg_catalog.btrim(question_record.option_c), '') AS option_c,
        NULLIF(pg_catalog.btrim(question_record.option_d), '') AS option_d,
        lower(NULLIF(pg_catalog.btrim(question_record.option_a), '')) AS option_a_key,
        lower(NULLIF(pg_catalog.btrim(question_record.option_b), '')) AS option_b_key,
        lower(NULLIF(pg_catalog.btrim(question_record.option_c), '')) AS option_c_key,
        lower(NULLIF(pg_catalog.btrim(question_record.option_d), '')) AS option_d_key,
        lower(NULLIF(pg_catalog.btrim(question_record.correct_option), '')) AS correct_option_key
    FROM public.questions AS question_record
    JOIN public.subjects AS subject_record
      ON subject_record.id = question_record.subject_id
    WHERE question_record.is_active = true
),
resolved_answers AS (
    SELECT
        normalized_questions.*,
        CASE
            WHEN correct_option_key = option_a_key THEN 'A'
            WHEN correct_option_key = option_b_key THEN 'B'
            WHEN correct_option_key = option_c_key THEN 'C'
            WHEN correct_option_key = option_d_key THEN 'D'
            ELSE NULL
        END AS correct_position,
        CASE
            WHEN correct_option_key = option_a_key THEN option_a
            WHEN correct_option_key = option_b_key THEN option_b
            WHEN correct_option_key = option_c_key THEN option_c
            WHEN correct_option_key = option_d_key THEN option_d
            ELSE NULL
        END AS correct_answer_text
    FROM normalized_questions
),
length_statistics AS (
    SELECT
        resolved_answers.*,
        length(correct_answer_text) AS correct_answer_length,
        CASE correct_position
            WHEN 'A' THEN greatest(length(option_b), length(option_c), length(option_d))
            WHEN 'B' THEN greatest(length(option_a), length(option_c), length(option_d))
            WHEN 'C' THEN greatest(length(option_a), length(option_b), length(option_d))
            WHEN 'D' THEN greatest(length(option_a), length(option_b), length(option_c))
        END AS longest_distractor_length,
        CASE correct_position
            WHEN 'A' THEN (length(option_b) + length(option_c) + length(option_d)) / 3.0
            WHEN 'B' THEN (length(option_a) + length(option_c) + length(option_d)) / 3.0
            WHEN 'C' THEN (length(option_a) + length(option_b) + length(option_d)) / 3.0
            WHEN 'D' THEN (length(option_a) + length(option_b) + length(option_c)) / 3.0
        END AS average_distractor_length
    FROM resolved_answers
)
SELECT
    id,
    subject_code,
    correct_position,
    correct_answer_length,
    longest_distractor_length,
    round(average_distractor_length, 1) AS average_distractor_length,
    correct_answer_length - longest_distractor_length AS excess_over_longest_distractor,
    round(
        correct_answer_length::numeric
        / NULLIF(average_distractor_length, 0),
        2
    ) AS correct_to_distractor_length_ratio,
    correct_answer_text
FROM length_statistics
WHERE correct_position IS NOT NULL
  AND (
      correct_answer_length > longest_distractor_length + 20
      OR correct_answer_length > average_distractor_length * 1.35
  )
ORDER BY subject_code, id;

-- Detailed rows requiring content review.
WITH normalized_questions AS (
    SELECT
        question_record.id,
        subject_record.code AS subject_code,
        question_record.question_text,
        NULLIF(pg_catalog.btrim(question_record.question_text), '') AS question_text_trimmed,
        NULLIF(pg_catalog.btrim(question_record.option_a), '') AS option_a,
        NULLIF(pg_catalog.btrim(question_record.option_b), '') AS option_b,
        NULLIF(pg_catalog.btrim(question_record.option_c), '') AS option_c,
        NULLIF(pg_catalog.btrim(question_record.option_d), '') AS option_d,
        NULLIF(pg_catalog.btrim(question_record.correct_option), '') AS correct_option,
        NULLIF(pg_catalog.btrim(question_record.explanation), '') AS explanation
    FROM public.questions AS question_record
    JOIN public.subjects AS subject_record
      ON subject_record.id = question_record.subject_id
    WHERE question_record.is_active = true
),
normalized_values AS (
    SELECT
        normalized_questions.*,
        lower(option_a) AS option_a_key,
        lower(option_b) AS option_b_key,
        lower(option_c) AS option_c_key,
        lower(option_d) AS option_d_key,
        lower(correct_option) AS correct_option_key
    FROM normalized_questions
)
SELECT
    id,
    subject_code,
    left(question_text, 140) AS question_preview,
    CASE
        WHEN question_text_trimmed IS NULL THEN 'missing question text'
        WHEN option_a IS NULL OR option_b IS NULL
          OR option_c IS NULL OR option_d IS NULL THEN 'missing option'
        WHEN correct_option_key NOT IN (
            option_a_key, option_b_key, option_c_key, option_d_key
        ) THEN 'correct answer does not match an option'
        WHEN option_a_key IN (option_b_key, option_c_key, option_d_key)
          OR option_b_key IN (option_c_key, option_d_key)
          OR option_c_key = option_d_key THEN 'duplicate option'
        WHEN explanation IS NULL THEN 'missing explanation'
        WHEN GREATEST(
            length(option_a), length(option_b), length(option_c), length(option_d)
        ) - LEAST(
            length(option_a), length(option_b), length(option_c), length(option_d)
        ) > 120 THEN 'large option-length spread'
        ELSE 'review'
    END AS review_reason
FROM normalized_values
WHERE question_text_trimmed IS NULL
   OR option_a IS NULL OR option_b IS NULL
   OR option_c IS NULL OR option_d IS NULL
   OR correct_option_key NOT IN (
        option_a_key, option_b_key, option_c_key, option_d_key
   )
   OR option_a_key IN (option_b_key, option_c_key, option_d_key)
   OR option_b_key IN (option_c_key, option_d_key)
   OR option_c_key = option_d_key
   OR explanation IS NULL
   OR GREATEST(
        length(option_a), length(option_b), length(option_c), length(option_d)
      ) - LEAST(
        length(option_a), length(option_b), length(option_c), length(option_d)
      ) > 120
ORDER BY subject_code, id;

-- Exact duplicate question text within a subject.
SELECT
    subject_record.code AS subject_code,
    lower(pg_catalog.btrim(question_record.question_text)) AS normalized_question,
    COUNT(*) AS duplicate_count,
    array_agg(question_record.id ORDER BY question_record.id) AS question_ids
FROM public.questions AS question_record
JOIN public.subjects AS subject_record
  ON subject_record.id = question_record.subject_id
WHERE question_record.is_active = true
GROUP BY subject_record.code, lower(pg_catalog.btrim(question_record.question_text))
HAVING COUNT(*) > 1
ORDER BY subject_code, normalized_question;

-- Manual semantic review list. SQL can flag structural problems, but a
-- subject-matter reviewer must judge whether distractors are closely related
-- to the question and definitively wrong.
SELECT
    question_record.id,
    subject_record.code AS subject_code,
    question_record.question_text,
    question_record.option_a,
    question_record.option_b,
    question_record.option_c,
    question_record.option_d,
    question_record.correct_option,
    question_record.explanation,
    question_record.difficulty_level,
    question_record.is_active
FROM public.questions AS question_record
JOIN public.subjects AS subject_record
  ON subject_record.id = question_record.subject_id
WHERE question_record.is_active = true
ORDER BY subject_record.code, question_record.id;
