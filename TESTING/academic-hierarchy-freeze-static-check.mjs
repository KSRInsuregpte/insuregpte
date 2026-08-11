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
const sectionRepairMigration = readFileSync(resolve(
  root,
  'supabase/migrations/20260811100000_repair_programme_section_assignments.sql'
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
const deploymentDocument = readFileSync(
  resolve(root, 'docs/ACADEMIC_HIERARCHY_DEPLOYMENT.md'),
  'utf8'
);
const predeploymentAudit = readFileSync(resolve(
  here,
  'sql/academic-hierarchy-predeployment-audit.sql'
), 'utf8');
const legacyDependencyAudit = readFileSync(resolve(
  here,
  'sql/academic-hierarchy-legacy-dependency-audit.sql'
), 'utf8');

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
  'Migration must enforce the frozen subject-category constraint.'
);

for (const marker of [
  '$iii_optional_credit_consolidation$',
  'An unaudited subject remains under III Optional Credit.',
  "'IC14'",
  "'IC23', 'IC24', 'IC27', 'IC57'",
  "'IC82', 'IC83', 'IC85', 'IC86'",
  'v_licentiate_section_id',
  'v_associate_section_id',
  'v_fellowship_section_id',
]) {
  assert.ok(
    migration.includes(marker),
    `Legacy Optional Credit mapping is missing ${marker}.`
  );
}
assert.ok(
  verification.includes(
    'A legacy III Optional Credit subject has an incorrect destination.'
  ),
  'Verification must validate every audited Optional Credit destination.'
);
for (const [label, sql] of [
  ['hierarchy freeze', migration],
  ['section repair', sectionRepairMigration],
]) {
  assert.match(sql, /\bBEGIN\s*;/i, `${label} migration must be transactional.`);
  assert.match(sql, /\bCOMMIT\s*;/i, `${label} migration must commit explicitly.`);
}

for (const marker of [
  'populateProgrammeSectionSelect',
  'section.training_programme_id',
  'preferredSection.code',
  'academicHierarchyIsCurrent',
  'requireCurrentAcademicHierarchy',
  '20260811100000',
  "byId('subject-programme').addEventListener('change'",
  "byId('exam-programme').addEventListener('change'",
]) {
  assert.ok(
    adminJavascript.includes(marker),
    `Programme-dependent section selection is missing ${marker}.`
  );
}
assert.match(
  sectionRepairMigration,
  /target_section\.training_programme_id\s*=\s*subject_record\.training_programme_id/i,
  'The repair must remap subjects to a same-programme section.'
);

for (const marker of [
  'deploys frontend files only',
  '20260810120000_freeze_academic_hierarchy.sql',
  '20260811100000_repair_programme_section_assignments.sql',
  'academic-hierarchy-freeze-verification.sql',
  'Life Broker Training',
]) {
  assert.ok(
    deploymentDocument.includes(marker),
    `Deployment guide is missing ${marker}.`
  );
}
assert.ok(
  adminHtml.includes('js/admin.js?v=20260811b'),
  'The Admin page must load the corrected hierarchy client version.'
);
const auditWithoutCommentsOrStrings = predeploymentAudit
  .replace(/\/\*[\s\S]*?\*\//g, ' ')
  .replace(/--.*$/gm, ' ')
  .replace(/'(?:''|[^'])*'/g, "''");
assert.doesNotMatch(
  auditWithoutCommentsOrStrings,
  /\b(?:insert|update|delete|create|alter|drop|truncate|grant|revoke|call|copy|do)\b/i,
  'The pre-deployment hierarchy audit must remain read-only.'
);
assert.doesNotMatch(
  predeploymentAudit,
  /pg_catalog\.coalesce\s*\(/i,
  'COALESCE is SQL syntax and must not be schema-qualified.'
);
const legacyAuditWithoutCommentsOrStrings = legacyDependencyAudit
  .replace(/\/\*[\s\S]*?\*\//g, ' ')
  .replace(/--.*$/gm, ' ')
  .replace(/'(?:''|[^'])*'/g, "''");
assert.doesNotMatch(
  legacyAuditWithoutCommentsOrStrings,
  /\b(?:insert|update|delete|create|alter|drop|truncate|grant|revoke|call|copy|do)\b/i,
  'The legacy dependency audit must remain read-only.'
);
assert.doesNotMatch(
  legacyDependencyAudit,
  /pg_catalog\.coalesce\s*\(/i,
  'The legacy audit must not schema-qualify COALESCE.'
);
for (const legacyCode of [
  'specialised_training',
  'iii_optional_credit',
  'nia_life_broker',
]) {
  assert.ok(
    legacyDependencyAudit.includes(legacyCode),
    `The dependency audit must cover ${legacyCode}.`
  );
}
assert.ok(
  deploymentDocument.includes('academic-hierarchy-predeployment-audit.sql')
    && deploymentDocument.includes('Attach that CSV'),
  'The deployment guide must require audit review before migration.'
);
assert.match(
  sectionRepairMigration,
  /current_section\.training_programme_id\s+IS DISTINCT FROM\s+subject_record\.training_programme_id/i,
  'The repair must target only mismatched subject assignments.'
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
  /select\s+id="subject-category"\s+required/i
);
assert.ok(
  !adminHtml.includes('subject-category-options'),
  'Admin subject category must not allow custom datalist values.'
);
assert.ok(
  !adminJavascript.includes('populateSubjectCategoryOptions'),
  'Admin must not add saved custom categories to the frozen dropdown.'
);

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
  customCategoryResult.errors.some((error) => error.message.includes(
    'category must'
  )),
  'Bulk upload must reject a custom category.'
);

for (const category of [
  'General Insurance',
  'Life Insurance',
  'Common (Life & Non-Life)',
  'Regulation and Compliance',
]) {
  values.category = category;
  const approvedCategoryCsv = [
    headers.join(','),
    headers.map((header) => values[header]).join(','),
  ].join('\r\n');
  const approvedResult = bulkUpload.validateCsv(
    'subjects',
    approvedCategoryCsv
  );
  assert.ok(
    !approvedResult.errors.some((error) => error.message.includes(
      'category must'
    )),
    `Bulk upload must accept ${category}.`
  );
}

for (const marker of [
  'Direct Broker – General, Life and Health Training',
  'General, Life and Health Training',
]) {
  assert.ok(migration.includes(marker), `Migration is missing ${marker}.`);
  assert.ok(freezeDocument.includes(marker),
    `Frozen documentation is missing ${marker}.`);
}

assert.ok(
  freezeDocument.includes('**Architecture Version:** 1.6'),
  'Frozen documentation must identify Architecture Version 1.6.'
);

console.log('Academic hierarchy freeze static checks passed.');
