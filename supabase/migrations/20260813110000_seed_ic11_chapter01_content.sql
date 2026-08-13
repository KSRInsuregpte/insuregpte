-- Seed original learning content for IC11 Chapter 1: Insurance Legislation.
-- Requires the IC11 topic-hierarchy migration. Stable codes make this rerunnable.
-- No learner, progress, entitlement, activity, or practice-attempt rows are changed.

BEGIN;

DO $validate$
DECLARE
    v_subject_id bigint;
    v_chapter_id integer;
BEGIN
    SELECT subject_record.id, chapter_record.id
    INTO v_subject_id, v_chapter_id
    FROM public.subjects AS subject_record
    JOIN public.subject_modules AS module_record
      ON module_record.subject_id = subject_record.id
    JOIN public.subject_chapters AS chapter_record
      ON chapter_record.subject_id = subject_record.id
     AND chapter_record.module_id = module_record.id
    WHERE pg_catalog.upper(subject_record.code) = 'IC11'
      AND pg_catalog.upper(module_record.code) = 'IC11-M01'
      AND pg_catalog.upper(chapter_record.code) = 'IC11-C01'
      AND subject_record.is_active = true
      AND module_record.is_active = true
      AND chapter_record.is_active = true;

    IF v_subject_id IS NULL THEN
        RAISE EXCEPTION 'The active IC11 / IC11-M01 / IC11-C01 hierarchy was not found.';
    END IF;

    IF (
        SELECT pg_catalog.count(*)
        FROM public.subject_topics AS topic_record
        WHERE topic_record.subject_id = v_subject_id
          AND topic_record.chapter_id = v_chapter_id
          AND topic_record.is_active = true
          AND pg_catalog.upper(topic_record.code) BETWEEN 'IC11-C01-T01' AND 'IC11-C01-T04'
    ) <> 4 THEN
        RAISE EXCEPTION 'All four active IC11 Chapter 1 topics are required.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.learning_resource_types AS resource_type
        WHERE pg_catalog.upper(resource_type.code) = 'NOTE' AND resource_type.is_active = true
    ) OR NOT EXISTS (
        SELECT 1 FROM public.learning_resource_types AS resource_type
        WHERE pg_catalog.upper(resource_type.code) = 'REVISION_NOTE' AND resource_type.is_active = true
    ) THEN
        RAISE EXCEPTION 'The active NOTE and REVISION_NOTE resource types are required.';
    END IF;
END;
$validate$;

DROP TABLE IF EXISTS pg_temp.ic11_c01_resource_seed;

CREATE TEMPORARY TABLE ic11_c01_resource_seed (
    topic_code text NOT NULL,
    resource_type_code text NOT NULL,
    code text PRIMARY KEY,
    title text NOT NULL,
    short_description text NOT NULL,
    content text NOT NULL,
    estimated_read_minutes integer NOT NULL,
    display_order integer NOT NULL
) ON COMMIT PRESERVE ROWS;

INSERT INTO ic11_c01_resource_seed VALUES
('IC11-C01-T01', 'NOTE', 'LR-IC11-C01-T01-001',
 'Evolution and Legal Framework of General Insurance',
 'An original overview of the development of Indian general insurance and its layered legal framework.',
 $content$
General insurance developed from arrangements for sharing the financial consequences of uncertain events. Early marine trading practices demonstrated the central idea: many participants contribute so that the loss suffered by a few can be met. Modern insurance separates the financing transaction from the insurance promise and records the cover in a legally enforceable contract.

Development in India

Indian insurance evolved through private enterprise, statutory supervision, nationalisation, and later market liberalisation. Each stage changed who could carry on insurance business and how institutions were controlled. The Insurance Act, 1938 created a comprehensive supervisory foundation. General insurance was subsequently nationalised under special legislation, and public-sector institutions became central to the market. Reforms following the Malhotra Committee led to the creation of an independent regulator and renewed private-sector participation.

The layered framework

No single enactment answers every insurance question. The framework consists of:

1. Primary legislation enacted by Parliament, including the Insurance Act and legislation establishing the insurance regulator.
2. Rules and regulations that translate statutory powers into operational requirements.
3. Directions, circulars, master circulars and guidelines issued by the regulator within its legal authority.
4. General laws governing contracts, consumers, motor vehicles, liability, taxation, foreign exchange and evidence.
5. The insurance policy itself, which defines the agreed cover subject to mandatory law.

The hierarchy matters. A policy condition cannot override a mandatory statute. A circular cannot exceed the authority granted by legislation. A commercial practice must be tested against both the policy wording and the governing law.

Why regulation is necessary

Insurance involves a promise to pay in the future. The insurer receives premium before the true cost of claims is known. Regulation therefore promotes financial soundness, fair treatment, reliable information, orderly market conduct and confidence that valid claims can be paid. It also establishes entry requirements and continuing supervision for insurers and intermediaries.

Historical facts explain why institutions exist, but legal requirements can change. For operational decisions, learners should distinguish the examination framework from the currently effective law and verify time-sensitive limits, procedures and eligibility conditions against official publications.
$content$, 18, 1),
('IC11-C01-T01', 'REVISION_NOTE', 'LR-IC11-C01-T01-002',
 'Quick Revision: Evolution and Legal Framework',
 'Exam-oriented revision of the historical stages, sources of law and reasons for insurance regulation.',
 $content$
Quick Revision Points

1. Insurance pools contributions so that losses of the few can be shared by the many.
2. The Insurance Act, 1938 established a comprehensive statutory framework.
3. Nationalisation reorganised general insurance under public ownership.
4. Later reforms introduced independent regulation and private participation.
5. Primary legislation grants powers and establishes mandatory duties.
6. Regulations and official directions supply detailed operating rules.
7. General contract, consumer, motor, liability and foreign-exchange laws may apply alongside insurance law.
8. Policy wording governs the contractual cover but cannot defeat mandatory law.
9. Regulation protects policyholders and promotes solvent, fair and orderly markets.
10. Time-sensitive rules must be checked against current official sources.

Exam Focus

- Arrange the major stages of market development in sequence.
- Distinguish an Act, a regulation, an official direction and a policy condition.
- Explain why advance premium and uncertain future claims justify supervision.

Memory Line

Law authorises; regulation details; policy contracts; supervision protects.
$content$, 6, 2),

('IC11-C01-T02', 'NOTE', 'LR-IC11-C01-T02-001',
 'Insurance Act and Regulatory Provisions',
 'How statutory provisions govern insurers, operations, financial discipline and regulatory supervision.',
 $content$
The Insurance Act supplies the principal legal structure for carrying on insurance business in India. It should be understood as an enabling and controlling framework rather than memorised as an isolated list of sections. Its provisions connect market entry, business conduct, financial security, reporting and enforcement.

Entry and continuing authority

An entity cannot carry on insurance merely because it is incorporated as a company. Insurance business requires the registration or authority prescribed by insurance law. The regulator examines matters such as ownership, capital, governance, management capability and the proposed business plan. Continuing permission depends on compliance, not only on obtaining an initial approval.

Financial discipline

An insurer accepts liabilities that may emerge long after premium is collected. The law therefore addresses capital, deposits, assets, investments, accounts, actuarial or technical provisions, solvency and financial reporting. These controls seek to ensure that assets are available, suitably held and sufficient to support policyholder obligations. Under-reserving may create an artificial profit; unsuitable investment may endanger liquidity or security.

Operational controls

Regulatory provisions influence product design, premium and policy documentation, distribution, commissions or remuneration, reinsurance, claims practices, expenses and recordkeeping. Specific requirements vary by class of business and change over time. The compliance method is to identify the applicable rule, confirm its effective version, document the decision and retain evidence.

Supervision and enforcement

The regulator may obtain returns and information, conduct inspection or investigation, issue directions and take corrective or enforcement action within its statutory powers. The objective is not only punishment after failure; supervision also seeks early detection and correction of unsafe or unfair practices.

Practical interpretation

When reviewing a transaction, ask four questions:

1. Is the insurer or intermediary authorised for this activity?
2. Does the proposed product or process meet mandatory requirements?
3. Are financial, disclosure and recordkeeping obligations satisfied?
4. Is there an official amendment, regulation or direction that supersedes older material?

Exact thresholds and procedures are time-sensitive. The examination concept remains the relationship between authorisation, financial soundness, market conduct and regulatory accountability.
$content$, 20, 1),
('IC11-C01-T02', 'REVISION_NOTE', 'LR-IC11-C01-T02-002',
 'Quick Revision: Insurance Act and Supervision',
 'Core statutory themes for registration, finance, operations, reporting and enforcement.',
 $content$
Quick Revision Points

1. Incorporation alone does not authorise insurance business.
2. Registration examines ownership, capital, governance, capability and business plans.
3. Permission is continuing and depends on compliance.
4. Capital, assets, investments, reserves and solvency protect claim-paying ability.
5. Accounts and regulatory returns make the insurer's position visible to supervisors.
6. Operational controls may cover products, distribution, remuneration, reinsurance, claims and records.
7. Inspection and investigation allow the regulator to test actual compliance.
8. Directions and enforcement measures correct or sanction non-compliance.
9. Under-reserving can overstate profit and weaken solvency.
10. Always use the effective official rule for numerical limits and procedures.

Exam Focus

- Link each regulatory control to the risk it addresses.
- Distinguish initial registration from continuing supervision.
- Explain why financial regulation and market-conduct regulation are both necessary.

Memory Line

Authorise the entity; supervise the business; secure the promise.
$content$, 6, 2),

('IC11-C01-T03', 'NOTE', 'LR-IC11-C01-T03-001',
 'Consumer, Motor and Liability Legislation',
 'The interaction of general insurance with consumer protection, compulsory motor cover and statutory liability.',
 $content$
General insurance operates within a wider legal environment. A policy may insure a liability, but the liability itself usually arises under another law or under general legal principles. Practitioners must keep the source of liability separate from the contract that finances it.

Consumer protection

Insurance is a service. A policyholder or other eligible consumer may seek redress where there is an alleged deficiency in service or an unfair practice. Consumer law provides forums and remedies in addition to internal grievance procedures and insurance-specific mechanisms. Jurisdictional limits, filing procedures and appeal rules are amended from time to time, so current official law must be checked before advising a complainant.

Motor-vehicle law

Motor legislation makes specified third-party insurance compulsory for the use of a motor vehicle in a public place. The purpose is social protection: an injured third party should not depend solely on the vehicle owner's financial resources. Compulsory third-party liability is distinct from own-damage protection. A comprehensive or package policy may combine both, but the legal requirement and the optional property cover should not be confused.

Statutory liability

Other enactments may impose liability for injury, occupational harm, hazardous activities, environmental damage or specified accidents. Insurance can provide financial protection subject to the policy, but it does not erase the underlying duty. Whether the insurer responds depends on the insured event, legal liability, policy period, limits, deductibles, exclusions and compliance with conditions.

Public-liability arrangements

Some hazardous activities are subject to special liability and insurance requirements. These schemes may aim at prompt relief and may operate differently from ordinary fault-based claims. A practitioner should identify the statute, the persons protected, the required insurance, the relief mechanism and any fund or authority involved.

Claims and compliance method

For any legally driven claim:

1. Identify the law creating or regulating the liability.
2. Establish the facts and the responsible parties.
3. Read the policy grant, definitions, exclusions and limits.
4. Check compulsory requirements and the rights of third parties.
5. Apply the currently effective procedure and preserve all notices and evidence.

This method prevents a common error: assuming that legal liability automatically equals full policy liability.
$content$, 20, 1),
('IC11-C01-T03', 'REVISION_NOTE', 'LR-IC11-C01-T03-002',
 'Quick Revision: Consumer, Motor and Liability Laws',
 'Key distinctions between legal liability, compulsory insurance and contractual policy response.',
 $content$
Quick Revision Points

1. Consumer law may treat insurance as a service.
2. Insurance-specific grievance mechanisms do not necessarily exclude other lawful remedies.
3. Motor third-party insurance serves a compulsory social-protection purpose.
4. Third-party liability cover is different from optional own-damage cover.
5. Liability arises under law or legal principles; insurance finances specified consequences.
6. A statutory duty continues even where insurance is arranged.
7. Policy response depends on wording, period, limits, exclusions and conditions.
8. Special liability statutes may provide prompt relief or compulsory cover.
9. Legal liability and insurer liability are related but not identical.
10. Current forum limits and procedures require official verification.

Exam Focus

- Distinguish compulsory third-party and own-damage motor cover.
- Separate the source of liability from the source of insurance indemnity.
- Apply the five-stage claims and compliance method.

Memory Line

Law creates the duty; policy defines the insured response.
$content$, 6, 2),

('IC11-C01-T04', 'NOTE', 'LR-IC11-C01-T04-001',
 'Exchange Control and Other Applicable Laws',
 'Legal considerations for premiums, claims, assets and insurance transactions with cross-border elements.',
 $content$
Insurance transactions may involve foreign currency, overseas property, international carriage, non-resident parties or claims paid outside India. These features bring foreign-exchange and other laws into the insurance analysis. The policy alone is not sufficient authority to receive, remit or settle money across borders.

Foreign-exchange control

Foreign-exchange law regulates dealings in foreign currency and transactions between residents and non-residents. Operational rules may be implemented through the central bank, authorised dealers and specific permissions or general directions. The relevant questions include the residence of the parties, location of risk, currency of premium and claim, place of payment, supporting documents and whether approval or reporting is required.

Marine, travel and overseas interests

Marine cargo and hull policies often connect several countries. Travel and overseas medical covers may require payments to foreign service providers. Multinational programmes may combine local policies with global arrangements. In each case, insurance validity, tax, foreign-exchange compliance and local compulsory insurance rules may differ.

Other applicable laws

General insurance work can also engage:

- contract law for formation, interpretation and remedies;
- company and insolvency law for corporate authority and financial distress;
- evidence and limitation rules for proof and time bars;
- taxation and stamp requirements for premiums and documents;
- sanctions, anti-money-laundering and know-your-customer controls;
- data-protection and confidentiality duties;
- transport, carriage, maritime and aviation law; and
- sector-specific safety or liability legislation.

Compliance workflow

Before handling a cross-border transaction, establish who is paying whom, in what currency, for which insurable interest, under which policy, and with what documentary authority. Confirm the current official rule and route regulated payments through the permitted channel. Retain proposal, invoice, policy, premium, claim and remittance evidence so that the transaction can be audited.

The examination principle is coordination: insurance professionals do not replace legal or foreign-exchange specialists, but they must recognise when another legal regime applies and obtain the necessary approval before committing cover or funds.
$content$, 18, 1),
('IC11-C01-T04', 'REVISION_NOTE', 'LR-IC11-C01-T04-002',
 'Quick Revision: Exchange Control and Other Laws',
 'Cross-border insurance questions, related legal regimes and a practical compliance workflow.',
 $content$
Quick Revision Points

1. A policy does not by itself authorise a foreign-currency payment.
2. Residence, risk location, currency and payment destination affect exchange-control analysis.
3. Authorised channels, documents, reporting or approval may be required.
4. Marine, travel and multinational insurance commonly create cross-border questions.
5. Local compulsory insurance rules may still apply within a global programme.
6. Contract, company, tax, evidence and limitation laws may affect insurance transactions.
7. AML, sanctions, KYC and data duties are part of operational compliance.
8. Transport, maritime and aviation laws can affect both liability and recovery rights.
9. Escalate specialist legal questions rather than assuming the policy resolves them.
10. Preserve documents supporting premium, cover, claim and remittance.

Exam Focus

- Identify the facts needed before an overseas premium or claim payment.
- Give examples of non-insurance laws that affect general insurance.
- Explain why a multinational programme may still need local compliance.

Memory Line

Identify the parties, place, currency, authority and evidence.
$content$, 6, 2);

INSERT INTO public.learning_resources (
    subject_id, module_id, chapter_id, topic_id, resource_type_id,
    code, title, short_description, content, external_url,
    attachment_path, author_name, version_no, estimated_read_minutes,
    display_order, is_exam_relevant, is_premium, is_active
)
SELECT
    subject_record.id, module_record.id, chapter_record.id, topic_record.id,
    resource_type.id, seed.code, seed.title, seed.short_description, seed.content,
    NULL, NULL, 'InsureGPTE Editorial Team', 1, seed.estimated_read_minutes,
    seed.display_order, true, false, true
FROM ic11_c01_resource_seed AS seed
JOIN public.subjects AS subject_record
  ON pg_catalog.upper(subject_record.code) = 'IC11'
JOIN public.subject_modules AS module_record
  ON module_record.subject_id = subject_record.id
 AND pg_catalog.upper(module_record.code) = 'IC11-M01'
JOIN public.subject_chapters AS chapter_record
  ON chapter_record.subject_id = subject_record.id
 AND chapter_record.module_id = module_record.id
 AND pg_catalog.upper(chapter_record.code) = 'IC11-C01'
JOIN public.subject_topics AS topic_record
  ON topic_record.subject_id = subject_record.id
 AND topic_record.module_id = module_record.id
 AND topic_record.chapter_id = chapter_record.id
 AND pg_catalog.upper(topic_record.code) = seed.topic_code
JOIN public.learning_resource_types AS resource_type
  ON pg_catalog.upper(resource_type.code) = seed.resource_type_code
WHERE NOT EXISTS (
    SELECT 1 FROM public.learning_resources AS existing
    WHERE pg_catalog.upper(existing.code) = seed.code
);

UPDATE public.learning_resources AS resource_record
SET resource_type_id = resource_type.id,
    title = seed.title,
    short_description = seed.short_description,
    content = seed.content,
    external_url = NULL,
    attachment_path = NULL,
    author_name = 'InsureGPTE Editorial Team',
    version_no = 1,
    estimated_read_minutes = seed.estimated_read_minutes,
    display_order = seed.display_order,
    is_exam_relevant = true,
    is_premium = false,
    is_active = true,
    updated_at = pg_catalog.clock_timestamp()
FROM ic11_c01_resource_seed AS seed
JOIN public.learning_resource_types AS resource_type
  ON pg_catalog.upper(resource_type.code) = seed.resource_type_code
WHERE pg_catalog.upper(resource_record.code) = seed.code;

DROP TABLE IF EXISTS pg_temp.ic11_c01_flashcard_seed;

CREATE TEMPORARY TABLE ic11_c01_flashcard_seed (
    topic_code text NOT NULL,
    code text PRIMARY KEY,
    question text NOT NULL,
    answer text NOT NULL,
    explanation text NOT NULL,
    display_order integer NOT NULL,
    difficulty_level text NOT NULL
) ON COMMIT PRESERVE ROWS;

INSERT INTO ic11_c01_flashcard_seed VALUES
('IC11-C01-T01', 'FC-IC11-C01-T01-001', 'Why does insurance require special regulation?',
 'Premium is received before the uncertain future cost of claims is known, so supervision protects financial soundness, fair treatment and confidence in the promise to pay.',
 'The time gap and information imbalance distinguish insurance from an ordinary immediate exchange.', 1, 'foundation'),
('IC11-C01-T01', 'FC-IC11-C01-T01-002', 'What is the difference between primary legislation and an insurance regulation?',
 'Primary legislation establishes powers and mandatory duties; a regulation supplies detailed rules under authority granted by that legislation.',
 'The regulation must remain within the enabling statute and cannot override it.', 2, 'foundation'),
('IC11-C01-T01', 'FC-IC11-C01-T01-003', 'Can a policy condition override a mandatory statute?',
 'No. Contractual wording operates subject to mandatory law.',
 'The policy defines agreed cover, but parties cannot contract out of a legal rule that is compulsory.', 3, 'foundation'),

('IC11-C01-T02', 'FC-IC11-C01-T02-001', 'Why is incorporation not enough to carry on insurance business?',
 'Insurance business also requires the registration or authority prescribed by insurance law.',
 'The regulator assesses financial, governance and operational fitness before and during business.', 1, 'foundation'),
('IC11-C01-T02', 'FC-IC11-C01-T02-002', 'How can under-reserving affect an insurer?',
 'It can overstate current profit and leave insufficient funds for future claims, weakening solvency.',
 'Insurance costs are delayed and uncertain, so prudent estimates are essential.', 2, 'intermediate'),
('IC11-C01-T02', 'FC-IC11-C01-T02-003', 'What is the difference between registration and continuing supervision?',
 'Registration permits market entry; continuing supervision monitors whether the insurer remains compliant and financially sound.',
 'Authority is not a once-only exercise because liabilities and business practices change over time.', 3, 'intermediate'),

('IC11-C01-T03', 'FC-IC11-C01-T03-001', 'How does compulsory motor third-party cover differ from own-damage cover?',
 'Third-party cover protects against specified legal liability to others and is compulsory; own-damage cover protects the insured vehicle and is generally optional.',
 'A package policy may contain both, but their purpose and legal basis differ.', 1, 'foundation'),
('IC11-C01-T03', 'FC-IC11-C01-T03-002', 'Does legal liability automatically mean the insurer must pay the full amount?',
 'No. The liability must also fall within the policy grant, period, limits and conditions and not be excluded.',
 'Law creates the underlying duty; the insurance contract defines the insured response.', 2, 'intermediate'),
('IC11-C01-T03', 'FC-IC11-C01-T03-003', 'Why must consumer-forum limits be checked against current official law?',
 'Pecuniary limits, procedures and appeal rules can be amended after a course book is published.',
 'The legal concept remains examinable, but operational advice must use the effective rule.', 3, 'intermediate'),

('IC11-C01-T04', 'FC-IC11-C01-T04-001', 'What facts are central to a foreign-exchange review of an insurance transaction?',
 'The parties and their residence, location of risk, currency, payment destination, insurable interest and supporting authority.',
 'These facts determine which exchange-control route, documents or approvals may apply.', 1, 'intermediate'),
('IC11-C01-T04', 'FC-IC11-C01-T04-002', 'Why may a multinational insurance programme still require local policies?',
 'Local compulsory insurance, licensing, tax, exchange-control or policy-issuance rules may apply where the risk is located.',
 'A global arrangement does not automatically displace mandatory local law.', 2, 'advanced'),
('IC11-C01-T04', 'FC-IC11-C01-T04-003', 'Name four non-insurance legal areas that can affect general insurance.',
 'Contract, taxation, foreign exchange and limitation law are examples; company, evidence, sanctions, data and transport laws may also apply.',
 'Insurance professionals must recognise connected legal regimes and escalate specialist questions.', 3, 'intermediate');

INSERT INTO public.flashcards (
    subject_id, module_id, chapter_id, topic_id, code, question, answer,
    explanation, display_order, difficulty_level, is_exam_relevant, is_active
)
SELECT
    subject_record.id, module_record.id, chapter_record.id, topic_record.id,
    seed.code, seed.question, seed.answer, seed.explanation,
    seed.display_order, seed.difficulty_level, true, true
FROM ic11_c01_flashcard_seed AS seed
JOIN public.subjects AS subject_record
  ON pg_catalog.upper(subject_record.code) = 'IC11'
JOIN public.subject_modules AS module_record
  ON module_record.subject_id = subject_record.id
 AND pg_catalog.upper(module_record.code) = 'IC11-M01'
JOIN public.subject_chapters AS chapter_record
  ON chapter_record.subject_id = subject_record.id
 AND chapter_record.module_id = module_record.id
 AND pg_catalog.upper(chapter_record.code) = 'IC11-C01'
JOIN public.subject_topics AS topic_record
  ON topic_record.subject_id = subject_record.id
 AND topic_record.module_id = module_record.id
 AND topic_record.chapter_id = chapter_record.id
 AND pg_catalog.upper(topic_record.code) = seed.topic_code
WHERE NOT EXISTS (
    SELECT 1 FROM public.flashcards AS existing
    WHERE pg_catalog.upper(existing.code) = seed.code
);

UPDATE public.flashcards AS flashcard_record
SET question = seed.question,
    answer = seed.answer,
    explanation = seed.explanation,
    display_order = seed.display_order,
    difficulty_level = seed.difficulty_level,
    is_exam_relevant = true,
    is_active = true,
    updated_at = pg_catalog.clock_timestamp()
FROM ic11_c01_flashcard_seed AS seed
WHERE pg_catalog.upper(flashcard_record.code) = seed.code;

DO $verify$
DECLARE
    v_chapter_id integer;
BEGIN
    SELECT chapter_record.id
    INTO v_chapter_id
    FROM public.subjects AS subject_record
    JOIN public.subject_chapters AS chapter_record
      ON chapter_record.subject_id = subject_record.id
    WHERE pg_catalog.upper(subject_record.code) = 'IC11'
      AND pg_catalog.upper(chapter_record.code) = 'IC11-C01';

    IF (
        SELECT pg_catalog.count(*) FROM public.learning_resources AS resource_record
        WHERE resource_record.chapter_id = v_chapter_id AND resource_record.is_active = true
    ) <> 8 THEN
        RAISE EXCEPTION 'Expected exactly 8 active IC11 Chapter 1 resources.';
    END IF;

    IF (
        SELECT pg_catalog.count(*) FROM public.flashcards AS flashcard_record
        WHERE flashcard_record.chapter_id = v_chapter_id AND flashcard_record.is_active = true
    ) <> 12 THEN
        RAISE EXCEPTION 'Expected exactly 12 active IC11 Chapter 1 flashcards.';
    END IF;
END;
$verify$;

DROP TABLE IF EXISTS pg_temp.ic11_c01_flashcard_seed;
DROP TABLE IF EXISTS pg_temp.ic11_c01_resource_seed;

COMMIT;
