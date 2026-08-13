-- Direct IC11 topic insertion, batch 01 of 06.
-- IC11 subject_id=2; module IDs 5-9; chapter IDs 10-18.
-- IC11-C01-T01 is intentionally excluded because it was inserted successfully first.

INSERT INTO public.subject_topics (
    subject_id, module_id, chapter_id, topic_number, code, title,
    description, learning_objective, practical_relevance,
    estimated_study_minutes, difficulty_level, display_order,
    is_exam_relevant, is_active, created_at, updated_at
)
VALUES
(2, 5, 10, 2, 'IC11-C01-T02', 'Insurance Act and Regulatory Provisions', 'Core Insurance Act provisions affecting general insurers, business operations, supervision and compliance.', 'Explain how the Insurance Act regulates general insurance institutions and transactions.', 'Helps practitioners recognise when operational decisions require statutory or regulatory review.', 40, 'intermediate', 2, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 5, 10, 3, 'IC11-C01-T03', 'Consumer, Motor and Liability Legislation', 'Consumer-protection, motor-vehicle, public-liability and related laws affecting general insurance.', 'Relate major non-insurance statutes to policy obligations, compulsory cover and claims handling.', 'Supports compliant underwriting and claims decisions where insurance policies interact with wider law.', 40, 'intermediate', 3, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 5, 10, 4, 'IC11-C01-T04', 'Exchange Control and Other Applicable Laws', 'Exchange-control requirements and other legal provisions relevant to cross-border and specialised general insurance.', 'Identify legal considerations that arise when premiums, risks, assets or claims involve overseas elements.', 'Reduces compliance risk in marine, travel, reinsurance and international insurance transactions.', 30, 'intermediate', 4, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 5, 11, 1, 'IC11-C02-T01', 'Indian General Insurance Market Structure', 'Public, private and specialised participants and the structure of the Indian non-life insurance market.', 'Describe the principal market participants and how general insurance business is organised in India.', 'Helps learners place products and transactions within the correct institutional setting.', 35, 'foundation', 1, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 5, 11, 2, 'IC11-C02-T02', 'Insurers and Specialised Insurance Institutions', 'General insurers, health insurers, reinsurers, agriculture and export-credit institutions and government insurance arrangements.', 'Distinguish conventional insurers from specialised institutions and explain their market roles.', 'Supports correct referral and placement of risks requiring specialised capacity or public schemes.', 35, 'foundation', 2, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 5, 11, 3, 'IC11-C02-T03', 'Insurance Intermediaries and Service Providers', 'Agents, corporate agents, brokers, third-party administrators, surveyors and loss assessors.', 'Compare the functions, responsibilities and relationships of key insurance intermediaries and service providers.', 'Clarifies who may solicit, service, assess and support general insurance business and claims.', 40, 'intermediate', 3, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 5, 11, 4, 'IC11-C02-T04', 'International Insurance and Reinsurance Markets', 'Major international insurance centres, global market participants and the role of reinsurance capacity.', 'Explain why insurers access international markets and how global capacity supports complex risks.', 'Provides context for placements involving large, unusual or internationally connected exposures.', 35, 'intermediate', 4, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp())
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
