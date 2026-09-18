-- IC11 IC11-C08: three flashcards for each active topic.
WITH content_seed (topic_code, learning_focus, study_method, exam_focus) AS (
VALUES
('IC11-C08-T01', 'prompt notice; emergency response; mitigation; evidence preservation; claim registration; communication', 'Use a first-notice checklist covering safety, mitigation, facts, documents and immediate support.', 'Explain why early notification and loss minimisation protect both insured and insurer.'),
('IC11-C08-T02', 'proximate cause; policy period; insured peril; exclusion; legal liability; investigation; fraud indicators', 'Build a fact chronology, then apply policy coverage and legal liability in separate stages.', 'Apply a structured coverage investigation without assuming that reported loss equals insured loss.'),
('IC11-C08-T03', 'surveyor; specialist; proof of loss; valuation; invoices; repair estimates; underinsurance; quantum', 'Create an evidence schedule linking each claimed amount to documents and policy valuation rules.', 'Explain the role of survey and how evidence supports a defensible loss assessment.'),
('IC11-C08-T04', 'case reserve; reserve revision; policy excess; depreciation; average; authority; payment; discharge', 'Reconcile assessed loss, policy adjustments, approvals and payment documentation.', 'Explain why reserves change and distinguish assessment from final settlement.'),
('IC11-C08-T05', 'coverage dispute; quantum dispute; arbitration; litigation; limitation; without-prejudice negotiation; evidence', 'Classify the dispute before choosing the contractual, judicial or negotiated resolution route.', 'Distinguish arbitration of quantum from disputes about policy liability.'),
('IC11-C08-T06', 'salvage; subrogation; contribution; third-party recovery; disposal; recovery costs; closure review', 'Protect physical salvage and legal rights from first notification through post-payment recovery.', 'Explain how salvage, subrogation and contribution reduce net claim cost.')
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
 AND topic_record.chapter_id = 17
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
