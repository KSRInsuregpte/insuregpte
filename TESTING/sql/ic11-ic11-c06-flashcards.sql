-- IC11 IC11-C06: three flashcards for each active topic.
WITH content_seed (topic_code, learning_focus, study_method, exam_focus) AS (
VALUES
('IC11-C06-T01', 'construction works; erection; storage; testing; commissioning; third-party liability; project value; policy period', 'Build a project timeline and mark when each cover attaches, changes and expires.', 'Compare contractors-all-risks and erection-all-risks policies and their testing exposure.'),
('IC11-C06-T02', 'machinery breakdown; boiler explosion; pressure plant; electrical damage; electronic equipment; restoration', 'Identify the equipment, internal failure mechanism, external peril and resulting financial consequence.', 'Select the engineering policy that corresponds to machinery, pressure plant or electronic equipment.'),
('IC11-C06-T03', 'industrial all risks; broad property cover; exclusions; project delay; advance loss of profits; critical path', 'Coordinate the material-damage trigger with the financial effect of delayed commercial operation.', 'Explain how industrial-all-risks and advance-loss-of-profits protection work together.'),
('IC11-C06-T04', 'oil and gas; energy; offshore operations; satellite; accumulation; technical surveys; specialist wording; market capacity', 'Break a complex risk into physical assets, operations, liabilities, interruption and catastrophe accumulation.', 'Explain why specialised risks need technical underwriting, tailored wording and shared capacity.')
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
 AND topic_record.chapter_id = 15
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
