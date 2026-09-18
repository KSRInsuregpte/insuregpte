import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const migration = readFileSync(
    resolve(here, '..', 'supabase', 'migrations', '20260813120000_seed_remaining_ic11_content.sql'),
    'utf8'
);
const rollback = readFileSync(
    resolve(here, '..', 'supabase', 'rollbacks', '20260813120000_seed_remaining_ic11_content.sql'),
    'utf8'
);
const verification = readFileSync(resolve(here, 'sql', 'ic11-complete-content-verification.sql'), 'utf8');

const seedCodes = migration.match(/^\('IC11-C\d{2}-T\d{2}',/gm) ?? [];
assert.equal(seedCodes.length, 39, 'The remaining IC11 migration must seed exactly 39 topics.');
assert.equal(new Set(seedCodes).size, 39, 'Remaining IC11 topic codes must be unique.');

for (const required of [
    'CREATE TABLE public.migration_ic11_remaining_content_seed',
    'ENABLE ROW LEVEL SECURITY',
    'REVOKE ALL ON TABLE public.migration_ic11_remaining_content_seed FROM anon, authenticated',
    "'NOTE'", "'REVISION_NOTE'", 'CROSS JOIN LATERAL',
    'Expected exactly 78 active IC11 Chapter 2-9 resources',
    'Expected exactly 117 active IC11 Chapter 2-9 flashcards',
    'Every remaining IC11 topic must have two resources and three flashcards'
]) {
    assert.ok(migration.includes(required), `Missing remaining IC11 safeguard: ${required}`);
}
for (const forbidden of [
    'insert into public.user_', 'update public.user_', 'delete from public.user_',
    'insert into public.user_entitlements', 'insert into public.quiz_attempts'
]) {
    assert.ok(!migration.toLowerCase().includes(forbidden), `Forbidden IC11 write: ${forbidden}`);
}
for (const protectedTable of ['user_learning_activity', 'learning_resources', 'flashcards']) {
    assert.ok(rollback.includes(protectedTable), `Rollback must account for ${protectedTable}.`);
}
for (const expected of ['active_topics', 'active_resources', 'active_flashcards', 'resources_have_content']) {
    assert.ok(verification.includes(expected), `Final IC11 verification must include ${expected}.`);
}

console.log('Complete IC11 content static checks passed: 39 remaining topics, 78 resources, 117 flashcards.');
