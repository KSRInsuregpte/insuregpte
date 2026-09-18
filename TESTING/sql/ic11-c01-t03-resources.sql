-- IC11 Chapter 1 resources for IC11-C01-T03; two active resources expected.
WITH resource_seed (
    topic_code, resource_type_code, code, title, short_description, content,
    estimated_read_minutes, display_order
) AS (
VALUES
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
