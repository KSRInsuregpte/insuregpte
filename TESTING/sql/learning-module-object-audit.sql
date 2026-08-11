-- InsureGPTE Learning Module live-object audit.
-- Run this single read-only statement in the trial Supabase SQL editor and
-- export the result grid as CSV. It returns schema metadata, grants, function
-- definitions, and approximate row counts only. It does not return learner
-- identities, learning history, resource content, or flashcard text.

with
required_relations(object_schema, object_name) as (
  values
    ('public', 'profiles'),
    ('public', 'subjects'),
    ('public', 'subject_modules'),
    ('public', 'subject_chapters'),
    ('public', 'subject_topics'),
    ('public', 'learning_resource_types'),
    ('public', 'learning_resources'),
    ('public', 'flashcards'),
    ('public', 'user_entitlements'),
    ('public', 'user_topic_progress'),
    ('public', 'user_learning_activity')
),
planned_functions(function_name) as (
  values
    ('get_subject_hierarchy'),
    ('get_modules_by_subject'),
    ('get_chapters_by_module'),
    ('get_topics_by_chapter'),
    ('get_learning_resources'),
    ('get_flashcards'),
    ('get_topic_details'),
    ('record_learning_activity'),
    ('get_resume_learning'),
    ('get_recent_activity'),
    ('get_topic_completion'),
    ('get_learning_statistics')
),
relation_status as (
  select
    '01_required_relations'::text as audit_section,
    format('%I.%I', required.object_schema, required.object_name)::text
      as object_name,
    jsonb_build_object(
      'exists', classes.oid is not null,
      'relation_kind',
        case classes.relkind
          when 'r' then 'table'
          when 'p' then 'partitioned_table'
          when 'v' then 'view'
          when 'm' then 'materialized_view'
          when 'f' then 'foreign_table'
          else classes.relkind::text
        end,
      'rls_enabled', coalesce(classes.relrowsecurity, false),
      'rls_forced', coalesce(classes.relforcerowsecurity, false),
      'approximate_rows',
        case when classes.relkind in ('r', 'p') then classes.reltuples else null end
    ) as details
  from required_relations as required
  left join pg_catalog.pg_namespace as namespaces
    on namespaces.nspname = required.object_schema
  left join pg_catalog.pg_class as classes
    on classes.relnamespace = namespaces.oid
   and classes.relname = required.object_name
   and classes.relkind in ('r', 'p', 'v', 'm', 'f')
),
column_inventory as (
  select
    '02_columns'::text as audit_section,
    format('%I.%I', required.object_schema, required.object_name)::text
      as object_name,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'position', columns.ordinal_position,
          'name', columns.column_name,
          'data_type', columns.data_type,
          'udt_name', columns.udt_name,
          'nullable', columns.is_nullable,
          'default', columns.column_default
        )
        order by columns.ordinal_position
      ) filter (where columns.column_name is not null),
      '[]'::jsonb
    ) as details
  from required_relations as required
  left join information_schema.columns as columns
    on columns.table_schema = required.object_schema
   and columns.table_name = required.object_name
  group by required.object_schema, required.object_name
),
constraint_inventory as (
  select
    '03_constraints'::text as audit_section,
    required.object_name::text as object_name,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'name', constraints.conname,
          'type', constraints.contype,
          'validated', constraints.convalidated,
          'definition', pg_catalog.pg_get_constraintdef(constraints.oid, true)
        )
        order by constraints.conname
      ) filter (where constraints.oid is not null),
      '[]'::jsonb
    ) as details
  from required_relations as required
  left join pg_catalog.pg_namespace as namespaces
    on namespaces.nspname = required.object_schema
  left join pg_catalog.pg_class as classes
    on classes.relnamespace = namespaces.oid
   and classes.relname = required.object_name
  left join pg_catalog.pg_constraint as constraints
    on constraints.conrelid = classes.oid
  group by required.object_name
),
index_inventory as (
  select
    '04_indexes'::text as audit_section,
    required.object_name::text as object_name,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'name', indexes.indexname,
          'definition', indexes.indexdef
        )
        order by indexes.indexname
      ) filter (where indexes.indexname is not null),
      '[]'::jsonb
    ) as details
  from required_relations as required
  left join pg_catalog.pg_indexes as indexes
    on indexes.schemaname = required.object_schema
   and indexes.tablename = required.object_name
  group by required.object_name
),
policy_inventory as (
  select
    '05_rls_policies'::text as audit_section,
    required.object_name::text as object_name,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'name', policies.policyname,
          'permissive', policies.permissive,
          'roles', policies.roles,
          'command', policies.cmd,
          'using', policies.qual,
          'check', policies.with_check
        )
        order by policies.policyname
      ) filter (where policies.policyname is not null),
      '[]'::jsonb
    ) as details
  from required_relations as required
  left join pg_catalog.pg_policies as policies
    on policies.schemaname = required.object_schema
   and policies.tablename = required.object_name
  group by required.object_name
),
relation_grants as (
  select
    '06_browser_relation_grants'::text as audit_section,
    format('%I.%I', required.object_schema, required.object_name)::text
      as object_name,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'grantee', grants.grantee,
          'privilege', grants.privilege_type,
          'grantable', grants.is_grantable
        )
        order by grants.grantee, grants.privilege_type
      ) filter (where grants.grantee is not null),
      '[]'::jsonb
    ) as details
  from required_relations as required
  left join information_schema.role_table_grants as grants
    on grants.table_schema = required.object_schema
   and grants.table_name = required.object_name
   and grants.grantee in ('anon', 'authenticated')
  group by required.object_schema, required.object_name
),
planned_function_status as (
  select
    '07_planned_function_status'::text as audit_section,
    planned.function_name::text as object_name,
    jsonb_build_object(
      'exists', count(procedures.oid) > 0,
      'signatures',
        coalesce(
          jsonb_agg(
            jsonb_build_object(
              'arguments',
                pg_catalog.pg_get_function_identity_arguments(procedures.oid),
              'result', pg_catalog.pg_get_function_result(procedures.oid),
              'security_definer', procedures.prosecdef,
              'volatility', procedures.provolatile,
              'anon_execute',
                pg_catalog.has_function_privilege('anon', procedures.oid, 'EXECUTE'),
              'authenticated_execute',
                pg_catalog.has_function_privilege(
                  'authenticated', procedures.oid, 'EXECUTE'
                ),
              'definition',
                case
                  when procedures.prokind = 'f'
                    then pg_catalog.pg_get_functiondef(procedures.oid)
                  else null
                end
            )
            order by pg_catalog.pg_get_function_identity_arguments(procedures.oid)
          ) filter (where procedures.oid is not null),
          '[]'::jsonb
        )
    ) as details
  from planned_functions as planned
  left join pg_catalog.pg_namespace as namespaces
    on namespaces.nspname = 'public'
  left join pg_catalog.pg_proc as procedures
    on procedures.pronamespace = namespaces.oid
   and procedures.proname = planned.function_name
   and procedures.prokind = 'f'
  group by planned.function_name
),
related_function_inventory as (
  select
    '08_related_function_inventory'::text as audit_section,
    procedures.proname::text as object_name,
    jsonb_build_object(
      'arguments', pg_catalog.pg_get_function_identity_arguments(procedures.oid),
      'result', pg_catalog.pg_get_function_result(procedures.oid),
      'security_definer', procedures.prosecdef,
      'volatility', procedures.provolatile,
      'anon_execute',
        pg_catalog.has_function_privilege('anon', procedures.oid, 'EXECUTE'),
      'authenticated_execute',
        pg_catalog.has_function_privilege(
          'authenticated', procedures.oid, 'EXECUTE'
        ),
      'definition',
        case
          when procedures.prokind = 'f'
            then pg_catalog.pg_get_functiondef(procedures.oid)
          else null
        end
    ) as details
  from pg_catalog.pg_proc as procedures
  join pg_catalog.pg_namespace as namespaces
    on namespaces.oid = procedures.pronamespace
  where namespaces.nspname = 'public'
    and procedures.prokind = 'f'
    and (
      procedures.proname ~* '(learn|progress|module|chapter|topic|flashcard|resource)'
      or (
        case
          when procedures.prokind = 'f'
            then pg_catalog.pg_get_functiondef(procedures.oid)
          else null
        end
      ) ~* '(subject_modules|subject_chapters|subject_topics|learning_resources|flashcards|user_topic_progress|user_learning_activity)'
    )
)
select audit_section, object_name, details
from relation_status
union all
select audit_section, object_name, details
from column_inventory
union all
select audit_section, object_name, details
from constraint_inventory
union all
select audit_section, object_name, details
from index_inventory
union all
select audit_section, object_name, details
from policy_inventory
union all
select audit_section, object_name, details
from relation_grants
union all
select audit_section, object_name, details
from planned_function_status
union all
select audit_section, object_name, details
from related_function_inventory
order by audit_section, object_name;
