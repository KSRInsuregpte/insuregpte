-- IC11 IC11-C02: three flashcards for each active topic.
WITH content_seed (topic_code, learning_focus, study_method, exam_focus) AS (
VALUES
('IC11-C02-T01', 'market evolution; public and private insurers; specialised participants; regulatory structure; market segmentation', 'Build a timeline, then group institutions by the insurance function they perform.', 'Explain the market structure and distinguish insurer, regulator and specialised institution.'),
('IC11-C02-T02', 'general insurers; standalone health insurers; reinsurers; agriculture insurance; export credit; government insurance arrangements', 'Compare each institution by ownership, customer, risk class and source of capacity.', 'Match an institution to its principal purpose and identify when specialist capacity is needed.'),
('IC11-C02-T03', 'agents; corporate agents; brokers; third-party administrators; surveyors; loss assessors', 'Use a responsibility matrix covering solicitation, advice, servicing, administration and loss assessment.', 'Distinguish intermediary roles and avoid assigning a regulated function to the wrong participant.'),
('IC11-C02-T04', 'international insurance centres; Lloyd''s market; global insurers; reinsurers; cross-border capacity; complex risks', 'Trace a large risk from the Indian insured through local placement to international capacity.', 'Explain why international insurance and reinsurance markets support large or specialised risks.')
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
 AND topic_record.chapter_id = 11
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
