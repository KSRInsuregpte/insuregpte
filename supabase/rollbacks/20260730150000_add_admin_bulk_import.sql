-- Safe operational rollback for administrator bulk import.
--
-- This removes only the coordinating RPC. Records already saved through the
-- existing audited administrator RPCs are intentionally retained because
-- automatically reversing legitimate content or user-status changes would be
-- destructive.

BEGIN;

REVOKE EXECUTE ON FUNCTION public.admin_bulk_import(text, jsonb)
FROM authenticated;

DROP FUNCTION IF EXISTS public.admin_bulk_import(text, jsonb);

NOTIFY pgrst, 'reload schema';

COMMIT;
