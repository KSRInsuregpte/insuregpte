-- IC11 IC11-C02: two resources for each active topic.
WITH content_seed (topic_code, learning_focus, study_method, exam_focus) AS (
VALUES
('IC11-C02-T01', 'market evolution; public and private insurers; specialised participants; regulatory structure; market segmentation', 'Build a timeline, then group institutions by the insurance function they perform.', 'Explain the market structure and distinguish insurer, regulator and specialised institution.'),
('IC11-C02-T02', 'general insurers; standalone health insurers; reinsurers; agriculture insurance; export credit; government insurance arrangements', 'Compare each institution by ownership, customer, risk class and source of capacity.', 'Match an institution to its principal purpose and identify when specialist capacity is needed.'),
('IC11-C02-T03', 'agents; corporate agents; brokers; third-party administrators; surveyors; loss assessors', 'Use a responsibility matrix covering solicitation, advice, servicing, administration and loss assessment.', 'Distinguish intermediary roles and avoid assigning a regulated function to the wrong participant.'),
('IC11-C02-T04', 'international insurance centres; Lloyd''s market; global insurers; reinsurers; cross-border capacity; complex risks', 'Trace a large risk from the Indian insured through local placement to international capacity.', 'Explain why international insurance and reinsurance markets support large or specialised risks.')
)
INSERT INTO public.learning_resources (
    subject_id, module_id, chapter_id, topic_id, resource_type_id,
    code, title, short_description, content, external_url, attachment_path,
    author_name, version_no, estimated_read_minutes, display_order,
    is_exam_relevant, is_premium, is_active
)
SELECT
    topic_record.subject_id, topic_record.module_id, topic_record.chapter_id,
    topic_record.id, resource_type.id,
    'LR-' || seed.topic_code || '-' ||
        CASE WHEN resource_type.code = 'NOTE' THEN '001' ELSE '002' END,
    CASE WHEN resource_type.code = 'NOTE' THEN topic_record.title
         ELSE 'Quick Revision: ' || topic_record.title END,
    CASE WHEN resource_type.code = 'NOTE' THEN topic_record.description
         ELSE 'Concise examination revision and practical application cues for ' || topic_record.title || '.' END,
    CASE WHEN resource_type.code = 'NOTE' THEN
        topic_record.title || E'\n\nOverview\n\n' || topic_record.description ||
        E'\n\nLearning objective\n\n' || topic_record.learning_objective ||
        E'\n\nCore learning framework\n\nStudy the topic through these connected elements: ' || seed.learning_focus ||
        E'. Do not treat the elements as isolated definitions. Identify the insured interest or legal duty, the event or exposure, the policy or institutional response, the important limitations, and the evidence required to support a decision.\n\nStudy method\n\n' || seed.study_method ||
        E' Consider a simple personal risk and a larger commercial risk, and test how the outcome changes when facts, limits or documents change.\n\nPractical relevance\n\n' || topic_record.practical_relevance ||
        E' A sound practitioner explains the reason for the decision, applies the complete wording or process, records material facts, and escalates technical or legal uncertainty.\n\nCurrent-practice note\n\nNumerical limits, prescribed forms and regulatory procedures may change. Use the course framework for examination preparation and verify time-sensitive requirements against current official sources before operational use.'
    ELSE
        'Quick Revision: ' || topic_record.title || E'\n\nKey scope\n\n' || topic_record.description ||
        E'\n\nRemember\n\n- Purpose: ' || topic_record.learning_objective ||
        E'\n- Core elements: ' || seed.learning_focus ||
        E'.\n- Application: ' || topic_record.practical_relevance ||
        E'\n- Method: ' || seed.study_method ||
        E'\n\nExam focus\n\n' || seed.exam_focus ||
        E' Compare related concepts, state the reason for each control or policy feature, and apply the framework to a short fact situation.\n\nMemory method\n\nIdentify the interest or duty; identify the exposure; identify the response; test limitations; retain evidence.\n\nAccuracy reminder\n\nVerify changeable legal limits, rates, forms and procedures against current official publications.'
    END,
    NULL, NULL, 'InsureGPTE Editorial Team', 1,
    CASE WHEN resource_type.code = 'NOTE' THEN 18 ELSE 6 END,
    CASE WHEN resource_type.code = 'NOTE' THEN 1 ELSE 2 END,
    true, false, true
FROM content_seed AS seed
JOIN public.subject_topics AS topic_record
  ON topic_record.subject_id = 2
 AND topic_record.chapter_id = 11
 AND pg_catalog.upper(topic_record.code) = seed.topic_code
 AND topic_record.is_active = true
CROSS JOIN public.learning_resource_types AS resource_type
WHERE pg_catalog.upper(resource_type.code) IN ('NOTE', 'REVISION_NOTE')
  AND resource_type.is_active = true
  AND NOT EXISTS (
      SELECT 1
      FROM public.learning_resources AS existing
      WHERE pg_catalog.upper(existing.code) =
        'LR-' || seed.topic_code || '-' ||
        CASE WHEN resource_type.code = 'NOTE' THEN '001' ELSE '002' END
  )
RETURNING code, topic_id, resource_type_id, display_order, is_active;
