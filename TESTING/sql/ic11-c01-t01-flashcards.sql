-- IC11 Chapter 1 flashcards for IC11-C01-T01; three active flashcards expected.
WITH flashcard_seed (
    topic_code, code, question, answer, explanation, display_order,
    difficulty_level
) AS (
VALUES
('IC11-C01-T01', 'FC-IC11-C01-T01-001', 'Why does insurance require special regulation?',
 'Premium is received before the uncertain future cost of claims is known, so supervision protects financial soundness, fair treatment and confidence in the promise to pay.',
 'The time gap and information imbalance distinguish insurance from an ordinary immediate exchange.', 1, 'foundation'),
('IC11-C01-T01', 'FC-IC11-C01-T01-002', 'What is the difference between primary legislation and an insurance regulation?',
 'Primary legislation establishes powers and mandatory duties; a regulation supplies detailed rules under authority granted by that legislation.',
 'The regulation must remain within the enabling statute and cannot override it.', 2, 'foundation'),
('IC11-C01-T01', 'FC-IC11-C01-T01-003', 'Can a policy condition override a mandatory statute?',
 'No. Contractual wording operates subject to mandatory law.',
 'The policy defines agreed cover, but parties cannot contract out of a legal rule that is compulsory.', 3, 'foundation')
)
INSERT INTO public.flashcards (
    subject_id, module_id, chapter_id, topic_id, code, question, answer,
    explanation, display_order, difficulty_level, is_exam_relevant, is_active
)
SELECT
    topic_record.subject_id, topic_record.module_id, topic_record.chapter_id,
    topic_record.id, seed.code, seed.question, seed.answer,
    seed.explanation, seed.display_order, seed.difficulty_level, true, true
FROM flashcard_seed AS seed
JOIN public.subject_topics AS topic_record
  ON topic_record.subject_id = 2
 AND topic_record.chapter_id = 10
 AND topic_record.code = seed.topic_code
 AND topic_record.is_active = true
WHERE NOT EXISTS (
    SELECT 1
    FROM public.flashcards AS existing
    WHERE pg_catalog.upper(existing.code) = pg_catalog.upper(seed.code)
)
RETURNING code, topic_id, display_order, difficulty_level, is_active;
