import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repositoryRoot = path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    '..'
);

function read(relativePath) {
    return fs.readFileSync(path.join(repositoryRoot, relativePath), 'utf8');
}

const catalogueMigration = read(
    'supabase/migrations/20260725120000_launch_subject_catalogue.sql'
);
const quizMigration = read(
    'supabase/migrations/20260725121000_gate_quiz_access_and_enable_demo.sql'
);
const catalogueRollback = read(
    'supabase/rollbacks/20260725120000_launch_subject_catalogue.sql'
);
const quizRollback = read(
    'supabase/rollbacks/20260725121000_gate_quiz_access_and_enable_demo.sql'
);
const compatibilityMigration = read(
    'supabase/migrations/'
    + '20260728100000_restore_catalogue_admin_compatibility.sql'
);
const compatibilityRollback = read(
    'supabase/rollbacks/'
    + '20260728100000_restore_catalogue_admin_compatibility.sql'
);
const compatibilityVerification = read(
    'TESTING/sql/catalogue-admin-compatibility-verification.sql'
);
const indexHtml = read('index.html');
const indexAuth = read('js/index-auth.js');
const validation = read('js/registration-validation.js');
const dashboard = read('js/dashboard.js');
const catalogue = read('js/catalogue.js');
const cart = read('js/cart.js');
const testHtml = read('test.html');

assert.ok(
    !/CREATE\s+TABLE/i.test(catalogueMigration),
    'catalogue migration must reuse existing tables'
);
for (const object of [
    'public.get_subject_catalogue()',
    'public.add_subject_to_cart(p_subject_id bigint)',
    'public.remove_subject_from_cart(p_subject_id bigint)',
    'public.get_my_cart()'
]) {
    assert.ok(
        catalogueMigration.includes(object),
        `catalogue migration is missing ${object}`
    );
}
for (const table of [
    'public.subjects',
    'public.carts',
    'public.cart_items',
    'public.user_entitlements'
]) {
    assert.ok(
        catalogueMigration.includes(table),
        `existing architecture table is not used: ${table}`
    );
}
assert.ok(
    catalogueMigration.includes(
        'migration:20260725120000:legacy-registration-selection'
    ),
    'legacy registrations must be grandfathered into entitlements'
);
assert.ok(
    catalogueMigration.includes(
        'registration_security_version >= 3'
    ),
    'registration version 3 must no longer require registration subjects'
);
assert.ok(
    catalogueMigration.includes(
        'Choose subjects from the catalogue after registration.'
    ),
    'registration version 3 must reject legacy subject updates'
);
assert.ok(
    indexAuth.includes('const REGISTRATION_SECURITY_VERSION = 3;'),
    'frontend must send registration security version 3'
);
assert.ok(
    !indexHtml.includes('id="subject-list"'),
    'registration must not display a subject selector'
);
assert.ok(
    !validation.includes('Select at least one subject.'),
    'registration validation must not require a subject'
);

assert.ok(
    quizMigration.includes(
        "test_mode IN ('practice', 'mock', 'proctored_mock', 'demo')"
    ),
    'demo must be an explicitly constrained quiz mode'
);
assert.ok(
    quizMigration.includes("difficulty_level = 'advanced'"),
    'hard demo questions must map to advanced difficulty'
);
assert.ok(
    quizMigration.includes('public.user_entitlements'),
    'paid quiz modes must be entitlement gated'
);
assert.ok(
    quizMigration.includes('question_record.is_active = true'),
    'quiz allocation must use active questions only'
);
assert.ok(
    quizMigration.includes(
        'CREATE OR REPLACE FUNCTION public.start_quiz_attempt'
    ),
    'existing start_quiz_attempt signature must be replaced, not duplicated'
);
assert.ok(
    quizRollback.includes(
        'CREATE OR REPLACE FUNCTION public.start_quiz_attempt'
    ),
    'quiz rollback must restore the prior RPC'
);
assert.ok(
    catalogueRollback.includes(
        'version-3 registrations exist'
    ),
    'catalogue rollback must protect new learner data'
);
assert.ok(
    !/CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION/i.test(
        compatibilityMigration
    ) && !/CREATE\s+TABLE/i.test(compatibilityMigration),
    'compatibility repair must not duplicate tables or RPCs'
);
for (const signature of [
    'public.get_subject_catalogue()',
    'public.add_subject_to_cart(bigint)',
    'public.remove_subject_from_cart(bigint)',
    'public.get_my_cart()'
]) {
    assert.ok(
        compatibilityMigration.includes(signature),
        `compatibility repair is missing ${signature}`
    );
}
assert.ok(
    compatibilityMigration.includes(
        'REVOKE ALL ON TABLE public.subjects'
    ) && compatibilityMigration.includes(
        'REVOKE ALL ON TABLE public.questions'
    ),
    'compatibility repair must preserve subject/question hardening'
);
assert.ok(
    compatibilityVerification.includes(
        'FROM public.get_subject_catalogue()'
    ) && compatibilityVerification.includes('SET LOCAL ROLE anon'),
    'compatibility verification must execute the public catalogue as anon'
);
assert.ok(
    compatibilityRollback.includes(
        'created no table, function, or learner data'
    ),
    'compatibility rollback must preserve existing RPCs and learner data'
);

for (const source of [dashboard, catalogue, cart]) {
    assert.ok(
        !source.includes(".from('subjects')"),
        'frontend must not read subjects directly'
    );
    assert.ok(
        !source.includes(".from('user_entitlements')"),
        'frontend must not read entitlements directly'
    );
}
assert.ok(
    dashboard.includes("attempt.test_mode === 'practice'"),
    'free demos must not consume paid practice attempt counts'
);
assert.ok(
    catalogue.includes("client.rpc('add_subject_to_cart'"),
    'catalogue purchase action must use the server RPC'
);
assert.ok(
    cart.includes("client.rpc('get_my_cart')"),
    'cart display must use the server RPC'
);
assert.ok(
    testHtml.includes("p.get('mode')==='demo'"),
    'test page must support the demo route'
);
assert.ok(
    testHtml.includes('p_test_mode:currentTestMode'),
    'test page must send the selected safe quiz mode'
);

console.log('Catalogue, cart, entitlement, and demo static checks passed.');
