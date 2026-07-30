-- Roll back only the compatibility normalization.
--
-- This migration created no table, function, or learner data, so no database
-- object should be dropped. Keep the RPC grants owned by their original
-- catalogue migration and preserve the hardened subject/question boundary.

REVOKE ALL ON TABLE public.subjects
FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.questions
FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.subjects_id_seq
FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.questions_id_seq
FROM PUBLIC, anon, authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE
ON TABLE public.subjects TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE
ON TABLE public.questions TO service_role;
GRANT USAGE, SELECT ON SEQUENCE public.subjects_id_seq
TO service_role;
GRANT USAGE, SELECT ON SEQUENCE public.questions_id_seq
TO service_role;

NOTIFY pgrst, 'reload schema';
