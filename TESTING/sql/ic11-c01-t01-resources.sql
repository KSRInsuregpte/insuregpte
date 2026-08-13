-- IC11 Chapter 1 resources for IC11-C01-T01; two active resources expected.
WITH resource_seed (
    topic_code, resource_type_code, code, title, short_description, content,
    estimated_read_minutes, display_order
) AS (
VALUES
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
