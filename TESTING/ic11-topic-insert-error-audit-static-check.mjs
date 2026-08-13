import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const sql = readFileSync(resolve(here, 'sql', 'ic11-topic-insert-error-audit.sql'), 'utf8');
const withoutComments = sql.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/--.*$/gm, ' ');
const withoutQuotedText = withoutComments
    .replace(/'(?:''|[^'])*'/g, "''")
    .replace(/"(?:""|[^"])*"/g, '""');

assert.doesNotMatch(
    withoutQuotedText,
    /\b(create|alter|drop|insert|update|delete|truncate|grant|revoke|call|copy|do)\b/i,
    'The IC11 topic insert error audit must remain read-only.'
);
for (const required of ['pg_trigger', 'pg_policies', 'information_schema.columns', 'pg_constraint', 'pg_rewrite', 'subject_topics']) {
    assert.ok(sql.includes(required), `Diagnostic audit must inspect ${required}.`);
}
console.log('IC11 topic insert error audit static check passed.');
