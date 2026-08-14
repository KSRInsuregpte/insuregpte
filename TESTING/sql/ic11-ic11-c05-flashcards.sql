-- IC11 IC11-C05: three flashcards for each active topic.
WITH content_seed (topic_code, learning_focus, study_method, exam_focus) AS (
VALUES
('IC11-C05-T01', 'vehicle classification; compulsory third-party liability; own damage; package cover; rating; motor claims', 'Separate statutory liability, vehicle damage and personal benefits before reviewing policy response.', 'Distinguish compulsory and optional motor protection and outline the motor claim process.'),
('IC11-C05-T02', 'public liability; product liability; employer liability; professional negligence; claims-made cover; limits', 'Identify the duty, alleged breach, claimant, injury or damage, and the policy trigger.', 'Match common liability exposures with suitable cover and distinguish occurrence from claims-made features.'),
('IC11-C05-T03', 'accidental death; disability; medical expenses; hospitalisation; waiting periods; exclusions; benefit and indemnity', 'Compare the insured event, benefit basis and evidence required under accident and health policies.', 'Distinguish fixed benefits from indemnity and identify common coverage limitations.'),
('IC11-C05-T04', 'forcible entry; money in transit; baggage; employee dishonesty; discovery; limits; security protections', 'Classify the property and cause of loss before selecting burglary, money, baggage or fidelity cover.', 'Distinguish theft-related policies by insured interest, event and responsible person.'),
('IC11-C05-T05', 'aviation hull and liability; rural exposures; crop and livestock; micro-insurance; accessibility; affordability', 'Compare specialist technical risk with inclusive products designed for underserved customers.', 'Explain the broad purpose of aviation, rural and micro-insurance and their differing design needs.')
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
 AND topic_record.chapter_id = 14
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
