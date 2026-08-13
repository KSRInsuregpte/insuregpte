-- Direct IC11 topic insertion, batch 06 of 06.
-- IC11 subject_id=2; module IDs 5-9; chapter IDs 10-18.
-- IC11-C01-T01 is intentionally excluded because it was inserted successfully first.

INSERT INTO public.subject_topics (
    subject_id, module_id, chapter_id, topic_number, code, title,
    description, learning_objective, practical_relevance,
    estimated_study_minutes, difficulty_level, display_order,
    is_exam_relevant, is_active, created_at, updated_at
)
VALUES
(2, 8, 17, 5, 'IC11-C08-T05', 'Arbitration, Litigation and Claim Disputes', 'Disagreement over quantum or liability, arbitration provisions, litigation and alternative resolution.', 'Distinguish common claim disputes and the mechanisms available for resolving them.', 'Helps route disagreements appropriately while preserving evidence and contractual rights.', 40, 'advanced', 5, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 8, 17, 6, 'IC11-C08-T06', 'Salvage, Subrogation, Recoveries and Closure', 'Salvage control, recovery from responsible parties, contribution and post-settlement claim closure.', 'Explain how insurers preserve and exercise recovery rights after indemnifying a loss.', 'Reduces net claim cost and ensures that files close with assets, rights and records properly handled.', 40, 'intermediate', 6, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 9, 18, 1, 'IC11-C09-T01', 'Purpose and Types of Technical Reserves', 'Why general insurers establish technical reserves and the principal categories of future claim liability.', 'Explain how delayed and uncertain claim costs create the need for prudent reserving.', 'Connects claims estimates with insurer profitability, liquidity and solvency.', 40, 'intermediate', 1, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 9, 18, 2, 'IC11-C09-T02', 'Outstanding Claims and IBNR Reserves', 'Case estimates, incurred-but-not-reported claims, development uncertainty and reserve review.', 'Distinguish outstanding-claim and IBNR reserves and explain why both change over time.', 'Supports accurate claims reporting and recognition of liabilities not fully visible at the reporting date.', 45, 'advanced', 2, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 9, 18, 3, 'IC11-C09-T03', 'Unexpired Risk and Premium Reserves', 'Unearned exposure, unexpired-risk obligations and the relationship between written premium and future cover.', 'Explain why part of premium must be carried forward for risk remaining after the accounting date.', 'Helps interpret underwriting results and prevents premature recognition of income.', 40, 'advanced', 3, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 9, 18, 4, 'IC11-C09-T04', 'Insurance Investments and Asset Strategy', 'Investment objectives, regulatory constraints, liquidity, security, yield and asset-liability considerations.', 'Explain how insurers invest funds while protecting claim-paying capacity and regulatory compliance.', 'Connects investment decisions with the timing, uncertainty and nature of insurance liabilities.', 45, 'advanced', 4, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()),
(2, 9, 18, 5, 'IC11-C09-T05', 'Financial Statements and Management Returns', 'Insurance accounts, underwriting results, balance-sheet items, regulatory statements and management information.', 'Identify the principal financial and management reports used to monitor a general insurer.', 'Supports interpretation of performance, reserve adequacy, solvency and operational trends.', 45, 'advanced', 5, true, true, pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp())
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
