import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const here = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(here, '..');
const migration = readFileSync(
  resolve(
    repositoryRoot,
    'supabase',
    'migrations',
    '20260730150000_add_admin_bulk_import.sql'
  ),
  'utf8'
);
const rollback = readFileSync(
  resolve(
    repositoryRoot,
    'supabase',
    'rollbacks',
    '20260730150000_add_admin_bulk_import.sql'
  ),
  'utf8'
);
const verification = readFileSync(
  resolve(here, 'sql', 'admin-bulk-import-verification.sql'),
  'utf8'
);
const adminHtml = readFileSync(
  resolve(repositoryRoot, 'admin-dashboard.html'),
  'utf8'
);
const adminJavascript = readFileSync(
  resolve(repositoryRoot, 'js', 'admin.js'),
  'utf8'
);
const bulkJavascript = readFileSync(
  resolve(repositoryRoot, 'js', 'admin-bulk-upload.js'),
  'utf8'
);

assert.doesNotMatch(
  migration,
  /\bcreate\s+table\b/i,
  'Bulk upload must not create a duplicate table.'
);
assert.match(
  migration,
  /create\s+function\s+public\.admin_bulk_import\s*\(\s*p_entity\s+text,\s*p_rows\s+jsonb\s*\)/i
);
for (const delegatedFunction of [
  'public.admin_save_subject(v_row)',
  'public.admin_save_question(v_payload)',
  'public.admin_set_user_status(',
]) {
  assert.ok(
    migration.includes(delegatedFunction),
    `Bulk import must delegate to ${delegatedFunction}.`
  );
}
assert.match(
  migration,
  /IF\s+NOT\s+public\.fn_is_admin\(\)/i,
  'Every bulk request must recheck the active administrator role.'
);
assert.match(
  migration,
  /v_row_count\s+NOT\s+BETWEEN\s+1\s+AND\s+250/i,
  'The server must bound each atomic import.'
);
assert.match(
  migration,
  /Deploy the administrator question-answer storage repair before bulk import/i,
  'Question bulk import must require the scoring-compatible answer repair.'
);
assert.doesNotMatch(
  migration,
  /\b(insert\s+into|update)\s+(public\.)?(subjects|questions|profiles|auth\.users)\b/i,
  'The coordinator must not duplicate existing save logic.'
);
assert.match(
  rollback,
  /drop\s+function\s+if\s+exists\s+public\.admin_bulk_import\s*\(\s*text,\s*jsonb\s*\)/i
);
for (const expectedVerification of [
  'Success. No rows returned',
  'Only authenticated administrators may reach the bulk-import RPC',
  'Bulk import must delegate to existing audited save functions',
  'A request without an authenticated administrator was accepted',
]) {
  assert.ok(
    verification.includes(expectedVerification),
    `Missing verification: ${expectedVerification}.`
  );
}

for (const requiredHtml of [
  'data-admin-tab="bulk-upload"',
  'id="panel-bulk-upload"',
  'id="bulk-upload-entity"',
  'id="bulk-upload-file"',
  'id="run-bulk-upload-button"',
  'id="download-selected-template"',
  'admin-upload-templates/questions.csv',
  'admin-upload-templates/admin-bulk-upload-formats.xlsx',
]) {
  assert.ok(adminHtml.includes(requiredHtml), `Missing ${requiredHtml}.`);
}
assert.ok(
  adminJavascript.includes("'admin_bulk_import'"),
  'The Admin frontend must use the guarded bulk coordinator.'
);
assert.doesNotMatch(
  adminJavascript,
  /\.from\s*\(/,
  'Bulk upload must not weaken the RPC-only frontend boundary.'
);

const browserContext = { window: {} };
vm.runInNewContext(bulkJavascript, browserContext);
const bulkUpload = browserContext.window.InsureGPTEAdminBulkUpload;
assert.ok(bulkUpload, 'The browser CSV validator was not exposed.');
assert.equal(bulkUpload.MAX_ROWS, 250);

const quotedQuestionCsv = [
  bulkUpload.FORMATS.questions.columns.join(','),
  [
    '',
    'IC01',
    '"What does a policy cover, in principle?"',
    '"Option, one"',
    'Option two',
    'Option three',
    'Option four',
    'A',
    '"Explains the correct answer, clearly."',
    'Hard',
    '1',
    '0',
    '1',
    'true',
  ].join(','),
].join('\r\n');
const validQuestionResult = bulkUpload.validateCsv(
  'questions',
  quotedQuestionCsv
);
assert.equal(validQuestionResult.errors.length, 0);
assert.equal(validQuestionResult.rows[0].subject_code, 'IC01');
assert.equal(validQuestionResult.rows[0].option_a, 'Option, one');
assert.equal(validQuestionResult.rows[0].difficulty_level, 'hard');

const invalidQuestionResult = bulkUpload.validateCsv(
  'questions',
  quotedQuestionCsv.replace(',A,', ',E,')
);
assert.ok(
  invalidQuestionResult.errors.some(
    (error) => error.message.includes('correct_option')
  ),
  'An invalid answer tag must be rejected before upload.'
);

const userResult = bulkUpload.validateCsv(
  'users',
  'email,status\r\nlearner@example.com,active'
);
assert.equal(userResult.errors.length, 0);
assert.deepEqual(
  JSON.parse(JSON.stringify(userResult.rows)),
  [{ email: 'learner@example.com', status: 'active' }]
);

const invalidSubjectResult = bulkUpload.validateCsv(
  'subjects',
  [
    bulkUpload.FORMATS.subjects.columns.join(','),
    ',IC99,New Subject,,,,,Licentiate,2026,1,10,499,INR,true,true',
  ].join('\n')
);
assert.ok(
  invalidSubjectResult.errors.some(
    (error) => error.message.includes('new subject')
  ),
  'New subjects must remain inactive during the first upload.'
);

for (const [entity, fileName] of [
  ['users', 'users.csv'],
  ['subjects', 'subjects.csv'],
  ['questions', 'questions.csv'],
]) {
  const template = readFileSync(
    resolve(repositoryRoot, 'admin-upload-templates', fileName),
    'utf8'
  ).trim();
  assert.equal(
    template,
    [...bulkUpload.FORMATS[entity].columns].join(','),
    `${fileName} must match its browser and server contract.`
  );
}

console.log(
  'Admin bulk-upload checks passed: fixed CSV formats, quoted-field parsing, ' +
  'browser validation, atomic audited RPC delegation, and no duplicate tables.'
);
