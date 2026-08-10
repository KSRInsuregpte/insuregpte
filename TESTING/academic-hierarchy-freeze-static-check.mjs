import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');
const migration = readFileSync(resolve(
  root,
  'supabase/migrations/20260810120000_freeze_academic_hierarchy.sql'
), 'utf8');
const rollback = readFileSync(resolve(
  root,
  'supabase/rollbacks/20260810120000_freeze_academic_hierarchy.sql'
), 'utf8');
const verification = readFileSync(resolve(
  here,
  'sql/academic-hierarchy-freeze-verification.sql'
), 'utf8');
const adminHtml = readFileSync(resolve(root, 'admin-dashboard.html'), 'utf8');
const adminJavascript = readFileSync(resolve(root, 'js/admin.js'), 'utf8');
const bulkJavascript = readFileSync(
  resolve(root, 'js/admin-bulk-upload.js'),
  'utf8'
);
const freezeDocument = readFileSync(
  resolve(root, 'docs/ACADEMIC_HIERARCHY_FREEZE.md'),
  'utf8'
);

for (const marker of [
  'iii_spl_diploma',
  'iii_surveyor',
  'surveyor_exam',
  'specialized_diploma_exam',
  'compulsory_optional',
  'optional_credit',
  'Common (Life & Non-Life)',
]) {
  assert.ok(migration.includes(marker), `Migration is missing ${marker}.`);
  assert.ok(
    freezeDocument.includes(marker),
    `Frozen documentation is missing ${marker}.`
  );
}
assert.ok(
  migration.includes('chk_subjects_valid_category'),
  'Migration must enforce a valid, extensible subject category constraint.'
);

assert.match(
  migration,
  /update\s+public\.subjects[\s\S]*training_programme_id\s*=\s*v_direct_id/i,
  'Life Broker subjects must move to Direct Broker before deletion.'
);
assert.match(
  migration,
  /delete\s+from\s+public\.training_programmes[\s\S]*v_life_id/i,
  'The standalone Life Broker programme must be removed.'
);
assert.doesNotMatch(
  migration,
  /delete\s+from\s+public\.subjects/i,
  'Hierarchy normalization must never delete subjects.'
);
assert.ok(
  /preserving\s+(?:--\s*)?all normalized hierarchy data/i.test(rollback),
  'Rollback must explicitly preserve normalized data.'
);
assert.ok(
  verification.includes("code = 'nia_life_broker'"),
  'Verification must reject a remaining Life Broker programme.'
);

for (const category of [
  'General Insurance',
  'Life Insurance',
  'Common (Life &amp; Non-Life)',
  'Regulation and Compliance',
]) {
  assert.ok(adminHtml.includes(category), `Admin dropdown is missing ${category}.`);
}
assert.match(
  adminHtml,
  /input\s+id="subject-category"\s+list="subject-category-options"\s+required/i
);
assert.ok(
  adminHtml.includes('id="subject-category-options"'),
  'Admin subject category suggestions require a datalist.'
);
for (const marker of [
  'DEFAULT_SUBJECT_CATEGORIES',
  'populateSubjectCategoryOptions',
  'categories.add(category)',
]) {
  assert.ok(
    adminJavascript.includes(marker),
    `Admin category suggestions are missing ${marker}.`
  );
}

const browserContext = { window: {} };
vm.runInNewContext(bulkJavascript, browserContext);
const bulkUpload = browserContext.window.InsureGPTEAdminBulkUpload;
const subjectFormat = bulkUpload.FORMATS.subjects;
const headers = [...subjectFormat.columns];
const values = Object.fromEntries(headers.map((header) => [header, '']));
Object.assign(values, {
  code: 'IC99',
  title: 'Approved Subject',
  category: 'Specialty Risks',
  display_order: '1',
  demo_question_limit: '10',
  price: '0',
  currency_code: 'INR',
  is_demo_available: 'false',
  is_active: 'false',
});
const customCategoryCsv = [
  headers.join(','),
  headers.map((header) => values[header]).join(','),
].join('\r\n');
const customCategoryResult = bulkUpload.validateCsv(
  'subjects',
  customCategoryCsv
);
assert.ok(
  !customCategoryResult.errors.some((error) => error.message.includes(
    'category must'
  )),
  'Bulk upload must accept a valid reviewed custom category.'
);

for (const marker of [
  'Direct Broker Training',
  'General, Life and Health Training',
]) {
  assert.ok(migration.includes(marker), `Migration is missing ${marker}.`);
  assert.ok(freezeDocument.includes(marker),
    `Frozen documentation is missing ${marker}.`);
}

console.log('Academic hierarchy freeze static checks passed.');
