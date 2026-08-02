-- InsureGPTE live safety-system object audit.
-- Run in the trial Supabase SQL editor and export the single result grid.
-- This script is read-only and privacy-safe: it returns object metadata and
-- aggregate counts only. It does not return names, contact details, tokens,
-- quiz answers, IP addresses, user-agent strings, or Auth-event payloads.

with
required_relations(object_schema, object_name) as (
  values
    ('auth', 'users'),
    ('auth', 'audit_log_entries'),
    ('public', 'profiles'),
    ('public', 'active_client_leases'),
    ('public', 'admin_audit_events')
),
required_relation_status as (
  select
    '01_required_relation'::text as audit_section,
    format('%I.%I', relation.object_schema, relation.object_name)::text
      as object_name,
    jsonb_build_object(
      'exists',
      pg_catalog.to_regclass(
        format('%I.%I', relation.object_schema, relation.object_name)
      ) is not null
    ) as details
  from required_relations as relation
),
required_column_inventory as (
  select
    '02_required_columns'::text as audit_section,
    format('%I.%I', relation.object_schema, relation.object_name)::text
      as object_name,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'position', columns.ordinal_position,
          'name', columns.column_name,
          'data_type', columns.data_type,
          'nullable', columns.is_nullable,
          'default', columns.column_default
        )
        order by columns.ordinal_position
      ) filter (where columns.column_name is not null),
      '[]'::jsonb
    ) as details
  from required_relations as relation
  left join information_schema.columns as columns
    on columns.table_schema = relation.object_schema
   and columns.table_name = relation.object_name
  group by relation.object_schema, relation.object_name
),
safety_relation_candidates as (
  select
    '03_safety_relation_candidates'::text as audit_section,
    namespaces.nspname::text as object_name,
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
          end,
          'rls_enabled', classes.relrowsecurity
        )
        order by classes.relname
      ) filter (where classes.oid is not null),
      '[]'::jsonb
    ) as details
  from pg_catalog.pg_namespace as namespaces
  left join pg_catalog.pg_class as classes
    on classes.relnamespace = namespaces.oid
   and classes.relkind in ('r', 'p', 'v', 'm', 'f')
   and classes.relname ~*
       '(security|alert|incident|notification|outbox|warning|enforcement|violation|block|suspend|session|login|audit)'
  where namespaces.nspname in ('public', 'auth')
  group by namespaces.nspname
),
safety_function_candidates as (
  select
    '04_safety_function_candidates'::text as audit_section,
    namespaces.nspname::text as object_name,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'name', procedures.proname,
          'arguments',
          pg_catalog.pg_get_function_identity_arguments(procedures.oid),
          'result', pg_catalog.pg_get_function_result(procedures.oid),
          'security_definer', procedures.prosecdef,
          'volatility', procedures.provolatile
        )
        order by procedures.proname,
                 pg_catalog.pg_get_function_identity_arguments(procedures.oid)
      ) filter (where procedures.oid is not null),
      '[]'::jsonb
    ) as details
  from pg_catalog.pg_namespace as namespaces
  left join pg_catalog.pg_proc as procedures
    on procedures.pronamespace = namespaces.oid
   and procedures.proname ~*
       '(security|alert|incident|notification|warning|enforce|violation|block|suspend|session|login|audit)'
  where namespaces.nspname in ('public', 'auth')
  group by namespaces.nspname
),
proposed_relations(object_name) as (
  values
    ('security_events'),
    ('account_enforcement_cases'),
    ('notification_outbox')
),
proposed_relation_status as (
  select
    '05_proposed_relation_conflicts'::text as audit_section,
    proposed.object_name::text as object_name,
    jsonb_build_object(
      'exists',
      pg_catalog.to_regclass(
        format('public.%I', proposed.object_name)
      ) is not null
    ) as details
  from proposed_relations as proposed
),
proposed_functions(function_name) as (
  values
    ('fn_queue_account_activation_notification'),
    ('fn_scan_long_running_sessions'),
    ('get_admin_security_summary'),
    ('admin_list_security_events'),
    ('admin_review_security_event'),
    ('admin_list_enforcement_cases'),
    ('admin_restore_user_access'),
    ('claim_notification_outbox'),
    ('complete_notification_outbox')
),
proposed_function_status as (
  select
    '06_proposed_function_conflicts'::text as audit_section,
    proposed.function_name::text as object_name,
    jsonb_build_object(
      'exists',
      exists (
        select 1
        from pg_catalog.pg_proc as procedures
        join pg_catalog.pg_namespace as namespaces
          on namespaces.oid = procedures.pronamespace
        where namespaces.nspname = 'public'
          and procedures.proname = proposed.function_name
      ),
      'signatures',
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'arguments',
              pg_catalog.pg_get_function_identity_arguments(procedures.oid),
              'result',
              pg_catalog.pg_get_function_result(procedures.oid),
              'security_definer', procedures.prosecdef
            )
            order by
              pg_catalog.pg_get_function_identity_arguments(procedures.oid)
          )
          from pg_catalog.pg_proc as procedures
          join pg_catalog.pg_namespace as namespaces
            on namespaces.oid = procedures.pronamespace
          where namespaces.nspname = 'public'
            and procedures.proname = proposed.function_name
        ),
        '[]'::jsonb
      )
    ) as details
  from proposed_functions as proposed
),
required_function_status(function_signature) as (
  values
    ('public.fn_is_admin()'),
    ('public.admin_list_users()'),
    ('public.admin_set_user_status(uuid,text)'),
    ('public.claim_active_client(uuid,boolean)'),
    ('public.heartbeat_active_client(uuid)'),
    ('public.release_active_client(uuid)'),
    ('public.fn_enforce_active_auth_session()'),
    ('public.activate_verified_user()')
),
required_function_inventory as (
  select
    '07_required_function'::text as audit_section,
    required.function_signature::text as object_name,
    case
      when pg_catalog.to_regprocedure(required.function_signature) is null
        then jsonb_build_object('exists', false)
      else jsonb_build_object(
        'exists', true,
        'result', pg_catalog.pg_get_function_result(
          pg_catalog.to_regprocedure(required.function_signature)
        ),
        'security_definer', procedures.prosecdef,
        'volatility', procedures.provolatile,
        'configuration', coalesce(to_jsonb(procedures.proconfig), '[]'::jsonb)
      )
    end as details
  from required_function_status as required
  left join pg_catalog.pg_proc as procedures
    on procedures.oid = pg_catalog.to_regprocedure(required.function_signature)
),
governed_constraints as (
  select
    '08_governed_constraints'::text as audit_section,
    classes.relname::text as object_name,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'name', constraints.conname,
          'type', constraints.contype,
          'definition',
          pg_catalog.pg_get_constraintdef(constraints.oid, true)
        )
        order by constraints.conname
      ),
      '[]'::jsonb
    ) as details
  from pg_catalog.pg_constraint as constraints
  join pg_catalog.pg_class as classes
    on classes.oid = constraints.conrelid
  join pg_catalog.pg_namespace as namespaces
    on namespaces.oid = classes.relnamespace
  where namespaces.nspname = 'public'
    and classes.relname in (
      'profiles',
      'active_client_leases',
      'admin_audit_events'
    )
  group by classes.relname
),
profile_status_counts as (
  select
    '09_profile_status_counts'::text as audit_section,
    coalesce(nullif(btrim(profile_record.status), ''), '(blank)')::text
      as object_name,
    jsonb_build_object('count', count(*)) as details
  from public.profiles as profile_record
  group by coalesce(nullif(btrim(profile_record.status), ''), '(blank)')
),
active_lease_aggregates as (
  select
    '10_active_lease_aggregates'::text as audit_section,
    'active_client_leases'::text as object_name,
    jsonb_build_object(
      'total_rows', count(*),
      'currently_unexpired',
      count(*) filter (where lease_record.expires_at > clock_timestamp()),
      'continuously_claimed_over_48_hours',
      count(*) filter (
        where lease_record.expires_at > clock_timestamp()
          and lease_record.claimed_at <= clock_timestamp() - interval '48 hours'
      ),
      'oldest_unexpired_claimed_at',
      min(lease_record.claimed_at) filter (
        where lease_record.expires_at > clock_timestamp()
      )
    ) as details
  from public.active_client_leases as lease_record
),
extension_inventory as (
  select
    '11_extension_inventory'::text as audit_section,
    extension.extension_name::text as object_name,
    jsonb_build_object(
      'installed', installed.oid is not null,
      'version', installed.extversion,
      'schema', namespaces.nspname
    ) as details
  from (
    values ('pg_cron'), ('pg_net'), ('supabase_vault')
  ) as extension(extension_name)
  left join pg_catalog.pg_extension as installed
    on installed.extname = extension.extension_name
  left join pg_catalog.pg_namespace as namespaces
    on namespaces.oid = installed.extnamespace
),
trigger_inventory as (
  select
    '12_trigger_inventory'::text as audit_section,
    format('%I.%I', namespaces.nspname, classes.relname)::text
      as object_name,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'name', triggers.tgname,
          'enabled', triggers.tgenabled,
          'definition', pg_catalog.pg_get_triggerdef(triggers.oid, true)
        )
        order by triggers.tgname
      ) filter (where triggers.oid is not null),
      '[]'::jsonb
    ) as details
  from pg_catalog.pg_namespace as namespaces
  join pg_catalog.pg_class as classes
    on classes.relnamespace = namespaces.oid
   and classes.relname in ('users', 'profiles')
  left join pg_catalog.pg_trigger as triggers
    on triggers.tgrelid = classes.oid
   and not triggers.tgisinternal
  where namespaces.nspname in ('auth', 'public')
  group by namespaces.nspname, classes.relname
),
governed_privileges as (
  select
    '13_governed_privileges'::text as audit_section,
    relation.object_name::text as object_name,
    jsonb_build_object(
      'rls_enabled', classes.relrowsecurity,
      'anon_select', pg_catalog.has_table_privilege(
        'anon', format('public.%I', relation.object_name), 'SELECT'
      ),
      'anon_write',
      pg_catalog.has_table_privilege(
        'anon', format('public.%I', relation.object_name), 'INSERT'
      )
      or pg_catalog.has_table_privilege(
        'anon', format('public.%I', relation.object_name), 'UPDATE'
      )
      or pg_catalog.has_table_privilege(
        'anon', format('public.%I', relation.object_name), 'DELETE'
      ),
      'authenticated_select', pg_catalog.has_table_privilege(
        'authenticated', format('public.%I', relation.object_name), 'SELECT'
      ),
      'authenticated_write',
      pg_catalog.has_table_privilege(
        'authenticated', format('public.%I', relation.object_name), 'INSERT'
      )
      or pg_catalog.has_table_privilege(
        'authenticated', format('public.%I', relation.object_name), 'UPDATE'
      )
      or pg_catalog.has_table_privilege(
        'authenticated', format('public.%I', relation.object_name), 'DELETE'
      )
    ) as details
  from (
    values
      ('profiles'),
      ('active_client_leases'),
      ('admin_audit_events')
  ) as relation(object_name)
  join pg_catalog.pg_class as classes
    on classes.oid = pg_catalog.to_regclass(
      format('public.%I', relation.object_name)
    )
)
select audit_section, object_name, details
from (
  select * from required_relation_status
  union all
  select * from required_column_inventory
  union all
  select * from safety_relation_candidates
  union all
  select * from safety_function_candidates
  union all
  select * from proposed_relation_status
  union all
  select * from proposed_function_status
  union all
  select * from required_function_inventory
  union all
  select * from governed_constraints
  union all
  select * from profile_status_counts
  union all
  select * from active_lease_aggregates
  union all
  select * from extension_inventory
  union all
  select * from trigger_inventory
  union all
  select * from governed_privileges
) as audit_rows
order by audit_section, object_name;
