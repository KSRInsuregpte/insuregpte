import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(here, '..');
const migrationPath = resolve(
  repositoryRoot,
  'supabase',
  'migrations',
  '20260727180000_build_admin_portal.sql'
);
const rollbackPath = resolve(
  repositoryRoot,
  'supabase',
  'rollbacks',
  '20260727180000_build_admin_portal.sql'
);
const verificationPath = resolve(
  here,
  'sql',
  'admin-portal-verification.sql'
);
const migration = readFileSync(migrationPath, 'utf8');
const rollback = readFileSync(rollbackPath, 'utf8');
const verification = readFileSync(verificationPath, 'utf8');
const adminHtml = readFileSync(
  resolve(repositoryRoot, 'admin-dashboard.html'),
  'utf8'
);
const adminJavascript = readFileSync(
  resolve(repositoryRoot, 'js', 'admin.js'),
  'utf8'
);
const dashboardHtml = readFileSync(
  resolve(repositoryRoot, 'dashboard.html'),
  'utf8'
);
const dashboardJavascript = readFileSync(
  resolve(repositoryRoot, 'js', 'dashboard.js'),
  'utf8'
);

const createdTables = [
  ...migration.matchAll(/\bcreate\s+table\s+public\.([a-z0-9_]+)/gi),
].map((match) => match[1]);
assert.deepEqual(
  createdTables,
  ['admin_audit_events'],
  'The admin migration must create only the audited missing history table.'
);

for (const reusedTable of [
  'profiles',
  'subjects',
  'questions',
  'qualification_levels',
  'exam_authorities',
  'training_programmes',
  'programme_sections',
  'regulatory_academic_publications',
]) {
  assert.doesNotMatch(
    migration,
    new RegExp(`create\\s+table\\s+public\\.${reusedTable}\\b`, 'i'),
    `Existing table ${reusedTable} must be reused.`
  );
}

const functionSignatures = [
  'fn_is_admin()',
  'get_admin_portal_summary()',
  'admin_list_subjects()',
  'admin_save_subject(jsonb)',
  'admin_list_questions(bigint)',
  'admin_save_question(jsonb)',
  'admin_list_users()',
  'admin_set_user_status(uuid,text)',
  'admin_list_exam_information()',
  'admin_save_exam_information(jsonb)',
  'admin_retire_exam_information(bigint)',
  'admin_list_audit_events(integer)',
];
for (const signature of functionSignatures) {
  const functionName = signature.split('(')[0];
  assert.match(
    migration,
    new RegExp(`create\\s+function\\s+public\\.${functionName}\\s*\\(`, 'i'),
    `Missing admin function ${signature}.`
  );
  assert.match(
    rollback,
    new RegExp(`drop\\s+function\\s+if\\s+exists\\s+public\\.${functionName}\\s*\\(`, 'i'),
    `Rollback must remove ${signature}.`
  );
  assert.ok(
    verification.includes(`public.${signature}`),
    `Verification must cover ${signature}.`
  );
}

assert.match(
  migration,
  /create\s+function\s+public\.fn_is_admin\(\)[\s\S]*role\s*=\s*'admin'[\s\S]*status\s*=\s*'active'/i
);
assert.match(
  migration,
  /create\s+function\s+public\.admin_save_question[\s\S]*when\s+'easy'\s+then\s+'foundation'[\s\S]*when\s+'moderate'\s+then\s+'intermediate'[\s\S]*when\s+'hard'\s+then\s+'advanced'/i
);
assert.match(
  migration,
  /create\s+function\s+public\.admin_set_user_status[\s\S]*\('active',\s*'verification_pending'\)/i
);
assert.doesNotMatch(
  migration,
  /\b(update|delete|insert\s+into)\s+auth\.users\b/i,
  'The admin migration must not modify Supabase Auth records directly.'
);
assert.doesNotMatch(
  migration,
  /\b(payment|payment_order|webhook_secret|gateway_signature)\b/i,
  'Payment objects require a separately approved provider boundary.'
);
assert.match(
  migration,
  /revoke\s+all\s+on\s+table\s+public\.admin_audit_events[\s\S]*from\s+public,\s*anon,\s*authenticated,\s*service_role/i
);
assert.match(
  migration,
  /revoke\s+all\s+on\s+table\s+public\.subjects[\s\S]*from\s+public,\s*anon,\s*authenticated/i
);
assert.match(
  migration,
  /revoke\s+all\s+on\s+table\s+public\.questions[\s\S]*from\s+public,\s*anon,\s*authenticated/i
);

for (const requiredHtml of [
  'id="admin-portal"',
  'data-admin-tab="subjects"',
  'data-admin-tab="questions"',
  'data-admin-tab="users"',
  'data-admin-tab="exam-information"',
  'data-admin-tab="audit"',
]) {
  assert.ok(adminHtml.includes(requiredHtml), `Missing ${requiredHtml}.`);
}

for (const rpcName of [
  'fn_is_admin',
  'get_admin_portal_summary',
  'admin_list_subjects',
  'admin_save_subject',
  'admin_list_questions',
  'admin_save_question',
  'admin_list_users',
  'admin_set_user_status',
  'admin_list_exam_information',
  'admin_save_exam_information',
  'admin_retire_exam_information',
  'admin_list_audit_events',
]) {
  assert.ok(
    adminJavascript.includes(`'${rpcName}'`),
    `Admin frontend must use ${rpcName}.`
  );
}

assert.doesNotMatch(
  adminJavascript,
  /\.from\s*\(/,
  'The admin frontend must not access database tables directly.'
);
assert.ok(
  dashboardHtml.includes('id="admin-link"')
    && dashboardHtml.includes('class="hidden'),
  'The dashboard admin link must be hidden by default.'
);
assert.ok(
  dashboardJavascript.includes("client.rpc('fn_is_admin')")
    && dashboardJavascript.includes("isAdmin === true"),
  'Only a confirmed administrator may see the dashboard admin link.'
);

for (const expected of [
  'Browser roles must not access admin_audit_events directly',
  'Browser roles must use RPCs for subjects and questions',
  'anon must not execute',
  'A request without an authenticated admin was unexpectedly accepted',
]) {
  assert.ok(
    verification.includes(expected),
    `Verification must include: ${expected}`
  );
}

console.log(
  'Admin portal static checks passed: authorization, audited RPC-only writes, ' +
  'difficulty mapping, user activation limits, and hidden navigation.'
);
