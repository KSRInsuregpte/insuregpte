-- Direct IC11 topic insertion, batch 04 of 06.
-- IC11 subject_id=2; module IDs 5-9; chapter IDs 10-18.
-- IC11-C01-T01 is intentionally excluded because it was inserted successfully first.

INSERT INTO public.subject_topics (
    subject_id, module_id, chapter_id, topic_number, code, title,
    description, learning_objective, practical_relevance,
    estimated_study_minutes, difficulty_level, display_order,
    is_exam_relevant, is_active, created_at, updated_at
)
VALUES
(2, 6, 15, 1, 'IC11-C06-T01', 'Contractors and Erection All Risks Insurance', 'Construction, erection, testing, third-party liability, values and policy-period considerations.', 'Compare contractors-all-risks and erection-all-risks cover across project stages.', 'Supports correct project-policy selection and control of construction and installation exposures.', 45, 'intermediate', 1, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 6, 15, 2, 'IC11-C06-T02', 'Machinery, Boiler and Electronic Equipment Insurance', 'Breakdown, explosion, electrical and electronic equipment risks and the related engineering policies.', 'Distinguish the principal engineering covers for machinery, pressure plant and electronic equipment.', 'Helps align technical assets with suitable accidental-damage and breakdown protection.', 45, 'intermediate', 2, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 6, 15, 3, 'IC11-C06-T03', 'Industrial All Risks and Advance Loss of Profits', 'Integrated industrial property coverage and delay or interruption losses connected with project damage.', 'Explain how industrial-all-risks and advance-loss-of-profits covers coordinate material and financial loss.', 'Supports programme design for large industrial operations and projects with time-sensitive revenue exposure.', 45, 'advanced', 3, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 6, 15, 4, 'IC11-C06-T04', 'Oil, Energy, Satellite and Other Specialised Risks', 'High-value technical risks requiring tailored wording, specialist engineering information and market capacity.', 'Identify why complex energy, space and other specialised exposures require customised insurance solutions.', 'Provides a framework for escalation, specialist placement and coordinated risk engineering.', 40, 'advanced', 4, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 7, 16, 1, 'IC11-C07-T01', 'Underwriting Purpose, Policy and Portfolio', 'Underwriting objectives, appetite, authority, guidelines and management of a balanced insurance portfolio.', 'Explain how underwriting policy converts an insurer''s strategy into risk-selection decisions.', 'Helps practitioners make consistent decisions that protect profitability and portfolio quality.', 40, 'intermediate', 1, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 7, 16, 2, 'IC11-C07-T02', 'Risk Information, Classification and Hazards', 'Collection and assessment of exposure information, risk classification and physical, moral and morale hazards.', 'Evaluate the information and hazard factors that influence acceptance, terms and pricing.', 'Improves risk selection and the identification of material underwriting concerns.', 45, 'intermediate', 2, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 7, 16, 3, 'IC11-C07-T03', 'Acceptance, Terms, Documentation and Renewal', 'Accepting or declining risks, limits, deductibles, warranties, documentation, renewal and customer service.', 'Apply the main underwriting options and document decisions throughout the policy lifecycle.', 'Supports transparent quotations, controlled policy issuance and disciplined renewal review.', 45, 'intermediate', 3, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp())
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
