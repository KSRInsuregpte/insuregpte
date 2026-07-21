-- Restore the browser-role grants captured on 2026-07-19.

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
ON TABLE public.profiles
TO anon, authenticated;
