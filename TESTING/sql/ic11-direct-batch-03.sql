-- Direct IC11 topic insertion, batch 03 of 06.
-- IC11 subject_id=2; module IDs 5-9; chapter IDs 10-18.
-- IC11-C01-T01 is intentionally excluded because it was inserted successfully first.

INSERT INTO public.subject_topics (
    subject_id, module_id, chapter_id, topic_number, code, title,
    description, learning_objective, practical_relevance,
    estimated_study_minutes, difficulty_level, display_order,
    is_exam_relevant, is_active, created_at, updated_at
)
VALUES
(2, 6, 13, 4, 'IC11-C04-T04', 'Marine Cargo Insurance', 'Cargo interests, transit risks, policy forms, clauses, valuation and claims considerations.', 'Describe how marine cargo insurance protects goods through domestic and international transit.', 'Assists in selecting transit cover and reviewing documentation across the supply chain.', 45, 'intermediate', 4, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 6, 13, 5, 'IC11-C04-T05', 'Marine Hull and Marine Policy Types', 'Hull interests, maritime perils, voyage and time policies, valued cover and related marine arrangements.', 'Distinguish marine hull coverage and the main forms in which marine insurance may be arranged.', 'Provides a foundation for handling vessel risks and coordinating marine policy interests.', 40, 'intermediate', 5, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 6, 14, 1, 'IC11-C05-T01', 'Motor Insurance', 'Vehicle classification, compulsory third-party liability, own-damage cover, rating and motor claims.', 'Explain the principal motor covers and distinguish compulsory liability from optional protection.', 'Supports compliant policy selection and the initial handling of motor losses and liabilities.', 50, 'intermediate', 1, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 6, 14, 2, 'IC11-C05-T02', 'Liability and Professional Indemnity Insurance', 'Public, product, employer and professional liabilities and the insurance mechanisms that address them.', 'Identify common liability exposures and explain the trigger and scope of liability policies.', 'Helps businesses and professionals arrange protection against third-party legal obligations.', 45, 'intermediate', 2, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 6, 14, 3, 'IC11-C05-T03', 'Personal Accident and Health Insurance', 'Accidental death and disability benefits, sickness and hospitalisation cover, exclusions and claims considerations.', 'Compare personal accident and health insurance and explain their principal benefits and limitations.', 'Supports appropriate personal protection and clearer communication of benefit-based and indemnity covers.', 45, 'foundation', 3, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 6, 14, 4, 'IC11-C05-T04', 'Burglary, Baggage, Money and Fidelity Covers', 'Property-crime, travel-property, money and employee-dishonesty exposures and their insurance treatment.', 'Distinguish the interests and loss events protected by common crime and fidelity policies.', 'Enables practitioners to identify gaps between property damage, theft and dishonesty protection.', 40, 'intermediate', 4, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 6, 14, 5, 'IC11-C05-T05', 'Aviation, Rural and Micro-insurance Covers', 'Selected aviation exposures and general-insurance solutions designed for rural and low-income customers.', 'Describe the purpose and broad scope of aviation, rural and micro-insurance products.', 'Builds awareness of specialised access, affordability and exposure considerations across diverse markets.', 35, 'intermediate', 5, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp())
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
