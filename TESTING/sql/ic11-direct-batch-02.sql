-- Direct IC11 topic insertion, batch 02 of 06.
-- IC11 subject_id=2; module IDs 5-9; chapter IDs 10-18.
-- IC11-C01-T01 is intentionally excluded because it was inserted successfully first.

INSERT INTO public.subject_topics (
    subject_id, module_id, chapter_id, topic_number, code, title,
    description, learning_objective, practical_relevance,
    estimated_study_minutes, difficulty_level, display_order,
    is_exam_relevant, is_active, created_at, updated_at
)
VALUES
(2, 6, 12, 1, 'IC11-C03-T01', 'Insurance Contract and Policy Structure', 'Contract formation, insurance principles and the principal components of a policy document.', 'Identify the elements of an insurance contract and explain the function of each policy component.', 'Supports accurate policy preparation, servicing and evaluation of contractual obligations.', 40, 'foundation', 1, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 6, 12, 2, 'IC11-C03-T02', 'Proposal Forms and Material Information', 'Proposal forms, material facts, disclosure, declarations and the use of underwriting information.', 'Explain how proposal information forms the basis of underwriting and contractual disclosure.', 'Helps prevent coverage disputes arising from incomplete or inaccurate risk information.', 35, 'intermediate', 2, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 6, 12, 3, 'IC11-C03-T03', 'Cover Notes, Certificates and Endorsements', 'Interim cover notes, statutory certificates, policy schedules and endorsements used during a policy lifecycle.', 'Distinguish the purpose and legal effect of common insurance documents and amendments.', 'Enables practitioners to select and issue the correct evidence of cover or policy change.', 35, 'foundation', 3, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 6, 12, 4, 'IC11-C03-T04', 'Policy Interpretation, Co-insurance and Documentation', 'Rules of policy interpretation, warranties, conditions, exceptions, co-insurance and document control.', 'Apply a structured approach to interpreting policy wording and documenting shared insurance arrangements.', 'Improves consistency when explaining cover, allocating participation and resolving wording questions.', 40, 'intermediate', 4, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 6, 13, 1, 'IC11-C04-T01', 'Standard Fire and Special Perils Coverage', 'Property interests, insured perils, exclusions, sums insured and the structure of fire insurance coverage.', 'Explain the operative cover and principal limitations of standard fire and special-perils insurance.', 'Supports suitable property placement and accurate first-stage analysis of fire losses.', 45, 'intermediate', 1, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 6, 13, 2, 'IC11-C04-T02', 'Fire Policy Extensions and Special Policies', 'Extensions, add-on covers, special declarations and policies designed for particular property exposures.', 'Select policy adaptations that address risk characteristics not met by basic fire cover.', 'Helps align property protection with occupancy, values, stock patterns and catastrophe exposure.', 40, 'intermediate', 2, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 6, 13, 3, 'IC11-C04-T03', 'Consequential Loss Following Fire', 'Business interruption, gross profit, indemnity period, standing charges and increased cost of working.', 'Explain how consequential-loss insurance responds to financial interruption after insured damage.', 'Supports coordinated property and interruption cover that protects business continuity.', 45, 'intermediate', 3, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp())
ON CONFLICT (subject_id, code)
DO UPDATE SET
    module_id = EXCLUDED.module_id,
    chapter_id = EXCLUDED.chapter_id,
    topic_number = EXCLUDED.topic_number,
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    learning_objective = EXCLUDED.learning_objective,
    practical_relevance = EXCLUDED.practical_relevance,
    estimated_study_minutes = EXCLUDED.estimated_study_minutes,
    difficulty_level = EXCLUDED.difficulty_level,
    display_order = EXCLUDED.display_order,
    is_exam_relevant = EXCLUDED.is_exam_relevant,
    is_active = EXCLUDED.is_active,
    updated_at = pg_catalog.clock_timestamp()
RETURNING code, chapter_id, topic_number, is_active;
