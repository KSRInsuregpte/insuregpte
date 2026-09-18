-- IC11 Chapter 1 flashcards for IC11-C01-T03; three active flashcards expected.
WITH flashcard_seed (
    topic_code, code, question, answer, explanation, display_order,
    difficulty_level
) AS (
VALUES
('IC11-C01-T03', 'FC-IC11-C01-T03-001', 'How does compulsory motor third-party cover differ from own-damage cover?',
 'Third-party cover protects against specified legal liability to others and is compulsory; own-damage cover protects the insured vehicle and is generally optional.',
 'A package policy may contain both, but their purpose and legal basis differ.', 1, 'foundation'),
('IC11-C01-T03', 'FC-IC11-C01-T03-002', 'Does legal liability automatically mean the insurer must pay the full amount?',
 'No. The liability must also fall within the policy grant, period, limits and conditions and not be excluded.',
 'Law creates the underlying duty; the insurance contract defines the insured response.', 2, 'intermediate'),
('IC11-C01-T03', 'FC-IC11-C01-T03-003', 'Why must consumer-forum limits be checked against current official law?',
 'Pecuniary limits, procedures and appeal rules can be amended after a course book is published.',
 'The legal concept remains examinable, but operational advice must use the effective rule.', 3, 'intermediate')
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
