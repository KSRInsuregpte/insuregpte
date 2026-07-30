import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repositoryRoot = path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    '..'
);
const registerPath = path.join(
    repositoryRoot,
    'docs',
    'regulatory-source-register.json'
);
const register = JSON.parse(fs.readFileSync(registerPath, 'utf8'));

function isIsoDate(value) {
    if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
        return false;
    }

    return !Number.isNaN(Date.parse(`${value}T00:00:00Z`));
}

function assertSafeArchivePath(value) {
    assert.equal(typeof value, 'string', 'archive path must be text');
    assert.ok(
        value.startsWith('1/'),
        `archive path must remain relative to the reviewed archive: ${value}`
    );
    assert.ok(!value.includes('\\'), `archive path must use forward slashes: ${value}`);
    assert.ok(!value.includes('..'), `archive path must not traverse folders: ${value}`);
    assert.ok(
        !/^[A-Za-z]:/.test(value),
        `archive path must not expose a workstation path: ${value}`
    );
}

function assertOfficialUrl(value) {
    const url = new URL(value);
    assert.equal(url.protocol, 'https:', `official URL must use HTTPS: ${value}`);
    assert.ok(
        url.hostname === 'insuranceinstituteofindia.com'
            || url.hostname.endsWith('.insuranceinstituteofindia.com'),
        `unexpected official source hostname: ${url.hostname}`
    );
}

assert.equal(register.schema_version, 1);
assert.equal(register.registry_scope, 'trial');
assert.ok(isIsoDate(register.as_of_date), 'register must include a valid as-of date');
assert.ok(Array.isArray(register.documents) && register.documents.length > 0);
assert.ok(Array.isArray(register.pilot_subjects));
assert.ok(Array.isArray(register.withdrawn_subjects));
assert.ok(Array.isArray(register.quarantine));
assert.ok(Array.isArray(register.duplicate_groups));
assert.equal(
    register.review_policy.full_study_material_may_be_republished,
    false,
    'full source books must not be approved for republication'
);
assert.equal(
    register.review_policy.filename_dates_are_authoritative,
    false,
    'document dates must not be inferred from filenames'
);

const authorityCodes = new Set(register.authorities.map((authority) => authority.code));
const documentIds = new Set();
const documentTypes = new Set([
    'handbook',
    'syllabus',
    'credit_points',
    'schedule',
    'centre_list',
    'language_list',
    'withdrawal_notice',
    'subject_amendment'
]);
const allowedUsage = new Set(['metadata_only', 'reference_only']);

for (const document of register.documents) {
    assert.ok(document.id, 'each document must have an id');
    assert.ok(!documentIds.has(document.id), `duplicate document id: ${document.id}`);
    documentIds.add(document.id);

    assert.ok(documentTypes.has(document.document_type));
    assert.ok(authorityCodes.has(document.authority_code));
    assertSafeArchivePath(document.archive_path);
    assert.ok(allowedUsage.has(document.content_usage));
    assert.ok(isIsoDate(document.verified_on));
    assert.ok(Array.isArray(document.subject_codes));

    if (document.official_url) {
        assertOfficialUrl(document.official_url);
    }
    if (document.discovery_url) {
        assertOfficialUrl(document.discovery_url);
    }
    for (const field of ['published_on', 'effective_from', 'valid_until']) {
        if (document[field] !== null && document[field] !== undefined) {
            assert.ok(isIsoDate(document[field]), `${document.id} has invalid ${field}`);
        }
    }
    if (document.session_code) {
        assert.ok(
            isIsoDate(document.valid_until),
            `${document.id} must expire after its examination session`
        );
    }
    if (document.document_type === 'subject_amendment') {
        assert.equal(
            document.subject_codes.length,
            1,
            `${document.id} must identify one amended subject`
        );
        assert.ok(
            isIsoDate(document.published_on),
            `${document.id} must record the date printed in the amendment`
        );
    }
}

const pilotCodes = register.pilot_subjects
    .map((subject) => subject.subject_code)
    .sort();
assert.deepEqual(pilotCodes, ['IC01', 'IC02', 'IC11', 'IC14']);

for (const subject of register.pilot_subjects) {
    assert.equal(subject.official_status, 'active');
    assert.equal(subject.trial_release_state, 'metadata_ready');
    assert.equal(subject.learning_content_state, 'review_required');
    assert.equal(subject.commercial_state, 'not_approved');
    for (const sourceId of subject.source_document_ids) {
        assert.ok(
            documentIds.has(sourceId),
            `${subject.subject_code} references unknown source ${sourceId}`
        );
    }
}

const withdrawnCodes = new Set(
    register.withdrawn_subjects.map((subject) => subject.subject_code)
);
assert.ok(withdrawnCodes.has('IC23'));
assert.ok(withdrawnCodes.has('IC82'));
for (const subject of register.withdrawn_subjects) {
    assert.equal(subject.official_status, 'withdrawn');
    assert.equal(subject.commercial_state, 'blocked');
    assert.ok(isIsoDate(subject.effective_from));
    assert.ok(documentIds.has(subject.source_document_id));
}

for (const item of register.quarantine) {
    assertSafeArchivePath(item.archive_path);
    assert.ok(item.reason);
}
for (const duplicateGroup of register.duplicate_groups) {
    assert.ok(duplicateGroup.length >= 2);
    for (const archivePath of duplicateGroup) {
        assertSafeArchivePath(archivePath);
    }
}

const serializedRegister = JSON.stringify(register);
for (const forbidden of [
    'SUPABASE_SERVICE_ROLE_KEY',
    'database password',
    'SMTP password'
]) {
    assert.ok(
        !serializedRegister.includes(forbidden),
        `register contains forbidden secret material: ${forbidden}`
    );
}

console.log(
    `Regulatory source register passed: ${register.documents.length} documents, `
    + `${register.pilot_subjects.length} pilot subjects, `
    + `${register.withdrawn_subjects.length} withdrawn subjects.`
);
