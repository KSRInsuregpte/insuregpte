-- Remove direct write and administrative table privileges from browser roles.
-- Authenticated SELECT is temporarily retained because the current dashboard
-- and quiz page still read the signed-in user's status from profiles.
-- SECURITY DEFINER profile RPCs execute with the function owner's privileges
-- and do not require caller INSERT or UPDATE rights on the table.
--
-- Rollback:
-- supabase/rollbacks/20260719181000_restrict_profiles_table_privileges.sql

REVOKE ALL PRIVILEGES ON TABLE public.profiles FROM anon;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
ON TABLE public.profiles
FROM authenticated;

GRANT SELECT ON TABLE public.profiles TO authenticated;
