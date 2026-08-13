-- Seed the complete IC11 topic hierarchy under the approved modules and chapters.
-- This migration does not create learning resources or flashcards and must be
-- deployed together with the approved IC11 content migrations.
-- No learner, progress, entitlement, activity, or practice-attempt rows are changed.

BEGIN;

DROP TABLE IF EXISTS pg_temp.ic11_topic_seed;

CREATE TEMPORARY TABLE ic11_topic_seed (
    module_code text NOT NULL,
    chapter_code text NOT NULL,
    topic_number integer NOT NULL,
    code text PRIMARY KEY,
    title text NOT NULL,
    description text NOT NULL,
    learning_objective text NOT NULL,
    practical_relevance text NOT NULL,
    estimated_study_minutes integer NOT NULL,
    difficulty_level text NOT NULL,
    display_order integer NOT NULL
) ON COMMIT PRESERVE ROWS;

INSERT INTO ic11_topic_seed VALUES
('IC11-M01', 'IC11-C01', 1, 'IC11-C01-T01', 'Evolution and Legal Framework of General Insurance',
 'Development of general insurance in India and the principal laws that shape non-life insurance business.',
 'Trace the development of general insurance and identify the purpose of its principal legislation.',
 'Provides the legal context needed when interpreting insurer, intermediary and policyholder responsibilities.', 35, 'foundation', 1),
('IC11-M01', 'IC11-C01', 2, 'IC11-C01-T02', 'Insurance Act and Regulatory Provisions',
 'Core Insurance Act provisions affecting general insurers, business operations, supervision and compliance.',
 'Explain how the Insurance Act regulates general insurance institutions and transactions.',
 'Helps practitioners recognise when operational decisions require statutory or regulatory review.', 40, 'intermediate', 2),
('IC11-M01', 'IC11-C01', 3, 'IC11-C01-T03', 'Consumer, Motor and Liability Legislation',
 'Consumer-protection, motor-vehicle, public-liability and related laws affecting general insurance.',
 'Relate major non-insurance statutes to policy obligations, compulsory cover and claims handling.',
 'Supports compliant underwriting and claims decisions where insurance policies interact with wider law.', 40, 'intermediate', 3),
('IC11-M01', 'IC11-C01', 4, 'IC11-C01-T04', 'Exchange Control and Other Applicable Laws',
 'Exchange-control requirements and other legal provisions relevant to cross-border and specialised general insurance.',
 'Identify legal considerations that arise when premiums, risks, assets or claims involve overseas elements.',
 'Reduces compliance risk in marine, travel, reinsurance and international insurance transactions.', 30, 'intermediate', 4),

('IC11-M01', 'IC11-C02', 1, 'IC11-C02-T01', 'Indian General Insurance Market Structure',
 'Public, private and specialised participants and the structure of the Indian non-life insurance market.',
 'Describe the principal market participants and how general insurance business is organised in India.',
 'Helps learners place products and transactions within the correct institutional setting.', 35, 'foundation', 1),
('IC11-M01', 'IC11-C02', 2, 'IC11-C02-T02', 'Insurers and Specialised Insurance Institutions',
 'General insurers, health insurers, reinsurers, agriculture and export-credit institutions and government insurance arrangements.',
 'Distinguish conventional insurers from specialised institutions and explain their market roles.',
 'Supports correct referral and placement of risks requiring specialised capacity or public schemes.', 35, 'foundation', 2),
('IC11-M01', 'IC11-C02', 3, 'IC11-C02-T03', 'Insurance Intermediaries and Service Providers',
 'Agents, corporate agents, brokers, third-party administrators, surveyors and loss assessors.',
 'Compare the functions, responsibilities and relationships of key insurance intermediaries and service providers.',
 'Clarifies who may solicit, service, assess and support general insurance business and claims.', 40, 'intermediate', 3),
('IC11-M01', 'IC11-C02', 4, 'IC11-C02-T04', 'International Insurance and Reinsurance Markets',
 'Major international insurance centres, global market participants and the role of reinsurance capacity.',
 'Explain why insurers access international markets and how global capacity supports complex risks.',
 'Provides context for placements involving large, unusual or internationally connected exposures.', 35, 'intermediate', 4),

('IC11-M02', 'IC11-C03', 1, 'IC11-C03-T01', 'Insurance Contract and Policy Structure',
 'Contract formation, insurance principles and the principal components of a policy document.',
 'Identify the elements of an insurance contract and explain the function of each policy component.',
 'Supports accurate policy preparation, servicing and evaluation of contractual obligations.', 40, 'foundation', 1),
('IC11-M02', 'IC11-C03', 2, 'IC11-C03-T02', 'Proposal Forms and Material Information',
 'Proposal forms, material facts, disclosure, declarations and the use of underwriting information.',
 'Explain how proposal information forms the basis of underwriting and contractual disclosure.',
 'Helps prevent coverage disputes arising from incomplete or inaccurate risk information.', 35, 'intermediate', 2),
('IC11-M02', 'IC11-C03', 3, 'IC11-C03-T03', 'Cover Notes, Certificates and Endorsements',
 'Interim cover notes, statutory certificates, policy schedules and endorsements used during a policy lifecycle.',
 'Distinguish the purpose and legal effect of common insurance documents and amendments.',
 'Enables practitioners to select and issue the correct evidence of cover or policy change.', 35, 'foundation', 3),
('IC11-M02', 'IC11-C03', 4, 'IC11-C03-T04', 'Policy Interpretation, Co-insurance and Documentation',
 'Rules of policy interpretation, warranties, conditions, exceptions, co-insurance and document control.',
 'Apply a structured approach to interpreting policy wording and documenting shared insurance arrangements.',
 'Improves consistency when explaining cover, allocating participation and resolving wording questions.', 40, 'intermediate', 4),

('IC11-M02', 'IC11-C04', 1, 'IC11-C04-T01', 'Standard Fire and Special Perils Coverage',
 'Property interests, insured perils, exclusions, sums insured and the structure of fire insurance coverage.',
 'Explain the operative cover and principal limitations of standard fire and special-perils insurance.',
 'Supports suitable property placement and accurate first-stage analysis of fire losses.', 45, 'intermediate', 1),
('IC11-M02', 'IC11-C04', 2, 'IC11-C04-T02', 'Fire Policy Extensions and Special Policies',
 'Extensions, add-on covers, special declarations and policies designed for particular property exposures.',
 'Select policy adaptations that address risk characteristics not met by basic fire cover.',
 'Helps align property protection with occupancy, values, stock patterns and catastrophe exposure.', 40, 'intermediate', 2),
('IC11-M02', 'IC11-C04', 3, 'IC11-C04-T03', 'Consequential Loss Following Fire',
 'Business interruption, gross profit, indemnity period, standing charges and increased cost of working.',
 'Explain how consequential-loss insurance responds to financial interruption after insured damage.',
 'Supports coordinated property and interruption cover that protects business continuity.', 45, 'intermediate', 3),
('IC11-M02', 'IC11-C04', 4, 'IC11-C04-T04', 'Marine Cargo Insurance',
 'Cargo interests, transit risks, policy forms, clauses, valuation and claims considerations.',
 'Describe how marine cargo insurance protects goods through domestic and international transit.',
 'Assists in selecting transit cover and reviewing documentation across the supply chain.', 45, 'intermediate', 4),
('IC11-M02', 'IC11-C04', 5, 'IC11-C04-T05', 'Marine Hull and Marine Policy Types',
 'Hull interests, maritime perils, voyage and time policies, valued cover and related marine arrangements.',
 'Distinguish marine hull coverage and the main forms in which marine insurance may be arranged.',
 'Provides a foundation for handling vessel risks and coordinating marine policy interests.', 40, 'intermediate', 5),

('IC11-M02', 'IC11-C05', 1, 'IC11-C05-T01', 'Motor Insurance',
 'Vehicle classification, compulsory third-party liability, own-damage cover, rating and motor claims.',
 'Explain the principal motor covers and distinguish compulsory liability from optional protection.',
 'Supports compliant policy selection and the initial handling of motor losses and liabilities.', 50, 'intermediate', 1),
('IC11-M02', 'IC11-C05', 2, 'IC11-C05-T02', 'Liability and Professional Indemnity Insurance',
 'Public, product, employer and professional liabilities and the insurance mechanisms that address them.',
 'Identify common liability exposures and explain the trigger and scope of liability policies.',
 'Helps businesses and professionals arrange protection against third-party legal obligations.', 45, 'intermediate', 2),
('IC11-M02', 'IC11-C05', 3, 'IC11-C05-T03', 'Personal Accident and Health Insurance',
 'Accidental death and disability benefits, sickness and hospitalisation cover, exclusions and claims considerations.',
 'Compare personal accident and health insurance and explain their principal benefits and limitations.',
 'Supports appropriate personal protection and clearer communication of benefit-based and indemnity covers.', 45, 'foundation', 3),
('IC11-M02', 'IC11-C05', 4, 'IC11-C05-T04', 'Burglary, Baggage, Money and Fidelity Covers',
 'Property-crime, travel-property, money and employee-dishonesty exposures and their insurance treatment.',
 'Distinguish the interests and loss events protected by common crime and fidelity policies.',
 'Enables practitioners to identify gaps between property damage, theft and dishonesty protection.', 40, 'intermediate', 4),
('IC11-M02', 'IC11-C05', 5, 'IC11-C05-T05', 'Aviation, Rural and Micro-insurance Covers',
 'Selected aviation exposures and general-insurance solutions designed for rural and low-income customers.',
 'Describe the purpose and broad scope of aviation, rural and micro-insurance products.',
 'Builds awareness of specialised access, affordability and exposure considerations across diverse markets.', 35, 'intermediate', 5),

('IC11-M02', 'IC11-C06', 1, 'IC11-C06-T01', 'Contractors and Erection All Risks Insurance',
 'Construction, erection, testing, third-party liability, values and policy-period considerations.',
 'Compare contractors-all-risks and erection-all-risks cover across project stages.',
 'Supports correct project-policy selection and control of construction and installation exposures.', 45, 'intermediate', 1),
('IC11-M02', 'IC11-C06', 2, 'IC11-C06-T02', 'Machinery, Boiler and Electronic Equipment Insurance',
 'Breakdown, explosion, electrical and electronic equipment risks and the related engineering policies.',
 'Distinguish the principal engineering covers for machinery, pressure plant and electronic equipment.',
 'Helps align technical assets with suitable accidental-damage and breakdown protection.', 45, 'intermediate', 2),
('IC11-M02', 'IC11-C06', 3, 'IC11-C06-T03', 'Industrial All Risks and Advance Loss of Profits',
 'Integrated industrial property coverage and delay or interruption losses connected with project damage.',
 'Explain how industrial-all-risks and advance-loss-of-profits covers coordinate material and financial loss.',
 'Supports programme design for large industrial operations and projects with time-sensitive revenue exposure.', 45, 'advanced', 3),
('IC11-M02', 'IC11-C06', 4, 'IC11-C06-T04', 'Oil, Energy, Satellite and Other Specialised Risks',
 'High-value technical risks requiring tailored wording, specialist engineering information and market capacity.',
 'Identify why complex energy, space and other specialised exposures require customised insurance solutions.',
 'Provides a framework for escalation, specialist placement and coordinated risk engineering.', 40, 'advanced', 4),

('IC11-M03', 'IC11-C07', 1, 'IC11-C07-T01', 'Underwriting Purpose, Policy and Portfolio',
 'Underwriting objectives, appetite, authority, guidelines and management of a balanced insurance portfolio.',
 'Explain how underwriting policy converts an insurer''s strategy into risk-selection decisions.',
 'Helps practitioners make consistent decisions that protect profitability and portfolio quality.', 40, 'intermediate', 1),
('IC11-M03', 'IC11-C07', 2, 'IC11-C07-T02', 'Risk Information, Classification and Hazards',
 'Collection and assessment of exposure information, risk classification and physical, moral and morale hazards.',
 'Evaluate the information and hazard factors that influence acceptance, terms and pricing.',
 'Improves risk selection and the identification of material underwriting concerns.', 45, 'intermediate', 2),
('IC11-M03', 'IC11-C07', 3, 'IC11-C07-T03', 'Acceptance, Terms, Documentation and Renewal',
 'Accepting or declining risks, limits, deductibles, warranties, documentation, renewal and customer service.',
 'Apply the main underwriting options and document decisions throughout the policy lifecycle.',
 'Supports transparent quotations, controlled policy issuance and disciplined renewal review.', 45, 'intermediate', 3),
('IC11-M03', 'IC11-C07', 4, 'IC11-C07-T04', 'Co-insurance and Reinsurance',
 'Sharing risk among insurers and transferring portfolio or individual-risk exposure to reinsurers.',
 'Distinguish co-insurance from reinsurance and explain how each supports underwriting capacity.',
 'Helps practitioners recognise when risk size, accumulation or volatility requires shared capacity.', 45, 'advanced', 4),
('IC11-M03', 'IC11-C07', 5, 'IC11-C07-T05', 'Rating and Premium Calculation',
 'Pure premium, expenses, commissions, claims cost, contingencies, profit and risk-based rating factors.',
 'Explain the components of premium and apply the principles that convert exposure into a rate.',
 'Supports sustainable quotations and clearer explanation of why premiums differ between risks.', 50, 'intermediate', 5),
('IC11-M03', 'IC11-C07', 6, 'IC11-C07-T06', 'Market Cycles and Risk Management',
 'Soft and hard insurance markets, portfolio review and the identification, control and financing of risk.',
 'Relate market conditions and risk-management measures to underwriting and pricing decisions.',
 'Helps maintain underwriting discipline while recognising how controls can improve an exposure.', 40, 'advanced', 6),

('IC11-M04', 'IC11-C08', 1, 'IC11-C08-T01', 'Claims Notification and Loss Minimisation',
 'Prompt notification, first response, mitigation duties and preservation of evidence following loss.',
 'Explain the insured''s and insurer''s immediate responsibilities after an incident.',
 'Supports faster assistance, reduced loss severity and reliable later investigation.', 35, 'foundation', 1),
('IC11-M04', 'IC11-C08', 2, 'IC11-C08-T02', 'Coverage, Investigation and Liability',
 'Policy response, cause of loss, factual investigation, legal liability and fraud indicators.',
 'Apply a structured approach to deciding whether and to what extent a reported loss is covered.',
 'Promotes fair, evidence-based decisions and early identification of complex or suspicious claims.', 45, 'intermediate', 2),
('IC11-M04', 'IC11-C08', 3, 'IC11-C08-T03', 'Survey, Documentation and Loss Assessment',
 'Role of surveyors and specialists, supporting documents, valuation and measurement of insured loss.',
 'Explain how claims evidence is collected and converted into a defensible loss assessment.',
 'Improves claim quality, auditability and coordination with external experts.', 45, 'intermediate', 3),
('IC11-M04', 'IC11-C08', 4, 'IC11-C08-T04', 'Claim Reserves, Settlement and Discharge',
 'Establishing and reviewing reserves, applying policy terms, agreeing settlement and documenting discharge.',
 'Describe the financial and procedural steps from assessed liability to claim payment.',
 'Supports accurate financial reporting and timely, properly authorised settlement.', 45, 'intermediate', 4),
('IC11-M04', 'IC11-C08', 5, 'IC11-C08-T05', 'Arbitration, Litigation and Claim Disputes',
 'Disagreement over quantum or liability, arbitration provisions, litigation and alternative resolution.',
 'Distinguish common claim disputes and the mechanisms available for resolving them.',
 'Helps route disagreements appropriately while preserving evidence and contractual rights.', 40, 'advanced', 5),
('IC11-M04', 'IC11-C08', 6, 'IC11-C08-T06', 'Salvage, Subrogation, Recoveries and Closure',
 'Salvage control, recovery from responsible parties, contribution and post-settlement claim closure.',
 'Explain how insurers preserve and exercise recovery rights after indemnifying a loss.',
 'Reduces net claim cost and ensures that files close with assets, rights and records properly handled.', 40, 'intermediate', 6),

('IC11-M05', 'IC11-C09', 1, 'IC11-C09-T01', 'Purpose and Types of Technical Reserves',
 'Why general insurers establish technical reserves and the principal categories of future claim liability.',
 'Explain how delayed and uncertain claim costs create the need for prudent reserving.',
 'Connects claims estimates with insurer profitability, liquidity and solvency.', 40, 'intermediate', 1),
('IC11-M05', 'IC11-C09', 2, 'IC11-C09-T02', 'Outstanding Claims and IBNR Reserves',
 'Case estimates, incurred-but-not-reported claims, development uncertainty and reserve review.',
 'Distinguish outstanding-claim and IBNR reserves and explain why both change over time.',
 'Supports accurate claims reporting and recognition of liabilities not fully visible at the reporting date.', 45, 'advanced', 2),
('IC11-M05', 'IC11-C09', 3, 'IC11-C09-T03', 'Unexpired Risk and Premium Reserves',
 'Unearned exposure, unexpired-risk obligations and the relationship between written premium and future cover.',
 'Explain why part of premium must be carried forward for risk remaining after the accounting date.',
 'Helps interpret underwriting results and prevents premature recognition of income.', 40, 'advanced', 3),
('IC11-M05', 'IC11-C09', 4, 'IC11-C09-T04', 'Insurance Investments and Asset Strategy',
 'Investment objectives, regulatory constraints, liquidity, security, yield and asset-liability considerations.',
 'Explain how insurers invest funds while protecting claim-paying capacity and regulatory compliance.',
 'Connects investment decisions with the timing, uncertainty and nature of insurance liabilities.', 45, 'advanced', 4),
('IC11-M05', 'IC11-C09', 5, 'IC11-C09-T05', 'Financial Statements and Management Returns',
 'Insurance accounts, underwriting results, balance-sheet items, regulatory statements and management information.',
 'Identify the principal financial and management reports used to monitor a general insurer.',
 'Supports interpretation of performance, reserve adequacy, solvency and operational trends.', 45, 'advanced', 5);

DO $validate$
DECLARE
    v_subject_id bigint;
BEGIN
    SELECT subject_record.id
    INTO v_subject_id
    FROM public.subjects AS subject_record
    WHERE pg_catalog.upper(subject_record.code) = 'IC11'
      AND subject_record.is_active = true;

    IF v_subject_id IS NULL THEN
        RAISE EXCEPTION 'The active IC11 subject was not found.';
    END IF;

    IF (
        SELECT pg_catalog.count(*)
        FROM public.subject_modules AS module_record
        WHERE module_record.subject_id = v_subject_id
          AND module_record.is_active = true
          AND pg_catalog.upper(module_record.code) IN (
              'IC11-M01', 'IC11-M02', 'IC11-M03', 'IC11-M04', 'IC11-M05'
          )
    ) <> 5 THEN
        RAISE EXCEPTION 'All five approved active IC11 modules are required.';
    END IF;

    IF (
        SELECT pg_catalog.count(*)
        FROM public.subject_chapters AS chapter_record
        WHERE chapter_record.subject_id = v_subject_id
          AND chapter_record.is_active = true
          AND pg_catalog.upper(chapter_record.code) BETWEEN 'IC11-C01' AND 'IC11-C09'
    ) <> 9 THEN
        RAISE EXCEPTION 'All nine approved active IC11 chapters are required.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ic11_topic_seed AS seed
        LEFT JOIN public.subject_modules AS module_record
          ON module_record.subject_id = v_subject_id
         AND pg_catalog.upper(module_record.code) = seed.module_code
        LEFT JOIN public.subject_chapters AS chapter_record
          ON chapter_record.subject_id = v_subject_id
         AND chapter_record.module_id = module_record.id
         AND pg_catalog.upper(chapter_record.code) = seed.chapter_code
        WHERE module_record.id IS NULL OR chapter_record.id IS NULL
    ) THEN
        RAISE EXCEPTION 'An IC11 topic seed row does not match the frozen module/chapter hierarchy.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.subject_topics AS topic_record
        JOIN ic11_topic_seed AS seed
          ON pg_catalog.upper(topic_record.code) = seed.code
        WHERE topic_record.subject_id <> v_subject_id
           OR pg_catalog.upper((
                SELECT chapter_record.code
                FROM public.subject_chapters AS chapter_record
                WHERE chapter_record.id = topic_record.chapter_id
              )) <> seed.chapter_code
    ) THEN
        RAISE EXCEPTION 'A planned IC11 topic code is already assigned outside its intended chapter.';
    END IF;
END;
$validate$;

INSERT INTO public.subject_topics (
    subject_id, module_id, chapter_id, topic_number, code, title,
    description, learning_objective, practical_relevance,
    estimated_study_minutes, difficulty_level, display_order,
    is_exam_relevant, is_active
)
SELECT
    subject_record.id,
    module_record.id,
    chapter_record.id,
    seed.topic_number,
    seed.code,
    seed.title,
    seed.description,
    seed.learning_objective,
    seed.practical_relevance,
    seed.estimated_study_minutes,
    seed.difficulty_level,
    seed.display_order,
    true,
    true
FROM ic11_topic_seed AS seed
JOIN public.subjects AS subject_record
  ON pg_catalog.upper(subject_record.code) = 'IC11'
JOIN public.subject_modules AS module_record
  ON module_record.subject_id = subject_record.id
 AND pg_catalog.upper(module_record.code) = seed.module_code
JOIN public.subject_chapters AS chapter_record
  ON chapter_record.subject_id = subject_record.id
 AND chapter_record.module_id = module_record.id
 AND pg_catalog.upper(chapter_record.code) = seed.chapter_code
WHERE NOT EXISTS (
    SELECT 1
    FROM public.subject_topics AS existing
    WHERE pg_catalog.upper(existing.code) = seed.code
);

UPDATE public.subject_topics AS topic_record
SET module_id = module_record.id,
    chapter_id = chapter_record.id,
    topic_number = seed.topic_number,
    title = seed.title,
    description = seed.description,
    learning_objective = seed.learning_objective,
    practical_relevance = seed.practical_relevance,
    estimated_study_minutes = seed.estimated_study_minutes,
    difficulty_level = seed.difficulty_level,
    display_order = seed.display_order,
    is_exam_relevant = true,
    is_active = true,
    updated_at = pg_catalog.clock_timestamp()
FROM ic11_topic_seed AS seed
JOIN public.subjects AS subject_record
  ON pg_catalog.upper(subject_record.code) = 'IC11'
JOIN public.subject_modules AS module_record
  ON module_record.subject_id = subject_record.id
 AND pg_catalog.upper(module_record.code) = seed.module_code
JOIN public.subject_chapters AS chapter_record
  ON chapter_record.subject_id = subject_record.id
 AND chapter_record.module_id = module_record.id
 AND pg_catalog.upper(chapter_record.code) = seed.chapter_code
WHERE topic_record.subject_id = subject_record.id
  AND pg_catalog.upper(topic_record.code) = seed.code;

DO $verify$
DECLARE
    v_subject_id bigint;
BEGIN
    SELECT subject_record.id
    INTO v_subject_id
    FROM public.subjects AS subject_record
    WHERE pg_catalog.upper(subject_record.code) = 'IC11';

    IF (
        SELECT pg_catalog.count(*)
        FROM public.subject_topics AS topic_record
        JOIN ic11_topic_seed AS seed
          ON seed.code = pg_catalog.upper(topic_record.code)
        WHERE topic_record.subject_id = v_subject_id
          AND topic_record.is_active = true
    ) <> 43 THEN
        RAISE EXCEPTION 'Expected exactly 43 active planned IC11 topics.';
    END IF;

    IF EXISTS (
        SELECT seed.chapter_code
        FROM ic11_topic_seed AS seed
        LEFT JOIN public.subject_topics AS topic_record
          ON pg_catalog.upper(topic_record.code) = seed.code
         AND topic_record.subject_id = v_subject_id
         AND topic_record.is_active = true
        GROUP BY seed.chapter_code
        HAVING pg_catalog.count(topic_record.id) <> pg_catalog.count(seed.code)
    ) THEN
        RAISE EXCEPTION 'One or more IC11 chapters has an incomplete topic hierarchy.';
    END IF;
END;
$verify$;

DROP TABLE IF EXISTS pg_temp.ic11_topic_seed;

COMMIT;
