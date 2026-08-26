-- Read-only InsureGPTE browser table-privilege audit.
-- Run this file alone in Supabase SQL Editor and export the result as CSV or JSON.

WITH expected_table(table_name) AS (
    VALUES
        ('profiles'),
        ('subjects'),
        ('questions'),
        ('quiz_attempts'),
        ('quiz_attempt_questions'),
        ('user_entitlements'),
        ('carts'),
        ('cart_items'),
        ('regulatory_academic_publications'),
        ('subject_modules'),
        ('subject_chapters'),
        ('subject_topics'),
        ('learning_resources'),
        ('flashcards'),
        ('user_topic_progress'),
        ('learning_activity')
)
SELECT
    expected_table.table_name,
    to_regclass('public.' || expected_table.table_name) IS NOT NULL AS exists,
    CASE WHEN to_regclass('public.' || expected_table.table_name) IS NULL THEN NULL ELSE pg_catalog.has_table_privilege('anon', 'public.' || expected_table.table_name, 'SELECT') END AS anon_select,
    CASE WHEN to_regclass('public.' || expected_table.table_name) IS NULL THEN NULL ELSE pg_catalog.has_table_privilege('authenticated', 'public.' || expected_table.table_name, 'SELECT') END AS authenticated_select,
    CASE WHEN to_regclass('public.' || expected_table.table_name) IS NULL THEN NULL ELSE pg_catalog.has_table_privilege('anon', 'public.' || expected_table.table_name, 'INSERT') END AS anon_insert,
    CASE WHEN to_regclass('public.' || expected_table.table_name) IS NULL THEN NULL ELSE pg_catalog.has_table_privilege('authenticated', 'public.' || expected_table.table_name, 'INSERT') END AS authenticated_insert,
    CASE WHEN to_regclass('public.' || expected_table.table_name) IS NULL THEN NULL ELSE pg_catalog.has_table_privilege('anon', 'public.' || expected_table.table_name, 'UPDATE') END AS anon_update,
    CASE WHEN to_regclass('public.' || expected_table.table_name) IS NULL THEN NULL ELSE pg_catalog.has_table_privilege('authenticated', 'public.' || expected_table.table_name, 'UPDATE') END AS authenticated_update,
    CASE WHEN to_regclass('public.' || expected_table.table_name) IS NULL THEN NULL ELSE pg_catalog.has_table_privilege('anon', 'public.' || expected_table.table_name, 'DELETE') END AS anon_delete,
    CASE WHEN to_regclass('public.' || expected_table.table_name) IS NULL THEN NULL ELSE pg_catalog.has_table_privilege('authenticated', 'public.' || expected_table.table_name, 'DELETE') END AS authenticated_delete
FROM expected_table
ORDER BY expected_table.table_name;
