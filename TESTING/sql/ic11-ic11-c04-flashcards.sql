-- IC11 IC11-C04: three flashcards for each active topic.
WITH content_seed (topic_code, learning_focus, study_method, exam_focus) AS (
VALUES
('IC11-C04-T01', 'insured property; insured perils; exclusions; sum insured; average; deductible; indemnity', 'Map the insured property against the operative perils and then test every applicable limitation.', 'Explain the structure of standard fire cover and the effect of underinsurance.'),
('IC11-C04-T02', 'extensions; add-on covers; declarations; floater arrangements; reinstatement value; special policies', 'Start with the basic gap and select the extension or policy structure that addresses it.', 'Choose an appropriate adaptation for changing stock, multiple locations or special valuation needs.'),
('IC11-C04-T03', 'material damage proviso; gross profit; standing charges; increased cost of working; indemnity period; trends', 'Follow a loss from physical damage through interruption, recovery time and financial calculation.', 'Distinguish material damage from consequential loss and explain the importance of the indemnity period.'),
('IC11-C04-T04', 'cargo interest; transit; Institute Cargo Clauses; valuation; insurable interest; documents; recovery rights', 'Trace goods from origin to destination and identify when risk, title and insurance responsibility change.', 'Compare levels of cargo cover and identify the documents needed for a transit claim.'),
('IC11-C04-T05', 'hull interest; maritime perils; time and voyage policies; valued policies; collision liability; total loss', 'Classify the marine interest first, then select the policy form and relevant maritime risks.', 'Distinguish hull from cargo insurance and compare time, voyage and valued arrangements.')
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
 AND topic_record.chapter_id = 13
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
