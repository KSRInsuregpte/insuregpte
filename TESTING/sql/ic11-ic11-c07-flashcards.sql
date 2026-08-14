-- IC11 IC11-C07: three flashcards for each active topic.
WITH content_seed (topic_code, learning_focus, study_method, exam_focus) AS (
VALUES
('IC11-C07-T01', 'underwriting appetite; authority; guidelines; selection; portfolio balance; accumulation; profitability', 'Connect each individual decision to its effect on the insurer''s overall portfolio.', 'Explain how underwriting policy controls risk selection and protects portfolio quality.'),
('IC11-C07-T02', 'proposal information; inspections; classification; physical hazard; moral hazard; morale hazard; exposure measurement', 'Test completeness, reliability and materiality of every item of risk information.', 'Distinguish hazard types and explain how they affect acceptance, terms and premium.'),
('IC11-C07-T03', 'accept; decline; postpone; load premium; deductible; warranty; exclusion; documentation; renewal review', 'Record the reason, authority and evidence for every underwriting decision and policy term.', 'Compare underwriting options and explain why renewal requires fresh exposure review.'),
('IC11-C07-T04', 'co-insurance; lead insurer; following insurers; facultative reinsurance; treaty reinsurance; retention; capacity', 'Follow the contractual relationships and distinguish who contracts with the insured and who reimburses the insurer.', 'Distinguish co-insurance from reinsurance and facultative from treaty protection.'),
('IC11-C07-T05', 'expected claims cost; expenses; commission; catastrophe allowance; investment assumptions; profit; taxes; credibility', 'Build premium from the expected cost of risk and add each required loading transparently.', 'Explain the components of premium and why technically adequate rates matter.'),
('IC11-C07-T06', 'soft market; hard market; capacity; competition; rate adequacy; risk identification; control; financing; monitoring', 'Separate market pressure from the technical merits of the risk and document risk improvements.', 'Explain market-cycle effects and distinguish risk control from risk financing.')
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
 AND topic_record.chapter_id = 16
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
