import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const auditPath = resolve(here, 'sql', 'learning-module-object-audit.sql');
const sql = readFileSync(auditPath, 'utf8');

const withoutComments = sql
    .replace(/\/\*[\s\S]*?\*\//g, ' ')
    .replace(/--.*$/gm, ' ');
const withoutQuotedText = withoutComments
    .replace(/'(?:''|[^'])*'/g, "''")
    .replace(/"(?:""|[^"])*"/g, '""');

assert.doesNotMatch(
    withoutQuotedText,
    /\b(create|alter|drop|insert|update|delete|truncate|grant|revoke|call|copy|do)\b/i,
    'The Learning Module audit must remain read-only.'
);

for (const forbidden of [
    'auth.users',
    'email',
    'phone',
    'mobile_number',
    'resource.content',
    'question_text',
    'answer_text'
]) {
    assert.ok(
        !withoutComments.toLowerCase().includes(forbidden),
        `The Learning Module audit must not expose ${forbidden}.`
    );
}

for (const expected of [
    'subject_modules',
    'subject_chapters',
    'subject_topics',
    'learning_resource_types',
    'learning_resources',
    'flashcards',
    'user_topic_progress',
    'user_learning_activity',
    'user_entitlements',
    'get_learning_resources',
    'record_learning_activity',
    'get_resume_learning',
    'get_learning_statistics',
    'information_schema.columns',
    'pg_get_function_identity_arguments',
    'pg_get_functiondef'
]) {
    assert.ok(sql.includes(expected), `Expected audit coverage for ${expected}.`);
}

assert.match(
    sql,
    /select\s+audit_section,\s*object_name,\s*details/i,
    'The audit must return a single, exportable result shape.'
);
assert.equal(
    (withoutQuotedText.match(/;\s*$/g) ?? []).length,
    1,
    'The audit must end as one SQL statement.'
);

console.log('Learning Module audit static check passed.');
