import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const sql = readFileSync(
    resolve(here, 'sql', 'ic11-ic14-learning-content-audit.sql'),
    'utf8'
);
const withoutComments = sql
    .replace(/\/\*[\s\S]*?\*\//g, ' ')
    .replace(/--.*$/gm, ' ');
const withoutQuotedText = withoutComments
    .replace(/'(?:''|[^'])*'/g, "''")
    .replace(/"(?:""|[^"])*"/g, '""');

assert.doesNotMatch(
    withoutQuotedText,
    /\b(create|alter|drop|insert|update|delete|truncate|grant|revoke|call|copy|do)\b/i,
    'The IC11/IC14 learning-content audit must remain read-only.'
);

for (const forbidden of [
    'auth.users',
    'profiles',
    'user_topic_progress',
    'user_learning_activity',
    'user_entitlements',
    'quiz_attempts',
    'email',
    'mobile'
]) {
    assert.ok(
        !withoutComments.toLowerCase().includes(forbidden),
        `The IC11/IC14 audit must not inspect ${forbidden}.`
    );
}

for (const expected of [
    "'IC11'",
    "'IC14'",
    'subject_modules',
    'subject_chapters',
    'subject_topics',
    'learning_resource_types',
    'learning_resources',
    'flashcards',
    "'05_topic_content_summary'",
    "'06_learning_resources'",
    "'07_flashcards'",
    'select audit_section, object_code, details'
]) {
    assert.ok(sql.includes(expected), `Expected IC11/IC14 audit coverage for ${expected}.`);
}

assert.equal(
    (withoutQuotedText.match(/;\s*$/g) ?? []).length,
    1,
    'The IC11/IC14 audit must end as one SQL statement.'
);

console.log('IC11 and IC14 learning-content audit static check passed.');
