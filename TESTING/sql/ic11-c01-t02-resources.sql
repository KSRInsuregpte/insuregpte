-- IC11 Chapter 1 resources for IC11-C01-T02; two active resources expected.
WITH resource_seed (
    topic_code, resource_type_code, code, title, short_description, content,
    estimated_read_minutes, display_order
) AS (
VALUES
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
$content$, 6, 2)
)
INSERT INTO public.learning_resources (
    subject_id, module_id, chapter_id, topic_id, resource_type_id,
    code, title, short_description, content, external_url, attachment_path,
    author_name, version_no, estimated_read_minutes, display_order,
    is_exam_relevant, is_premium, is_active
)
SELECT
    topic_record.subject_id, topic_record.module_id, topic_record.chapter_id,
    topic_record.id, resource_type.id, seed.code, seed.title,
    seed.short_description, seed.content, NULL, NULL,
    'InsureGPTE Editorial Team', 1, seed.estimated_read_minutes,
    seed.display_order, true, false, true
FROM resource_seed AS seed
JOIN public.subject_topics AS topic_record
  ON topic_record.subject_id = 2
 AND topic_record.chapter_id = 10
 AND topic_record.code = seed.topic_code
 AND topic_record.is_active = true
JOIN public.learning_resource_types AS resource_type
  ON resource_type.code = seed.resource_type_code
 AND resource_type.is_active = true
WHERE NOT EXISTS (
    SELECT 1
    FROM public.learning_resources AS existing
    WHERE pg_catalog.upper(existing.code) = pg_catalog.upper(seed.code)
)
RETURNING code, topic_id, resource_type_id, display_order, is_active;
