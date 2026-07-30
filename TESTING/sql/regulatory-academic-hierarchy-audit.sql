-- InsureGPTE live academic-hierarchy and examination-information audit.
-- Run in the Supabase SQL editor and export the single result grid as CSV.
-- This script reads object metadata and non-personal academic catalogue rows only.

with
required_relations(object_name) as (
  values
    ('qualification_levels'),
    ('exam_authorities'),
    ('training_programmes'),
    ('programme_sections'),
    ('subjects'),
    ('learning_resource_types'),
    ('learning_resources'),
    ('questions'),
    ('carts'),
    ('cart_items'),
    ('user_entitlements')
),
required_relation_status as (
  select
    '01_required_relation'::text as audit_section,
    required_relations.object_name::text as object_name,
    jsonb_build_object(
      'exists',
      to_regclass(format('public.%I', required_relations.object_name)) is not null,
      'qualified_name',
      format('public.%I', required_relations.object_name)
    ) as details
  from required_relations
),
required_column_inventory as (
  select
    '02_required_columns'::text as audit_section,
    required_relations.object_name::text as object_name,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'position', columns.ordinal_position,
          'name', columns.column_name,
          'data_type', columns.data_type,
          'nullable', columns.is_nullable
        )
        order by columns.ordinal_position
      ) filter (where columns.column_name is not null),
      '[]'::jsonb
    ) as details
  from required_relations
  left join information_schema.columns as columns
    on columns.table_schema = 'public'
   and columns.table_name = required_relations.object_name
  group by required_relations.object_name
),
candidate_relations as (
  select
    '03_session_relation_candidates'::text as audit_section,
    'public'::text as object_name,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'name', classes.relname,
          'kind',
          case classes.relkind
            when 'r' then 'table'
            when 'p' then 'partitioned_table'
            when 'v' then 'view'
            when 'm' then 'materialized_view'
            when 'f' then 'foreign_table'
            else classes.relkind::text
          end
        )
        order by classes.relname
      ) filter (where classes.oid is not null),
      '[]'::jsonb
    ) as details
  from pg_catalog.pg_namespace as namespaces
  left join pg_catalog.pg_class as classes
    on classes.relnamespace = namespaces.oid
   and classes.relkind in ('r', 'p', 'v', 'm', 'f')
   and classes.relname ~* '(exam|session|schedule|calendar|centre|center|regulat|amendment|notice|timetable)'
  where namespaces.nspname = 'public'
),
candidate_functions as (
  select
    '04_session_function_candidates'::text as audit_section,
    'public'::text as object_name,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'name', procedures.proname,
          'arguments', pg_get_function_identity_arguments(procedures.oid),
          'result', pg_get_function_result(procedures.oid),
          'security_definer', procedures.prosecdef,
          'volatility', procedures.provolatile
        )
        order by procedures.proname, pg_get_function_identity_arguments(procedures.oid)
      ) filter (where procedures.oid is not null),
      '[]'::jsonb
    ) as details
  from pg_catalog.pg_namespace as namespaces
  left join pg_catalog.pg_proc as procedures
    on procedures.pronamespace = namespaces.oid
   and procedures.proname ~* '(exam|session|schedule|calendar|centre|center|regulat|amendment|notice|timetable)'
  where namespaces.nspname = 'public'
),
reserved_rpc_names(rpc_name) as (
  values
    ('get_exam_information'),
    ('get_exam_session_information'),
    ('get_regulatory_subject_metadata')
),
reserved_rpc_status as (
  select
    '05_proposed_rpc_conflicts'::text as audit_section,
    reserved_rpc_names.rpc_name::text as object_name,
    jsonb_build_object(
      'exists',
      exists (
        select 1
        from pg_catalog.pg_proc as procedures
        join pg_catalog.pg_namespace as namespaces
          on namespaces.oid = procedures.pronamespace
        where namespaces.nspname = 'public'
          and procedures.proname = reserved_rpc_names.rpc_name
      ),
      'signatures',
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'arguments', pg_get_function_identity_arguments(procedures.oid),
              'result', pg_get_function_result(procedures.oid)
            )
            order by pg_get_function_identity_arguments(procedures.oid)
          )
          from pg_catalog.pg_proc as procedures
          join pg_catalog.pg_namespace as namespaces
            on namespaces.oid = procedures.pronamespace
          where namespaces.nspname = 'public'
            and procedures.proname = reserved_rpc_names.rpc_name
        ),
        '[]'::jsonb
      )
    ) as details
  from reserved_rpc_names
),
qualification_level_rows as (
  select
    '06_hierarchy_rows'::text as audit_section,
    'qualification_levels'::text as object_name,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', levels.id,
          'code', levels.code,
          'name', levels.name,
          'display_order', levels.display_order,
          'is_active', levels.is_active
        )
        order by levels.display_order, levels.code
      ),
      '[]'::jsonb
    ) as details
  from public.qualification_levels as levels
),
exam_authority_rows as (
  select
    '06_hierarchy_rows'::text as audit_section,
    'exam_authorities'::text as object_name,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', authorities.id,
          'code', authorities.code,
          'name', authorities.name,
          'short_name', authorities.short_name,
          'official_website', authorities.official_website,
          'display_order', authorities.display_order,
          'is_active', authorities.is_active
        )
        order by authorities.display_order, authorities.code
      ),
      '[]'::jsonb
    ) as details
  from public.exam_authorities as authorities
),
training_programme_rows as (
  select
    '06_hierarchy_rows'::text as audit_section,
    'training_programmes'::text as object_name,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', programmes.id,
          'exam_authority_id', programmes.exam_authority_id,
          'code', programmes.code,
          'name', programmes.name,
          'programme_category', programmes.programme_category,
          'official_pass_percentage', programmes.official_pass_percentage,
          'recommended_readiness_percentage', programmes.recommended_readiness_percentage,
          'exam_question_count', programmes.exam_question_count,
          'exam_duration_minutes', programmes.exam_duration_minutes,
          'display_order', programmes.display_order,
          'is_active', programmes.is_active
        )
        order by programmes.display_order, programmes.code
      ),
      '[]'::jsonb
    ) as details
  from public.training_programmes as programmes
),
programme_section_rows as (
  select
    '06_hierarchy_rows'::text as audit_section,
    'programme_sections'::text as object_name,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', sections.id,
          'training_programme_id', sections.training_programme_id,
          'code', sections.code,
          'name', sections.name,
          'exam_question_count', sections.exam_question_count,
          'recommended_practice_question_count', sections.recommended_practice_question_count,
          'display_order', sections.display_order,
          'is_active', sections.is_active
        )
        order by sections.training_programme_id, sections.display_order, sections.code
      ),
      '[]'::jsonb
    ) as details
  from public.programme_sections as sections
),
pilot_subject_rows as (
  select
    '07_pilot_subject_mapping'::text as audit_section,
    'IC01_IC02_IC11_IC14_IC23_IC82'::text as object_name,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', subjects.id,
          'code', subjects.code,
          'normalized_code', regexp_replace(upper(subjects.code), '[^A-Z0-9]', '', 'g'),
          'title', subjects.title,
          'qualification_level_id', subjects.qualification_level_id,
          'training_programme_id', subjects.training_programme_id,
          'programme_section_id', subjects.programme_section_id,
          'category', subjects.category,
          'syllabus_version', subjects.syllabus_version,
          'demo_question_limit', subjects.demo_question_limit,
          'price', subjects.price,
          'currency_code', subjects.currency_code,
          'is_demo_available', subjects.is_demo_available,
          'is_active', subjects.is_active
        )
        order by regexp_replace(upper(subjects.code), '[^A-Z0-9]', '', 'g'), subjects.id
      ),
      '[]'::jsonb
    ) as details
  from public.subjects as subjects
  where regexp_replace(upper(subjects.code), '[^A-Z0-9]', '', 'g')
    in ('IC01', 'IC02', 'IC11', 'IC14', 'IC23', 'IC82')
),
pilot_subject_cardinality as (
  select
    '08_pilot_subject_cardinality'::text as audit_section,
    normalized_codes.normalized_code::text as object_name,
    jsonb_build_object(
      'row_count', count(subjects.id),
      'subject_ids', coalesce(jsonb_agg(subjects.id order by subjects.id) filter (where subjects.id is not null), '[]'::jsonb),
      'stored_codes', coalesce(jsonb_agg(subjects.code order by subjects.id) filter (where subjects.id is not null), '[]'::jsonb)
    ) as details
  from (
    values ('IC01'), ('IC02'), ('IC11'), ('IC14'), ('IC23'), ('IC82')
  ) as normalized_codes(normalized_code)
  left join public.subjects as subjects
    on regexp_replace(upper(subjects.code), '[^A-Z0-9]', '', 'g') = normalized_codes.normalized_code
  group by normalized_codes.normalized_code
),
learning_resource_type_rows as (
  select
    '09_learning_resource_types'::text as audit_section,
    'learning_resource_types'::text as object_name,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', resource_types.id,
          'code', resource_types.code,
          'name', resource_types.name,
          'display_order', resource_types.display_order,
          'is_active', resource_types.is_active
        )
        order by resource_types.display_order, resource_types.code
      ),
      '[]'::jsonb
    ) as details
  from public.learning_resource_types as resource_types
),
pilot_learning_resource_counts as (
  select
    '10_pilot_learning_resource_counts'::text as audit_section,
    subjects.code::text as object_name,
    jsonb_build_object(
      'subject_id', subjects.id,
      'active_count', count(resources.id) filter (where resources.is_active),
      'inactive_count', count(resources.id) filter (where not resources.is_active),
      'resource_type_ids',
      coalesce(
        jsonb_agg(distinct resources.resource_type_id) filter (where resources.resource_type_id is not null),
        '[]'::jsonb
      )
    ) as details
  from public.subjects as subjects
  left join public.learning_resources as resources
    on resources.subject_id = subjects.id
  where regexp_replace(upper(subjects.code), '[^A-Z0-9]', '', 'g')
    in ('IC01', 'IC02', 'IC11', 'IC14', 'IC23', 'IC82')
  group by subjects.id, subjects.code
)
select audit_section, object_name, details
from (
  select * from required_relation_status
  union all
  select * from required_column_inventory
  union all
  select * from candidate_relations
  union all
  select * from candidate_functions
  union all
  select * from reserved_rpc_status
  union all
  select * from qualification_level_rows
  union all
  select * from exam_authority_rows
  union all
  select * from training_programme_rows
  union all
  select * from programme_section_rows
  union all
  select * from pilot_subject_rows
  union all
  select * from pilot_subject_cardinality
  union all
  select * from learning_resource_type_rows
  union all
  select * from pilot_learning_resource_counts
) as audit_rows
order by audit_section, object_name;
