-- Final IC11 content verification. Expected: 43 topics, 86 resources, 129 flashcards.

select
  chapter_record.code as chapter_code,
  chapter_record.title as chapter_title,
  pg_catalog.count(distinct topic_record.id) filter (
    where topic_record.is_active = true
  ) as active_topics,
  pg_catalog.count(distinct resource_record.id) filter (
    where resource_record.is_active = true
  ) as active_resources,
  pg_catalog.count(distinct flashcard_record.id) filter (
    where flashcard_record.is_active = true
  ) as active_flashcards,
  pg_catalog.bool_and(
    pg_catalog.char_length(pg_catalog.btrim(resource_record.content)) >= 250
  ) filter (where resource_record.is_active = true) as resources_have_content
from public.subjects as subject_record
join public.subject_chapters as chapter_record
  on chapter_record.subject_id = subject_record.id
left join public.subject_topics as topic_record
  on topic_record.chapter_id = chapter_record.id
left join public.learning_resources as resource_record
  on resource_record.topic_id = topic_record.id
left join public.flashcards as flashcard_record
  on flashcard_record.topic_id = topic_record.id
where pg_catalog.upper(subject_record.code) = 'IC11'
  and chapter_record.is_active = true
group by chapter_record.code, chapter_record.title, chapter_record.display_order
order by chapter_record.display_order;
