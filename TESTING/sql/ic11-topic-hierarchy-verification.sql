-- Verify the IC11 topic hierarchy after all IC11 migrations are ready to deploy.

with expected_counts(chapter_code, expected_topics) as (
  values
    ('IC11-C01', 4),
    ('IC11-C02', 4),
    ('IC11-C03', 4),
    ('IC11-C04', 5),
    ('IC11-C05', 5),
    ('IC11-C06', 4),
    ('IC11-C07', 6),
    ('IC11-C08', 6),
    ('IC11-C09', 5)
)
select
  chapter_record.code as chapter_code,
  chapter_record.title as chapter_title,
  expected_counts.expected_topics,
  pg_catalog.count(distinct topic_record.id) filter (
    where topic_record.is_active = true
  ) as active_topics,
  pg_catalog.count(distinct resource_record.id) filter (
    where resource_record.is_active = true
  ) as active_resources,
  pg_catalog.count(distinct flashcard_record.id) filter (
    where flashcard_record.is_active = true
  ) as active_flashcards
from expected_counts
join public.subjects as subject_record
  on pg_catalog.upper(subject_record.code) = 'IC11'
join public.subject_chapters as chapter_record
  on chapter_record.subject_id = subject_record.id
 and pg_catalog.upper(chapter_record.code) = expected_counts.chapter_code
left join public.subject_topics as topic_record
  on topic_record.chapter_id = chapter_record.id
left join public.learning_resources as resource_record
  on resource_record.topic_id = topic_record.id
left join public.flashcards as flashcard_record
  on flashcard_record.topic_id = topic_record.id
group by chapter_record.code, chapter_record.title, expected_counts.expected_topics
order by chapter_record.code;
