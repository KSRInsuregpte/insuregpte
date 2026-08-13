import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const migration = readFileSync(
    resolve(here, '..', 'supabase', 'migrations', '20260813100000_seed_ic11_topic_hierarchy.sql'),
    'utf8'
);
const rollback = readFileSync(
    resolve(here, '..', 'supabase', 'rollbacks', '20260813100000_seed_ic11_topic_hierarchy.sql'),
    'utf8'
);
const verification = readFileSync(
    resolve(here, 'sql', 'ic11-topic-hierarchy-verification.sql'),
    'utf8'
);

const topicRows = migration.match(
    /\('IC11-M\d{2}', 'IC11-C\d{2}', \d+, 'IC11-C\d{2}-T\d{2}'/g
) ?? [];
assert.equal(topicRows.length, 43, 'The IC11 hierarchy must contain exactly 43 topic seed rows.');

const topicCodes = topicRows.map((row) => row.match(/'IC11-C\d{2}-T\d{2}'/)?.[0]);
assert.equal(new Set(topicCodes).size, 43, 'Every IC11 topic code must be unique.');

const expectedByChapter = new Map([
    ['IC11-C01', 4], ['IC11-C02', 4], ['IC11-C03', 4],
    ['IC11-C04', 5], ['IC11-C05', 5], ['IC11-C06', 4],
    ['IC11-C07', 6], ['IC11-C08', 6], ['IC11-C09', 5]
]);
for (const [chapterCode, expectedCount] of expectedByChapter) {
    assert.equal(
        topicCodes.filter((code) => code?.includes(chapterCode)).length,
        expectedCount,
        `${chapterCode} must contain ${expectedCount} topics.`
    );
    assert.ok(verification.includes(`('${chapterCode}', ${expectedCount})`));
}

for (const forbidden of [
    'insert into public.user_',
    'update public.user_',
    'delete from public.user_',
    'insert into public.learning_resources',
    'insert into public.flashcards'
]) {
    assert.ok(
        !migration.toLowerCase().includes(forbidden),
        `The topic-hierarchy migration must not perform: ${forbidden}`
    );
}

for (const required of [
    'WITH topic_seed',
    'ON CONFLICT (subject_id, code) DO UPDATE',
    'Expected exactly 43 active planned IC11 topics',
    'One or more IC11 chapters has an incomplete topic hierarchy'
]) {
    assert.ok(migration.includes(required), `Missing IC11 migration safeguard: ${required}`);
}

for (const forbiddenStagingOperation of [
    'migration_ic11_topic_seed',
    'CREATE TABLE',
    'DROP TABLE'
]) {
    assert.ok(
        !migration.includes(forbiddenStagingOperation),
        `The IC11 hierarchy must not use session-dependent staging: ${forbiddenStagingOperation}`
    );
}

for (const guardTarget of [
    'learning_resources',
    'flashcards',
    'user_topic_progress',
    'user_learning_activity'
]) {
    assert.ok(rollback.includes(guardTarget), `Rollback must guard ${guardTarget}.`);
}

console.log('IC11 topic hierarchy static checks passed: 43 stable topics across 9 chapters.');
