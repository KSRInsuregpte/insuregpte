import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(here, '..');
const migration = readFileSync(
  resolve(
    repositoryRoot,
    'supabase',
    'migrations',
    '20260731120000_expand_admin_bulk_import.sql'
  ),
  'utf8'
);
const rollback = readFileSync(
  resolve(
    repositoryRoot,
    'supabase',
    'rollbacks',
    '20260731120000_expand_admin_bulk_import.sql'
  ),
  'utf8'
);
const verification = readFileSync(
  resolve(
    here,
    'sql',
    'admin-expanded-bulk-import-verification.sql'
  ),
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
  'The expansion must reuse the existing tables.'
);
for (const requiredFunction of [
  'admin_save_academic_content',
  'admin_save_entitlement',
  'admin_bulk_import',
]) {
  assert.match(
    migration,
    new RegExp(`function\\s+public\\.${requiredFunction}`, 'i'),
    `Missing ${requiredFunction}.`
  );
}
for (const protectedBoundary of [
  'public.fn_is_admin()',
  'public.admin_save_exam_information(v_payload)',
  'public.admin_save_subject(v_row)',
  'public.admin_save_question(v_payload)',
  'public.admin_set_user_status(',
  'public.admin_save_academic_content(',
  'public.admin_save_entitlement(v_row)',
  'Payment or subscription entitlements cannot be changed',
  'official_notice',
]) {
  assert.ok(
    migration.includes(protectedBoundary),
    `Missing protected boundary: ${protectedBoundary}.`
  );
}
assert.match(
  rollback,
  /drop\s+function\s+if\s+exists\s+public\.admin_save_entitlement/i
);
assert.match(
  rollback,
  /drop\s+function\s+if\s+exists\s+public\.admin_save_academic_content/i
);
for (const verificationText of [
  'Success. No rows returned',
  'Unauthenticated academic save was accepted',
  'Unauthenticated entitlement save was accepted',
  'official_notice',
]) {
  assert.ok(
    verification.includes(verificationText),
    `Missing SQL verification: ${verificationText}.`
  );
}

for (const htmlMarker of [
  'id="download-selected-template"',
  'value="qualification_levels"',
  'value="exam_authorities"',
  'value="training_programmes"',
  'value="programme_sections"',
  'value="modules"',
  'value="chapters"',
  'value="topics"',
  'value="learning_resource_types"',
  'value="learning_resources"',
  'value="flashcards"',
  'value="exam_information"',
  'value="entitlements"',
  'value="official_notice"',
]) {
  assert.ok(adminHtml.includes(htmlMarker), `Missing ${htmlMarker}.`);
}
assert.ok(
  adminJavascript.includes('syncBulkTemplateLink'),
  'The selected upload type must control its CSV download.'
);
assert.doesNotMatch(
  adminJavascript,
  /\.from\s*\(/,
  'The Admin frontend must remain RPC-only.'
);

const browserContext = { window: {} };
vm.runInNewContext(bulkJavascript, browserContext);
const bulkUpload =
  browserContext.window.InsureGPTEAdminBulkUpload;
assert.ok(bulkUpload, 'The expanded CSV validator was not exposed.');

const samples = {
  qualification_levels: {
    code: 'diploma',
    name: 'Specialised Diploma',
    description: 'Approved learning classification',
    display_order: '4',
    is_active: 'false',
  },
  exam_authorities: {
    code: 'iii',
    name: 'Insurance Institute of India',
    short_name: 'III',
    description: 'Examination authority',
    official_website: 'https://www.insuranceinstituteofindia.com',
    disclaimer_text: 'InsureGPTE is an independent learning platform.',
    display_order: '1',
    is_active: 'true',
  },
  training_programmes: {
    authority_code: 'iii',
    code: 'iii_licentiate',
    name: 'Licentiate',
    programme_category: 'professional_qualification',
    description: 'Exam preparation',
    official_pass_percentage: '60',
    recommended_readiness_percentage: '75',
    exam_question_count: '',
    exam_duration_minutes: '',
    negative_marking: 'false',
    display_order: '1',
    is_active: 'true',
  },
  programme_sections: {
    programme_code: 'iii_licentiate',
    code: 'compulsory',
    name: 'Compulsory Subjects',
    description: 'Required section',
    exam_question_count: '50',
    recommended_practice_question_count: '200',
    display_order: '1',
    is_active: 'true',
  },
  modules: {
    subject_code: 'IC01',
    code: 'module_01',
    title: 'Foundations',
    description: 'Foundational module',
    display_order: '1',
    is_active: 'false',
  },
  chapters: {
    subject_code: 'IC01',
    module_code: 'module_01',
    chapter_number: '1',
    code: 'chapter_01',
    title: 'Risk and Insurance',
    description: 'Chapter description',
    display_order: '1',
    is_active: 'false',
  },
  topics: {
    subject_code: 'IC01',
    module_code: 'module_01',
    chapter_code: 'chapter_01',
    topic_number: '1',
    code: 'topic_01',
    title: 'Risk concepts',
    description: 'Topic description',
    learning_objective: 'Understand risk',
    practical_relevance: 'Apply concepts',
    estimated_study_minutes: '20',
    difficulty_level: 'foundation',
    display_order: '1',
    is_exam_relevant: 'true',
    is_active: 'false',
  },
  learning_resource_types: {
    code: 'NOTE',
    name: 'Learning Note',
    description: 'Written learning material',
    icon_name: 'book-open',
    display_order: '1',
    is_active: 'true',
  },
  learning_resources: {
    subject_code: 'IC01',
    module_code: 'module_01',
    chapter_code: 'chapter_01',
    topic_code: 'topic_01',
    resource_type_code: 'NOTE',
    code: 'IC01:NOTE:001',
    title: 'Risk concepts note',
    short_description: 'Short guided note',
    content: 'This note explains the core risk concepts.',
    external_url: '',
    attachment_path: '',
    author_name: 'InsureGPTE',
    version_no: '1',
    estimated_read_minutes: '10',
    display_order: '1',
    is_exam_relevant: 'true',
    is_premium: 'false',
    is_active: 'false',
  },
  flashcards: {
    subject_code: 'IC01',
    module_code: 'module_01',
    chapter_code: 'chapter_01',
    topic_code: 'topic_01',
    code: 'IC01:CARD:001',
    question: 'What is risk?',
    answer: 'Uncertainty concerning a possible loss.',
    explanation: 'Risk concerns uncertain outcomes.',
    display_order: '1',
    difficulty_level: 'foundation',
    is_exam_relevant: 'true',
    is_active: 'false',
  },
  exam_information: {
    id: '',
    source_document_id: 'III-OCT-2026-TIMETABLE',
    authority_code: 'iii',
    subject_code: '',
    programme_code: 'iii_licentiate',
    section_code: '',
    session_code: 'III-OCT-2026',
    document_type: 'schedule',
    title: 'October 2026 examination schedule',
    geographic_scope: 'all',
    official_url: 'https://example.org/official-schedule.pdf',
    discovery_url: 'https://example.org/examinations',
    published_on: '2026-08-01',
    effective_from: '2026-08-01',
    valid_until: '2026-11-30',
    content_usage: 'metadata_only',
    verification_status: 'official_url_verified',
    verified_on: '2026-08-01',
    is_active: 'true',
  },
  entitlements: {
    id: '',
    email: 'learner@example.com',
    subject_code: 'IC01',
    access_type: 'admin_grant',
    status: 'active',
    valid_from: '2026-08-01T00:00:00+05:30',
    valid_until: '2026-08-31T23:59:59+05:30',
    source_reference: 'ADMIN-GRANT-2026-001',
  },
};

function csvCell(value) {
  const text = String(value ?? '');
  return /[",\r\n]/.test(text)
    ? `"${text.replaceAll('"', '""')}"`
    : text;
}

for (const [entity, sample] of Object.entries(samples)) {
  const format = bulkUpload.FORMATS[entity];
  assert.ok(format, `Missing browser format for ${entity}.`);
  const csv = [
    [...format.columns].join(','),
    [...format.columns].map(
      (column) => csvCell(sample[column])
    ).join(','),
  ].join('\r\n');
  const result = bulkUpload.validateCsv(entity, csv);
  assert.deepEqual(
    JSON.parse(JSON.stringify(result.errors)),
    [],
    `${entity} sample failed: ${JSON.stringify(result.errors)}`
  );
}

for (const [entity, format] of Object.entries(
  bulkUpload.FORMATS
)) {
  const template = readFileSync(
    resolve(
      repositoryRoot,
      'admin-upload-templates',
      format.fileName
    ),
    'utf8'
  ).trim();
  assert.equal(
    template,
    [...format.columns].join(','),
    `${format.fileName} must match the browser contract.`
  );
  assert.ok(entity.length > 0);
}

console.log(
  'Expanded Admin bulk-upload checks passed: academic hierarchy, learning ' +
  'content, exam information, non-payment entitlements, fixed CSV formats, ' +
  'RPC-only frontend, audited server routes, and no duplicate tables.'
);
