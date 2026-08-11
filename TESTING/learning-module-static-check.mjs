import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');
const migration = readFileSync(
    resolve(root, 'supabase', 'migrations', '20260811150000_build_learning_module.sql'),
    'utf8'
);
const rollback = readFileSync(
    resolve(root, 'supabase', 'rollbacks', '20260811150000_build_learning_module.sql'),
    'utf8'
);
const verification = readFileSync(
    resolve(here, 'sql', 'learning-module-verification.sql'),
    'utf8'
);
const learningHtml = readFileSync(resolve(root, 'learning.html'), 'utf8');
const learningJavascript = readFileSync(
    resolve(root, 'js', 'learning.js'),
    'utf8'
);
const dashboardJavascript = readFileSync(
    resolve(root, 'js', 'dashboard.js'),
    'utf8'
);
const subjectJavascript = readFileSync(
    resolve(root, 'js', 'subject.js'),
    'utf8'
);

const functions = [
    'get_subject_hierarchy',
    'get_modules_by_subject',
    'get_chapters_by_module',
    'get_topics_by_chapter',
    'get_topic_details',
    'get_learning_resources',
    'get_flashcards',
    'record_learning_activity',
    'get_resume_learning',
    'get_recent_activity',
    'get_topic_completion',
    'get_learning_statistics'
];

for (const name of functions) {
    assert.match(
        migration,
        new RegExp(`CREATE FUNCTION public\\.${name}\\b`, 'i'),
        `Expected migration definition for ${name}.`
    );
    assert.ok(
        migration.includes(`GRANT EXECUTE ON FUNCTION public.${name}`),
        `Expected authenticated grant for ${name}.`
    );
    assert.ok(
        rollback.includes(`DROP FUNCTION IF EXISTS public.${name}`),
        `Expected rollback for ${name}.`
    );
    assert.ok(
        verification.includes(`'${name}'`),
        `Expected verification for ${name}.`
    );
}

for (const required of [
    'auth.uid()',
    "profile_record.status = 'active'",
    "entitlement_record.status = 'active'",
    'entitlement_record.valid_from <=',
    'resource_record.is_premium',
    "RAISE SQLSTATE 'PT403'",
    'p_user_id IS DISTINCT FROM v_user_id',
    "'resource_viewed'",
    "'flashcard_reviewed'",
    'ON CONFLICT (user_id, topic_id)',
    'SECURITY DEFINER',
    "SET search_path = ''"
]) {
    assert.ok(migration.includes(required), `Missing Learning safeguard: ${required}`);
}

assert.doesNotMatch(
    migration,
    /\b(DROP\s+TABLE|TRUNCATE|DELETE\s+FROM)\b/i,
    'The Learning migration must not remove learner or content data.'
);
assert.match(
    migration,
    /REVOKE ALL ON TABLE public\.learning_resources FROM anon, authenticated/i,
    'Learning resources must be RPC-only for browser roles.'
);
assert.match(
    migration,
    /REVOKE ALL ON FUNCTION public\.upsert_user_topic_progress[\s\S]*FROM PUBLIC, anon, authenticated, service_role/i,
    'The unsafe legacy progress grant must be replaced.'
);
assert.match(
    rollback,
    /GRANT EXECUTE ON FUNCTION public\.upsert_user_topic_progress[\s\S]*TO anon, authenticated/i,
    'Rollback must restore the audited legacy execution grants.'
);

for (const expected of [
    'js/session-control.js',
    'js/security-notices.js',
    'js/learning.js',
    'hierarchy-list',
    'resource-list',
    'flashcard-list',
    'complete-topic-button'
]) {
    assert.ok(learningHtml.includes(expected), `Learning page is missing ${expected}.`);
}

for (const rpc of [
    'get_subject_catalogue',
    'get_subject_hierarchy',
    'get_topic_details',
    'get_learning_resources',
    'get_flashcards',
    'record_learning_activity',
    'get_resume_learning',
    'get_learning_statistics'
]) {
    assert.ok(
        learningJavascript.includes(`'${rpc}'`),
        `Learning frontend is missing ${rpc}.`
    );
}

for (const required of [
    'sessionControl.clientOptions()',
    'sessionControl.acquirePageControl()',
    'sessionControl.activateProtectedPage',
    'sessionControl.handleInactiveSessionError',
    'sessionControl.logoutEverywhere',
    'safeExternalUrl',
    "url.protocol === 'https:'",
    "'topic_completed'",
    "'flashcard_reviewed'"
]) {
    assert.ok(
        learningJavascript.includes(required),
        `Learning frontend safeguard is missing ${required}.`
    );
}

for (const source of [learningJavascript, dashboardJavascript, subjectJavascript]) {
    for (const table of [
        'subject_modules',
        'subject_chapters',
        'subject_topics',
        'learning_resources',
        'flashcards',
        'user_topic_progress',
        'user_learning_activity',
        'user_entitlements'
    ]) {
        assert.ok(
            !source.includes(`.from('${table}')`),
            `Frontend must not directly access ${table}.`
        );
    }
}

assert.ok(
    dashboardJavascript.includes("subject.has_learning_content ? 'learning.html'"),
    'Dashboard Learning action must open the Learning Module when content exists.'
);
assert.ok(
    subjectJavascript.includes('Open Learning'),
    'Subject overview must expose the protected Learning action.'
);

console.log('Learning Module database and frontend static checks passed.');
