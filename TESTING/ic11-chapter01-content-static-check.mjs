import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const migration = readFileSync(
    resolve(here, '..', 'supabase', 'migrations', '20260813110000_seed_ic11_chapter01_content.sql'),
    'utf8'
);
const verification = readFileSync(
    resolve(here, 'sql', 'ic11-chapter01-content-verification.sql'),
    'utf8'
);

assert.equal(
    (migration.match(/'LR-IC11-C01-T\d{2}-\d{3}'/g) ?? []).filter(
        (code, index, all) => all.indexOf(code) === index
    ).length,
    8,
    'IC11 Chapter 1 must define eight unique resources.'
);
assert.equal(
    (migration.match(/'FC-IC11-C01-T\d{2}-\d{3}'/g) ?? []).filter(
        (code, index, all) => all.indexOf(code) === index
    ).length,
    12,
    'IC11 Chapter 1 must define twelve unique flashcards.'
);

for (const topic of ['T01', 'T02', 'T03', 'T04']) {
    assert.ok(migration.includes(`'IC11-C01-${topic}'`), `Missing IC11 Chapter 1 ${topic}.`);
}
for (const required of [
    "'NOTE'", "'REVISION_NOTE'", 'ON COMMIT PRESERVE ROWS',
    'WHERE NOT EXISTS', 'Expected exactly 8 active IC11 Chapter 1 resources',
    'Expected exactly 12 active IC11 Chapter 1 flashcards'
]) {
    assert.ok(migration.includes(required), `Missing content safeguard: ${required}`);
}
for (const forbidden of [
    'insert into public.user_', 'update public.user_', 'delete from public.user_',
    'insert into public.user_entitlements', 'insert into public.quiz_attempts'
]) {
    assert.ok(!migration.toLowerCase().includes(forbidden), `Forbidden content write: ${forbidden}`);
}
assert.ok(verification.includes('resources_have_content'));
assert.ok(verification.includes("'IC11-C01'"));

console.log('IC11 Chapter 1 content static checks passed: 8 resources and 12 flashcards.');
