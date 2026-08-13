-- Read-only audit for database objects invoked when public.subject_topics is written.
-- Use this only to diagnose ERROR 42P01: relation "risk" does not exist.

with audit_rows as (
  select
    '01_trigger'::text as audit_section,
    trigger_record.tgname::text as object_name,
    pg_catalog.jsonb_build_object(
      'trigger_definition', pg_catalog.pg_get_triggerdef(trigger_record.oid, true),
      'function_schema', function_namespace.nspname,
      'function_name', function_record.proname,
      'function_definition', pg_catalog.pg_get_functiondef(function_record.oid)
    ) as details
  from pg_catalog.pg_trigger as trigger_record
  join pg_catalog.pg_proc as function_record
    on function_record.oid = trigger_record.tgfoid
  join pg_catalog.pg_namespace as function_namespace
    on function_namespace.oid = function_record.pronamespace
  where trigger_record.tgrelid = 'public.subject_topics'::pg_catalog.regclass
    and trigger_record.tgisinternal = false
    and function_record.prokind = 'f'

  union all

  select
    '02_policy'::text,
    policy_record.policyname::text,
    pg_catalog.jsonb_build_object(
      'command', policy_record.cmd,
      'roles', policy_record.roles,
      'using_expression', policy_record.qual,
      'check_expression', policy_record.with_check
    )
  from pg_catalog.pg_policies as policy_record
  where policy_record.schemaname = 'public'
    and policy_record.tablename = 'subject_topics'

  union all

  select
    '03_column_default'::text,
    column_record.column_name::text,
    pg_catalog.jsonb_build_object(
      'data_type', column_record.data_type,
      'default_expression', column_record.column_default
    )
  from information_schema.columns as column_record
  where column_record.table_schema = 'public'
    and column_record.table_name = 'subject_topics'
    and column_record.column_default is not null

  union all

  select
    '04_rule'::text,
    rewrite_record.rulename::text,
    pg_catalog.jsonb_build_object(
      'definition', pg_catalog.pg_get_ruledef(rewrite_record.oid, true)
    )
  from pg_catalog.pg_rewrite as rewrite_record
  where rewrite_record.ev_class = 'public.subject_topics'::pg_catalog.regclass
    and rewrite_record.rulename <> '_RETURN'
)
select audit_section, object_name, details
from audit_rows
order by audit_section, object_name;
