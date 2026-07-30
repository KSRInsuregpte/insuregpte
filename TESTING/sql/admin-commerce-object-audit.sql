-- InsureGPTE live admin-portal and commerce-object audit.
-- Run in the trial Supabase SQL editor and export the single result grid.
-- This script returns schema metadata and aggregate counts only. It does not
-- return names, contact details, question text, answers, or learner records.

with
required_relations(object_schema, object_name) as (
  values
    ('auth', 'users'),
    ('public', 'profiles'),
    ('public', 'subjects'),
    ('public', 'questions'),
    ('public', 'qualification_levels'),
    ('public', 'exam_authorities'),
    ('public', 'training_programmes'),
    ('public', 'programme_sections'),
    ('public', 'regulatory_academic_publications'),
    ('public', 'carts'),
    ('public', 'cart_items'),
    ('public', 'user_entitlements'),
    ('public', 'user_learning_activity')
),
required_relation_status as (
  select
    '01_required_relation'::text as audit_section,
    format('%I.%I', relation.object_schema, relation.object_name)::text
      as object_name,
    jsonb_build_object(
      'exists',
      to_regclass(
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
management_relation_candidates as (
  select
    '03_management_relation_candidates'::text as audit_section,
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
       '(admin|audit|payment|order|purchase|transaction|checkout|webhook)'
  where namespaces.nspname = 'public'
),
management_function_candidates as (
  select
    '04_management_function_candidates'::text as audit_section,
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
        order by procedures.proname,
                 pg_get_function_identity_arguments(procedures.oid)
      ) filter (where procedures.oid is not null),
      '[]'::jsonb
    ) as details
  from pg_catalog.pg_namespace as namespaces
  left join pg_catalog.pg_proc as procedures
    on procedures.pronamespace = namespaces.oid
   and procedures.proname ~*
       '(admin|audit|payment|order|purchase|checkout|webhook|manage)'
  where namespaces.nspname = 'public'
),
reserved_function_names(function_name) as (
  values
    ('fn_is_admin'),
    ('get_admin_portal_summary'),
    ('admin_list_subjects'),
    ('admin_save_subject'),
    ('admin_list_questions'),
    ('admin_save_question'),
    ('admin_list_users'),
    ('admin_set_user_status'),
    ('admin_list_exam_information'),
    ('admin_save_exam_information'),
    ('admin_retire_exam_information'),
    ('admin_list_audit_events'),
    ('create_payment_order'),
    ('verify_payment_webhook')
),
reserved_function_status as (
  select
    '05_proposed_function_conflicts'::text as audit_section,
    reserved.function_name::text as object_name,
    jsonb_build_object(
      'exists',
      exists (
        select 1
        from pg_catalog.pg_proc as procedures
        join pg_catalog.pg_namespace as namespaces
          on namespaces.oid = procedures.pronamespace
        where namespaces.nspname = 'public'
          and procedures.proname = reserved.function_name
      ),
      'signatures',
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'arguments',
              pg_get_function_identity_arguments(procedures.oid),
              'result',
              pg_get_function_result(procedures.oid)
            )
            order by pg_get_function_identity_arguments(procedures.oid)
          )
          from pg_catalog.pg_proc as procedures
          join pg_catalog.pg_namespace as namespaces
            on namespaces.oid = procedures.pronamespace
          where namespaces.nspname = 'public'
            and procedures.proname = reserved.function_name
        ),
        '[]'::jsonb
      )
    ) as details
  from reserved_function_names as reserved
),
profile_role_status_counts as (
  select
    '06_profile_role_status_counts'::text as audit_section,
    coalesce(nullif(btrim(profile.role), ''), '(blank)')::text
      as object_name,
    jsonb_object_agg(
      coalesce(nullif(btrim(profile.status), ''), '(blank)'),
      profile_count
      order by coalesce(nullif(btrim(profile.status), ''), '(blank)')
    ) as details
  from (
    select role, status, count(*) as profile_count
    from public.profiles
    group by role, status
  ) as profile
  group by coalesce(nullif(btrim(profile.role), ''), '(blank)')
),
question_distribution as (
  select
    '07_question_distribution'::text as audit_section,
    subject_record.code::text as object_name,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'difficulty_level',
          coalesce(question_record.difficulty_level, '(blank)'),
          'question_type',
          coalesce(question_record.question_type, '(blank)'),
          'is_active',
          coalesce(question_record.is_active, false),
          'count',
          question_record.question_count
        )
        order by
          question_record.difficulty_level,
          question_record.question_type,
          question_record.is_active
      ) filter (where question_record.question_count is not null),
      '[]'::jsonb
    ) as details
  from public.subjects as subject_record
  left join (
    select
      subject_id,
      difficulty_level,
      question_type,
      is_active,
      count(*) as question_count
    from public.questions
    group by subject_id, difficulty_level, question_type, is_active
  ) as question_record
    on question_record.subject_id = subject_record.id
  group by subject_record.id, subject_record.code
),
subject_master_rows as (
  select
    '08_subject_master_rows'::text as audit_section,
    'subjects'::text as object_name,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', subject_record.id,
          'code', subject_record.code,
          'title', subject_record.title,
          'qualification_level_id',
          subject_record.qualification_level_id,
          'training_programme_id',
          subject_record.training_programme_id,
          'programme_section_id',
          subject_record.programme_section_id,
          'category', subject_record.category,
          'syllabus_version', subject_record.syllabus_version,
          'display_order', subject_record.display_order,
          'demo_question_limit', subject_record.demo_question_limit,
          'price', subject_record.price,
          'currency_code', subject_record.currency_code,
          'is_demo_available', subject_record.is_demo_available,
          'is_active', subject_record.is_active
        )
        order by subject_record.display_order, subject_record.code
      ),
      '[]'::jsonb
    ) as details
  from public.subjects as subject_record
),
governed_constraints as (
  select
    '09_governed_constraints'::text as audit_section,
    classes.relname::text as object_name,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'name', constraints.conname,
          'type', constraints.contype,
          'definition', pg_get_constraintdef(constraints.oid, true)
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
      'subjects',
      'questions',
      'regulatory_academic_publications',
      'carts',
      'cart_items',
      'user_entitlements'
    )
  group by classes.relname
),
governed_privileges as (
  select
    '10_governed_privileges'::text as audit_section,
    relation.object_name::text as object_name,
    jsonb_build_object(
      'rls_enabled', classes.relrowsecurity,
      'anon_select',
      has_table_privilege(
        'anon',
        format('public.%I', relation.object_name),
        'SELECT'
      ),
      'anon_write',
      has_table_privilege(
        'anon',
        format('public.%I', relation.object_name),
        'INSERT'
      )
      or has_table_privilege(
        'anon',
        format('public.%I', relation.object_name),
        'UPDATE'
      )
      or has_table_privilege(
        'anon',
        format('public.%I', relation.object_name),
        'DELETE'
      ),
      'authenticated_select',
      has_table_privilege(
        'authenticated',
        format('public.%I', relation.object_name),
        'SELECT'
      ),
      'authenticated_write',
      has_table_privilege(
        'authenticated',
        format('public.%I', relation.object_name),
        'INSERT'
      )
      or has_table_privilege(
        'authenticated',
        format('public.%I', relation.object_name),
        'UPDATE'
      )
      or has_table_privilege(
        'authenticated',
        format('public.%I', relation.object_name),
        'DELETE'
      )
    ) as details
  from (
    values
      ('profiles'),
      ('subjects'),
      ('questions'),
      ('regulatory_academic_publications'),
      ('carts'),
      ('cart_items'),
      ('user_entitlements')
  ) as relation(object_name)
  join pg_catalog.pg_class as classes
    on classes.oid = to_regclass(format('public.%I', relation.object_name))
),
commerce_aggregate_counts as (
  select
    '11_commerce_aggregate_counts'::text as audit_section,
    'carts'::text as object_name,
    coalesce(
      (
        select jsonb_object_agg(status, status_count order by status)
        from (
          select status, count(*) as status_count
          from public.carts
          group by status
        ) as cart_counts
      ),
      '{}'::jsonb
    ) as details
  union all
  select
    '11_commerce_aggregate_counts',
    'cart_items',
    jsonb_build_object('count', count(*))
  from public.cart_items
  union all
  select
    '11_commerce_aggregate_counts',
    'user_entitlements',
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'access_type', access_type,
            'status', status,
            'count', entitlement_count
          )
          order by access_type, status
        )
        from (
          select access_type, status, count(*) as entitlement_count
          from public.user_entitlements
          group by access_type, status
        ) as entitlement_counts
      ),
      '[]'::jsonb
    )
)
select audit_section, object_name, details
from (
  select * from required_relation_status
  union all
  select * from required_column_inventory
  union all
  select * from management_relation_candidates
  union all
  select * from management_function_candidates
  union all
  select * from reserved_function_status
  union all
  select * from profile_role_status_counts
  union all
  select * from question_distribution
  union all
  select * from subject_master_rows
  union all
  select * from governed_constraints
  union all
  select * from governed_privileges
  union all
  select * from commerce_aggregate_counts
) as audit_rows
order by audit_section, object_name;
