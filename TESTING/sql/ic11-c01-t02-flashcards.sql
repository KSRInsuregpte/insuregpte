-- IC11 Chapter 1 flashcards for IC11-C01-T02; three active flashcards expected.
WITH flashcard_seed (
    topic_code, code, question, answer, explanation, display_order,
    difficulty_level
) AS (
VALUES
('IC11-C01-T02', 'FC-IC11-C01-T02-001', 'Why is incorporation not enough to carry on insurance business?',
 'Insurance business also requires the registration or authority prescribed by insurance law.',
 'The regulator assesses financial, governance and operational fitness before and during business.', 1, 'foundation'),
('IC11-C01-T02', 'FC-IC11-C01-T02-002', 'How can under-reserving affect an insurer?',
 'It can overstate current profit and leave insufficient funds for future claims, weakening solvency.',
 'Insurance costs are delayed and uncertain, so prudent estimates are essential.', 2, 'intermediate'),
('IC11-C01-T02', 'FC-IC11-C01-T02-003', 'What is the difference between registration and continuing supervision?',
 'Registration permits market entry; continuing supervision monitors whether the insurer remains compliant and financially sound.',
 'Authority is not a once-only exercise because liabilities and business practices change over time.', 3, 'intermediate')
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
