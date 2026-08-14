-- IC11 IC11-C09: three flashcards for each active topic.
WITH content_seed (topic_code, learning_focus, study_method, exam_focus) AS (
VALUES
('IC11-C09-T01', 'delayed claim cost; technical provisions; outstanding claims; IBNR; unexpired risk; fluctuation; solvency', 'Relate each reserve to the future obligation it is intended to finance.', 'Explain why technical reserves are liabilities and identify their principal types.'),
('IC11-C09-T02', 'case estimates; incurred but not reported claims; development; reopened claims; data triangles; uncertainty', 'Separate known reported claims from losses incurred but not yet visible in individual files.', 'Distinguish outstanding case reserves from IBNR and explain reserve development.'),
('IC11-C09-T03', 'written premium; earned premium; unearned premium; remaining coverage; unexpired-risk deficiency; matching', 'Use a policy timeline to separate the expired and unexpired portions of risk.', 'Explain why premium relating to future coverage cannot be treated wholly as current income.'),
('IC11-C09-T04', 'security; liquidity; yield; diversification; admissible assets; matching; concentration; regulatory limits', 'Evaluate an investment by its ability to support the timing and uncertainty of claim payments.', 'Explain the balance between safety, liquidity and return in insurer investment strategy.'),
('IC11-C09-T05', 'underwriting account; profit and loss; balance sheet; cash flow; claims ratio; combined ratio; solvency; management returns', 'Connect operational insurance data to financial statements and management indicators.', 'Interpret the principal reports and ratios used to monitor general insurance performance.')
)
INSERT INTO public.flashcards (
    subject_id, module_id, chapter_id, topic_id, code, question, answer,
    explanation, display_order, difficulty_level, is_exam_relevant, is_active
)
SELECT
    topic_record.subject_id, topic_record.module_id, topic_record.chapter_id,
    topic_record.id,
    'FC-' || seed.topic_code || '-' || pg_catalog.lpad(card.card_number::text, 3, '0'),
    card.question, card.answer, card.explanation, card.card_number,
    CASE WHEN card.card_number = 1 THEN 'foundation' ELSE topic_record.difficulty_level END,
    true, true
FROM content_seed AS seed
JOIN public.subject_topics AS topic_record
  ON topic_record.subject_id = 2
 AND topic_record.chapter_id = 18
 AND pg_catalog.upper(topic_record.code) = seed.topic_code
 AND topic_record.is_active = true
CROSS JOIN LATERAL (
    VALUES
      (1, 'What is the central scope of ' || topic_record.title || '?', topic_record.description,
          'A complete answer identifies the subject, its purpose and the connected elements: ' || seed.learning_focus || '.'),
      (2, 'What should a learner be able to do after studying ' || topic_record.title || '?', topic_record.learning_objective,
          'Use this objective to structure comparison and application questions. ' || seed.study_method),
      (3, 'Why is ' || topic_record.title || ' practically relevant?', topic_record.practical_relevance,
          seed.exam_focus || ' Verify any time-sensitive rule against a current official source.')
) AS card(card_number, question, answer, explanation)
WHERE NOT EXISTS (
    SELECT 1
    FROM public.flashcards AS existing
    WHERE pg_catalog.upper(existing.code) =
      'FC-' || seed.topic_code || '-' || pg_catalog.lpad(card.card_number::text, 3, '0')
)
RETURNING code, topic_id, display_order, difficulty_level, is_active;
