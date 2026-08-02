import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const auditPath = resolve(here, 'sql', 'safety-system-object-audit.sql');
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
  'The safety-system audit must remain read-only.'
);

for (const forbiddenSelection of [
  'first_name',
  'last_name',
  'mobile',
  'email',
  'ip_address',
  'user_agent',
  'payload',
  'token',
  'question_text',
  'correct_option',
  'explanation',
]) {
  assert.doesNotMatch(
    withoutQuotedText,
    new RegExp(`\\b${forbiddenSelection}\\b`, 'i'),
    `The audit must not select sensitive/content field ${forbiddenSelection}.`
  );
}

for (const expected of [
  'audit_log_entries',
  'profiles',
  'active_client_leases',
  'admin_audit_events',
  'security_events',
  'account_enforcement_cases',
  'notification_outbox',
  'admin_set_user_status(uuid,text)',
  'fn_enforce_active_auth_session()',
  'activate_verified_user()',
  'continuously_claimed_over_48_hours',
  'pg_cron',
  'pg_net',
  'pg_get_constraintdef',
  'pg_get_triggerdef',
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

console.log('Safety-system object audit static check passed.');
