select
  topic_record.code as topic_code,
  topic_record.title as topic_title,
  pg_catalog.count(distinct resource_record.id) filter (
    where resource_record.is_active = true
  ) as active_resources,
  pg_catalog.count(distinct flashcard_record.id) filter (
    where flashcard_record.is_active = true
  ) as active_flashcards,
  pg_catalog.jsonb_agg(distinct resource_type_record.code) filter (
    where resource_record.is_active = true
  ) as resource_types,
  pg_catalog.bool_and(
    pg_catalog.char_length(pg_catalog.btrim(resource_record.content)) >= 250
  ) filter (where resource_record.is_active = true) as resources_have_content
from public.subject_topics as topic_record
join public.subjects as subject_record
  on subject_record.id = topic_record.subject_id
join public.subject_chapters as chapter_record
  on chapter_record.id = topic_record.chapter_id
left join public.learning_resources as resource_record
  on resource_record.topic_id = topic_record.id
left join public.learning_resource_types as resource_type_record
  on resource_type_record.id = resource_record.resource_type_id
left join public.flashcards as flashcard_record
  on flashcard_record.topic_id = topic_record.id
where pg_catalog.upper(subject_record.code) = 'IC11'
  and pg_catalog.upper(chapter_record.code) = 'IC11-C01'
  and topic_record.is_active = true
group by topic_record.code, topic_record.title, topic_record.display_order
order by topic_record.display_order;
