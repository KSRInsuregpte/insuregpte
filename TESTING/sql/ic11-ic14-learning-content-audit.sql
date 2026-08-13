-- Read-only IC11 and IC14 learning-content audit.
-- Run in the test Supabase project and export the result as CSV.
-- This returns academic and educational content only. It does not read users,
-- profiles, learner progress, activity, entitlements, or quiz attempts.

with
target_subjects as (
  select subject_record.id, subject_record.code, subject_record.title,
         subject_record.description, subject_record.is_active
  from public.subjects as subject_record
  where pg_catalog.upper(subject_record.code) in ('IC11', 'IC14')
),
target_modules as (
  select module_record.*
  from public.subject_modules as module_record
  join target_subjects as subject_record
    on subject_record.id = module_record.subject_id
),
target_chapters as (
  select chapter_record.*
  from public.subject_chapters as chapter_record
  join target_subjects as subject_record
    on subject_record.id = chapter_record.subject_id
),
target_topics as (
  select topic_record.*
  from public.subject_topics as topic_record
  join target_subjects as subject_record
    on subject_record.id = topic_record.subject_id
),
audit_rows as (
  select
    '01_subjects'::text as audit_section,
    subject_record.code::text as object_code,
    pg_catalog.jsonb_build_object(
      'id', subject_record.id,
      'title', subject_record.title,
      'description', subject_record.description,
      'is_active', subject_record.is_active
    ) as details
  from target_subjects as subject_record

  union all

  select
    '02_modules'::text,
    module_record.code::text,
    pg_catalog.jsonb_build_object(
      'id', module_record.id,
      'subject_code', subject_record.code,
      'title', module_record.title,
      'description', module_record.description,
      'display_order', module_record.display_order,
      'is_active', module_record.is_active
    )
  from target_modules as module_record
  join target_subjects as subject_record
    on subject_record.id = module_record.subject_id

  union all

  select
    '03_chapters'::text,
    chapter_record.code::text,
    pg_catalog.jsonb_build_object(
      'id', chapter_record.id,
      'subject_code', subject_record.code,
      'module_code', module_record.code,
      'chapter_number', chapter_record.chapter_number,
      'title', chapter_record.title,
      'description', chapter_record.description,
      'display_order', chapter_record.display_order,
      'is_active', chapter_record.is_active
    )
  from target_chapters as chapter_record
  join target_subjects as subject_record
    on subject_record.id = chapter_record.subject_id
  join target_modules as module_record
    on module_record.id = chapter_record.module_id

  union all

  select
    '04_topics'::text,
    topic_record.code::text,
    pg_catalog.jsonb_build_object(
      'id', topic_record.id,
      'subject_code', subject_record.code,
      'module_code', module_record.code,
      'chapter_code', chapter_record.code,
      'topic_number', topic_record.topic_number,
      'title', topic_record.title,
      'description', topic_record.description,
      'learning_objective', topic_record.learning_objective,
      'practical_relevance', topic_record.practical_relevance,
      'estimated_study_minutes', topic_record.estimated_study_minutes,
      'difficulty_level', topic_record.difficulty_level,
      'display_order', topic_record.display_order,
      'is_exam_relevant', topic_record.is_exam_relevant,
      'is_active', topic_record.is_active
    )
  from target_topics as topic_record
  join target_subjects as subject_record
    on subject_record.id = topic_record.subject_id
  join target_modules as module_record
    on module_record.id = topic_record.module_id
  join target_chapters as chapter_record
    on chapter_record.id = topic_record.chapter_id

  union all

  select
    '05_topic_content_summary'::text,
    topic_record.code::text,
    pg_catalog.jsonb_build_object(
      'subject_code', subject_record.code,
      'chapter_code', chapter_record.code,
      'topic_title', topic_record.title,
      'active_resources', (
        select pg_catalog.count(*)
        from public.learning_resources as resource_record
        where resource_record.topic_id = topic_record.id
          and resource_record.is_active = true
      ),
      'active_flashcards', (
        select pg_catalog.count(*)
        from public.flashcards as flashcard_record
        where flashcard_record.topic_id = topic_record.id
          and flashcard_record.is_active = true
      ),
      'resource_types', (
        select pg_catalog.jsonb_agg(resource_type_codes.code order by resource_type_codes.code)
        from (
          select distinct resource_type_record.code
          from public.learning_resources as resource_record
          join public.learning_resource_types as resource_type_record
            on resource_type_record.id = resource_record.resource_type_id
          where resource_record.topic_id = topic_record.id
            and resource_record.is_active = true
        ) as resource_type_codes
      ),
      'resources_have_content', not exists (
        select 1
        from public.learning_resources as resource_record
        where resource_record.topic_id = topic_record.id
          and resource_record.is_active = true
          and pg_catalog.nullif(pg_catalog.btrim(resource_record.content), '') is null
      )
    )
  from target_topics as topic_record
  join target_subjects as subject_record
    on subject_record.id = topic_record.subject_id
  join target_chapters as chapter_record
    on chapter_record.id = topic_record.chapter_id

  union all

  select
    '06_learning_resources'::text,
    resource_record.code::text,
    pg_catalog.jsonb_build_object(
      'id', resource_record.id,
      'subject_code', subject_record.code,
      'module_code', module_record.code,
      'chapter_code', chapter_record.code,
      'topic_code', topic_record.code,
      'resource_type_code', resource_type_record.code,
      'title', resource_record.title,
      'short_description', resource_record.short_description,
      'content', resource_record.content,
      'external_url', resource_record.external_url,
      'attachment_path', resource_record.attachment_path,
      'author_name', resource_record.author_name,
      'version_no', resource_record.version_no,
      'estimated_read_minutes', resource_record.estimated_read_minutes,
      'display_order', resource_record.display_order,
      'is_exam_relevant', resource_record.is_exam_relevant,
      'is_premium', resource_record.is_premium,
      'is_active', resource_record.is_active
    )
  from public.learning_resources as resource_record
  join target_subjects as subject_record
    on subject_record.id = resource_record.subject_id
  join target_modules as module_record
    on module_record.id = resource_record.module_id
  join target_chapters as chapter_record
    on chapter_record.id = resource_record.chapter_id
  join target_topics as topic_record
    on topic_record.id = resource_record.topic_id
  join public.learning_resource_types as resource_type_record
    on resource_type_record.id = resource_record.resource_type_id

  union all

  select
    '07_flashcards'::text,
    flashcard_record.code::text,
    pg_catalog.jsonb_build_object(
      'id', flashcard_record.id,
      'subject_code', subject_record.code,
      'module_code', module_record.code,
      'chapter_code', chapter_record.code,
      'topic_code', topic_record.code,
      'question', flashcard_record.question,
      'answer', flashcard_record.answer,
      'explanation', flashcard_record.explanation,
      'display_order', flashcard_record.display_order,
      'difficulty_level', flashcard_record.difficulty_level,
      'is_exam_relevant', flashcard_record.is_exam_relevant,
      'is_active', flashcard_record.is_active
    )
  from public.flashcards as flashcard_record
  join target_subjects as subject_record
    on subject_record.id = flashcard_record.subject_id
  join target_modules as module_record
    on module_record.id = flashcard_record.module_id
  join target_chapters as chapter_record
    on chapter_record.id = flashcard_record.chapter_id
  join target_topics as topic_record
    on topic_record.id = flashcard_record.topic_id
)
select audit_section, object_code, details
from audit_rows
order by audit_section, object_code;
