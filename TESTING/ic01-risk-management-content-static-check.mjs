import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const migration = readFileSync(resolve(
    here,
    '..',
    'supabase',
    'migrations',
    '20260812160000_complete_ic01_risk_management_content.sql'
), 'utf8');
const verification = readFileSync(resolve(
    here,
    'sql',
    'ic01-risk-management-content-verification.sql'
), 'utf8');
const rollback = readFileSync(resolve(
    here,
    '..',
    'supabase',
    'rollbacks',
    '20260812160000_complete_ic01_risk_management_content.sql'
), 'utf8');

assert.match(migration, /^BEGIN;/m);
assert.match(migration, /^COMMIT;/m);
assert.match(migration, /The approved Topic 1 pilot content is incomplete/i);
assert.doesNotMatch(
    migration,
    /ON COMMIT DROP/i,
    'Supabase may commit each editor statement, so seed tables must survive statement commits.'
);
assert.equal(
    (migration.match(/ON COMMIT PRESERVE ROWS/g) ?? []).length,
    2,
    'Both IC01 seed tables must survive Supabase statement commits.'
);
assert.match(migration, /DROP TABLE IF EXISTS pg_temp\.ic01_resource_seed;/i);
assert.match(migration, /DROP TABLE IF EXISTS pg_temp\.ic01_flashcard_seed;/i);
assert.doesNotMatch(
    migration,
    /(?:INSERT INTO|UPDATE|DELETE FROM)\s+public\.(?:user_topic_progress|user_learning_activity|user_entitlements|quiz_attempts)/i,
    'The content migration must not alter learner or practice records.'
);

for (let topic = 2; topic <= 7; topic += 1) {
    const number = String(topic).padStart(2, '0');
    assert.ok(migration.includes(`LR-IC01-C01-T${number}-001`));
    assert.ok(migration.includes(`LR-IC01-C01-T${number}-002`));
    for (let card = 1; card <= 3; card += 1) {
        assert.ok(migration.includes(
            `FC-IC01-C01-T${number}-${String(card).padStart(3, '0')}`
        ));
    }
}

assert.equal(
    (migration.match(/\('IC01-C01-T0[2-7]', '(?:NOTE|REVISION_NOTE)'/g) ?? []).length,
    12,
    'Topics 2-7 must each receive a learning note and revision note.'
);
assert.equal(
    (migration.match(/\('IC01-C01-T0[2-7]', 'FC-IC01-C01-T0[2-7]-00[1-3]'/g) ?? []).length,
    18,
    'Topics 2-7 must each receive three flashcards.'
);
assert.match(migration, /Expected exactly 14 active IC01 Risk Management resources/i);
assert.match(migration, /Expected exactly 19 active IC01 Risk Management flashcards/i);
assert.match(verification, /resources_have_content/i);
assert.match(verification, /GROUP BY topic_record\.id/i);
assert.doesNotMatch(
    verification,
    /pg_catalog\.(?:array_agg|count|bool_and)\s*\(/i,
    'PostgreSQL aggregate functions must not be schema-qualified.'
);
assert.match(rollback, /LR-IC01-C01-T02-001/);
assert.match(rollback, /FC-IC01-C01-T02-001/);
assert.doesNotMatch(rollback, /IC01-C01-T01/);

console.log('IC01 Risk Management content static checks passed.');
