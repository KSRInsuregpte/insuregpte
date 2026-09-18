-- IC11 Chapter 1 flashcards for IC11-C01-T04; three active flashcards expected.
WITH flashcard_seed (
    topic_code, code, question, answer, explanation, display_order,
    difficulty_level
) AS (
VALUES
('IC11-C01-T04', 'FC-IC11-C01-T04-001', 'What facts are central to a foreign-exchange review of an insurance transaction?',
 'The parties and their residence, location of risk, currency, payment destination, insurable interest and supporting authority.',
 'These facts determine which exchange-control route, documents or approvals may apply.', 1, 'intermediate'),
('IC11-C01-T04', 'FC-IC11-C01-T04-002', 'Why may a multinational insurance programme still require local policies?',
 'Local compulsory insurance, licensing, tax, exchange-control or policy-issuance rules may apply where the risk is located.',
 'A global arrangement does not automatically displace mandatory local law.', 2, 'advanced'),
('IC11-C01-T04', 'FC-IC11-C01-T04-003', 'Name four non-insurance legal areas that can affect general insurance.',
 'Contract, taxation, foreign exchange and limitation law are examples; company, evidence, sanctions, data and transport laws may also apply.',
 'Insurance professionals must recognise connected legal regimes and escalate specialist questions.', 3, 'intermediate')
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
