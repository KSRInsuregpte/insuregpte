-- Direct IC11 topic insertion, batch 05 of 06.
-- IC11 subject_id=2; module IDs 5-9; chapter IDs 10-18.
-- IC11-C01-T01 is intentionally excluded because it was inserted successfully first.

INSERT INTO public.subject_topics (
    subject_id, module_id, chapter_id, topic_number, code, title,
    description, learning_objective, practical_relevance,
    estimated_study_minutes, difficulty_level, display_order,
    is_exam_relevant, is_active, created_at, updated_at
)
VALUES
(2, 7, 16, 4, 'IC11-C07-T04', 'Co-insurance and Reinsurance', 'Sharing risk among insurers and transferring portfolio or individual-risk exposure to reinsurers.', 'Distinguish co-insurance from reinsurance and explain how each supports underwriting capacity.', 'Helps practitioners recognise when risk size, accumulation or volatility requires shared capacity.', 45, 'advanced', 4, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 7, 16, 5, 'IC11-C07-T05', 'Rating and Premium Calculation', 'Pure premium, expenses, commissions, claims cost, contingencies, profit and risk-based rating factors.', 'Explain the components of premium and apply the principles that convert exposure into a rate.', 'Supports sustainable quotations and clearer explanation of why premiums differ between risks.', 50, 'intermediate', 5, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 7, 16, 6, 'IC11-C07-T06', 'Market Cycles and Risk Management', 'Soft and hard insurance markets, portfolio review and the identification, control and financing of risk.', 'Relate market conditions and risk-management measures to underwriting and pricing decisions.', 'Helps maintain underwriting discipline while recognising how controls can improve an exposure.', 40, 'advanced', 6, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 8, 17, 1, 'IC11-C08-T01', 'Claims Notification and Loss Minimisation', 'Prompt notification, first response, mitigation duties and preservation of evidence following loss.', 'Explain the insured''s and insurer''s immediate responsibilities after an incident.', 'Supports faster assistance, reduced loss severity and reliable later investigation.', 35, 'foundation', 1, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 8, 17, 2, 'IC11-C08-T02', 'Coverage, Investigation and Liability', 'Policy response, cause of loss, factual investigation, legal liability and fraud indicators.', 'Apply a structured approach to deciding whether and to what extent a reported loss is covered.', 'Promotes fair, evidence-based decisions and early identification of complex or suspicious claims.', 45, 'intermediate', 2, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 8, 17, 3, 'IC11-C08-T03', 'Survey, Documentation and Loss Assessment', 'Role of surveyors and specialists, supporting documents, valuation and measurement of insured loss.', 'Explain how claims evidence is collected and converted into a defensible loss assessment.', 'Improves claim quality, auditability and coordination with external experts.', 45, 'intermediate', 3, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 8, 17, 4, 'IC11-C08-T04', 'Claim Reserves, Settlement and Discharge', 'Establishing and reviewing reserves, applying policy terms, agreeing settlement and documenting discharge.', 'Describe the financial and procedural steps from assessed liability to claim payment.', 'Supports accurate financial reporting and timely, properly authorised settlement.', 45, 'intermediate', 4, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp())
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
