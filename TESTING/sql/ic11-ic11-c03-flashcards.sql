-- IC11 IC11-C03: three flashcards for each active topic.
WITH content_seed (topic_code, learning_focus, study_method, exam_focus) AS (
VALUES
('IC11-C03-T01', 'offer and acceptance; consideration; capacity; legality; utmost good faith; policy components', 'Review a policy from contract formation through operative clause, exclusions, conditions and schedule.', 'Identify the elements of an insurance contract and the function of the main policy sections.'),
('IC11-C03-T02', 'proposal form; material facts; disclosure; declarations; underwriting evidence; consequences of misstatement', 'Separate facts that describe the risk from statements that form contractual declarations.', 'Explain why material information affects acceptance, terms and claim disputes.'),
('IC11-C03-T03', 'cover note; certificate; schedule; endorsement; interim evidence; amendment of cover', 'Arrange the documents in the order they may appear during placement and servicing.', 'Distinguish evidence of temporary cover, statutory certification and a formal policy amendment.'),
('IC11-C03-T04', 'policy interpretation; ordinary meaning; ambiguity; warranties; conditions; exceptions; co-insurance; document control', 'Read the policy as a whole and reconcile the schedule, wording and endorsements before reaching a conclusion.', 'Apply a disciplined interpretation method and explain how co-insurance participation is documented.')
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
 AND topic_record.chapter_id = 12
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
