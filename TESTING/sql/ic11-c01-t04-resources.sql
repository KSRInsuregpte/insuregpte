-- IC11 Chapter 1 resources for IC11-C01-T04; two active resources expected.
WITH resource_seed (
    topic_code, resource_type_code, code, title, short_description, content,
    estimated_read_minutes, display_order
) AS (
VALUES
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
