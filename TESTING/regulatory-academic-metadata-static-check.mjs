import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(here, '..');
const migration = readFileSync(
  resolve(
    repositoryRoot,
    'supabase',
    'migrations',
    '20260727120000_map_regulatory_metadata_and_exam_information.sql'
  ),
  'utf8'
);
const rollback = readFileSync(
  resolve(
    repositoryRoot,
    'supabase',
    'rollbacks',
    '20260727120000_map_regulatory_metadata_and_exam_information.sql'
  ),
  'utf8'
);
const verification = readFileSync(
  resolve(
    here,
    'sql',
    'regulatory-academic-metadata-verification.sql'
  ),
  'utf8'
);
const register = JSON.parse(
  readFileSync(
    resolve(repositoryRoot, 'docs', 'regulatory-source-register.json'),
    'utf8'
  )
);

const createdTables = [
  ...migration.matchAll(/\bcreate\s+table\s+public\.([a-z0-9_]+)/gi),
].map((match) => match[1]);
assert.deepEqual(
  createdTables,
  ['regulatory_academic_publications'],
  'The migration must create only the audited missing metadata table.'
);

for (const reusedTable of [
  'qualification_levels',
  'exam_authorities',
  'training_programmes',
  'programme_sections',
  'subjects',
]) {
  assert.doesNotMatch(
    migration,
    new RegExp(`create\\s+table\\s+public\\.${reusedTable}\\b`, 'i'),
    `Existing table ${reusedTable} must be reused.`
  );
}

for (const subjectCode of ['IC01', 'IC02', 'IC11', 'IC14']) {
  assert.ok(
    register.pilot_subjects.some(
      (subject) => subject.subject_code === subjectCode
    ),
    `${subjectCode} must be approved in the source register.`
  );
  assert.ok(
    migration.includes(`'${subjectCode}'`),
    `${subjectCode} must be covered by the hierarchy mapping.`
  );
}

for (const withdrawnCode of ['IC23', 'IC82']) {
  assert.ok(
    register.withdrawn_subjects.some(
      (subject) => subject.subject_code === withdrawnCode
    ),
    `${withdrawnCode} must remain governed as withdrawn.`
  );
}

const sessionSourceIds = register.documents
  .filter((document) => document.session_code)
  .map((document) => document.id);
for (const sourceId of sessionSourceIds) {
  assert.ok(
    migration.includes(`'${sourceId}'`),
    `Session source ${sourceId} must be seeded from the approved register.`
  );
}

assert.match(
  migration,
  /create\s+function\s+public\.get_exam_information\s*\(\s*p_authority_code\s+text[\s\S]*p_session_code\s+text[\s\S]*p_subject_code\s+text/i
);
assert.match(migration, /source\.valid_until\s*>=\s*current_date/i);
assert.match(migration, /security\s+definer[\s\S]*set\s+search_path\s*=\s*''/i);
assert.match(
  migration,
  /revoke\s+all[\s\S]*get_exam_information\(text,text,text\)[\s\S]*from\s+anon/i
);
assert.match(
  migration,
  /grant\s+execute[\s\S]*get_exam_information\(text,text,text\)[\s\S]*to\s+authenticated/i
);
assert.doesNotMatch(
  migration,
  /\b(auth\.users|profiles|email|mobile|phone)\b/i,
  'The academic metadata migration must not access personal data.'
);
assert.doesNotMatch(
  migration,
  /\barchive_path\b/i,
  'Local archive paths must not enter the database.'
);

assert.match(rollback, /drop\s+function\s+if\s+exists\s+public\.get_exam_information/i);
assert.match(rollback, /drop\s+table\s+if\s+exists\s+public\.regulatory_academic_publications/i);
assert.match(rollback, /delete\s+from\s+public\.subjects/i);

for (const expected of [
  'v_source_count <> 18',
  'source.valid_until >= CURRENT_DATE',
  'anon must not execute get_exam_information',
  'authenticated cannot execute get_exam_information',
]) {
  assert.ok(
    verification.includes(expected),
    `Verification must include: ${expected}`
  );
}

console.log('Regulatory academic metadata static checks passed.');
