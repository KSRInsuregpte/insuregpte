import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const auditPath = resolve(here, 'sql', 'admin-commerce-object-audit.sql');
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
  'The admin/commerce audit must remain read-only.'
);

for (const forbiddenSelection of [
  'question_text',
  'correct_option',
  'explanation',
  'first_name',
  'last_name',
  'mobile',
  'company_name',
  'street_name',
  'pin_code',
]) {
  assert.doesNotMatch(
    withoutQuotedText,
    new RegExp(`\\b${forbiddenSelection}\\b`, 'i'),
    `The audit must not select sensitive/content field ${forbiddenSelection}.`
  );
}

for (const expected of [
  'profiles',
  'subjects',
  'questions',
  'regulatory_academic_publications',
  'carts',
  'cart_items',
  'user_entitlements',
  'profile_role_status_counts',
  'question_distribution',
  'difficulty_level',
  'fn_is_admin',
  'admin_save_subject',
  'admin_save_question',
  'admin_set_user_status',
  'admin_save_exam_information',
  'create_payment_order',
  'verify_payment_webhook',
  'pg_get_function_identity_arguments',
  'pg_get_constraintdef',
  'has_table_privilege',
]) {
  assert.ok(sql.includes(expected), `Expected audit coverage for ${expected}.`);
}

assert.match(
  sql,
  /select\s+audit_section,\s*object_name,\s*details/i,
  'The audit must return one exportable result shape.'
);
assert.equal(
  (withoutQuotedText.match(/;\s*$/g) ?? []).length,
  1,
  'The audit must end as one SQL statement.'
);

console.log('Admin and commerce audit static check passed.');
