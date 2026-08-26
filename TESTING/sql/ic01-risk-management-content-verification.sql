-- Run after 20260812160000_complete_ic01_risk_management_content.sql.
-- Read-only verification; returns educational content counts only.

SELECT
    topic_record.code AS topic_code,
    topic_record.title AS topic_title,
    count(DISTINCT resource_record.id)
        FILTER (WHERE resource_record.is_active = true) AS active_resources,
    count(DISTINCT flashcard_record.id)
        FILTER (WHERE flashcard_record.is_active = true) AS active_flashcards,
    array_agg(DISTINCT resource_type.code ORDER BY resource_type.code)
        FILTER (WHERE resource_record.is_active = true) AS resource_types,
    bool_and(
        resource_record.content IS NOT NULL
        AND pg_catalog.char_length(pg_catalog.btrim(resource_record.content)) >= 250
    ) FILTER (WHERE resource_record.is_active = true) AS resources_have_content
FROM public.subject_topics AS topic_record
JOIN public.subjects AS subject_record
  ON subject_record.id = topic_record.subject_id
JOIN public.subject_chapters AS chapter_record
  ON chapter_record.id = topic_record.chapter_id
LEFT JOIN public.learning_resources AS resource_record
  ON resource_record.topic_id = topic_record.id
LEFT JOIN public.learning_resource_types AS resource_type
  ON resource_type.id = resource_record.resource_type_id
LEFT JOIN public.flashcards AS flashcard_record
  ON flashcard_record.topic_id = topic_record.id
WHERE pg_catalog.upper(subject_record.code) = 'IC01'
  AND pg_catalog.upper(chapter_record.code) = 'IC01-C01'
  AND topic_record.is_active = true
GROUP BY topic_record.id, topic_record.code, topic_record.title,
         topic_record.display_order
ORDER BY topic_record.display_order;
