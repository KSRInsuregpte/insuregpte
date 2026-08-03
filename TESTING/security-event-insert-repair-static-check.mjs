import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const repositoryRoot = resolve(
    dirname(fileURLToPath(import.meta.url)),
    '..'
);

const migration = await readFile(
    resolve(
        repositoryRoot,
        'supabase/migrations/20260803100000_repair_security_event_insert.sql'
    ),
    'utf8'
);
const rollback = await readFile(
    resolve(
        repositoryRoot,
        'supabase/rollbacks/20260803100000_repair_security_event_insert.sql'
    ),
    'utf8'
);
const verification = await readFile(
    resolve(
        repositoryRoot,
        'TESTING/sql/security-event-insert-repair-verification.sql'
    ),
    'utf8'
);

assert.match(
    migration,
    /CREATE OR REPLACE FUNCTION public\.fn_insert_security_event\([\s\S]*?RETURNS bigint/i,
    'The repair must preserve the existing helper signature and return type.'
);
assert.match(
    migration,
    /occurred_at,\s*last_seen_at,\s*updated_at\s*\)[\s\S]*?coalesce\(p_occurred_at, clock_timestamp\(\)\),\s*clock_timestamp\(\),\s*clock_timestamp\(\)\s*\)/i,
    'The ten INSERT target columns must have all ten expressions.'
);
assert.match(
    migration,
    /ON CONFLICT \(dedupe_key\) DO UPDATE[\s\S]*occurrence_count[\s\S]*updated_at/i,
    'The existing deduplication behavior must remain intact.'
);
assert.match(
    migration,
    /REVOKE ALL ON FUNCTION public\.fn_insert_security_event\([\s\S]*?FROM PUBLIC, anon, authenticated, service_role/i,
    'The internal helper must remain unavailable to application roles.'
);
assert.match(
    rollback,
    /CREATE OR REPLACE FUNCTION public\.fn_insert_security_event/i,
    'A safe signature-preserving rollback must be present.'
);
assert.match(
    verification,
    /BEGIN;[\s\S]*public\.fn_insert_security_event[\s\S]*occurrence_count IS DISTINCT FROM 2[\s\S]*ROLLBACK;/i,
    'Verification must execute insert and deduplication paths transactionally.'
);

console.log('Security-event insert repair static checks passed.');
