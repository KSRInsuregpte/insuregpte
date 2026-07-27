import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const auditPath = resolve(here, 'sql', 'regulatory-academic-hierarchy-audit.sql');
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
  'The hierarchy audit must remain read-only.'
);

assert.doesNotMatch(
  sql,
  /\b(auth\.users|profiles|email|mobile|phone)\b/i,
  'The hierarchy audit must not inspect personal identity or profile data.'
);

for (const expected of [
  'qualification_levels',
  'exam_authorities',
  'training_programmes',
  'programme_sections',
  'subjects',
  'learning_resource_types',
  'learning_resources',
  'information_schema.columns',
  'pg_get_function_identity_arguments',
  'get_exam_information',
  'get_exam_session_information',
  'get_regulatory_subject_metadata',
  'IC01',
  'IC02',
  'IC11',
  'IC14',
  'IC23',
  'IC82',
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

console.log('Regulatory hierarchy audit static check passed.');
