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

const migration = read(
    'supabase/migrations/20260723214500_defer_mobile_verification.sql'
);
const rollback = read(
    'supabase/rollbacks/20260723214500_defer_mobile_verification.sql'
);
const verification = read(
    'TESTING/sql/email-only-activation-verification.sql'
);
const indexAuth = read('js/index-auth.js');
const indexHtml = read('index.html');

for (const snippet of [
    'CREATE OR REPLACE FUNCTION public.activate_verified_user()',
    'WHEN NEW.email_confirmed_at IS NOT NULL THEN',
    'Complete email verification before continuing.',
    "status = 'active'",
    'auth_user.email_confirmed_at IS NOT NULL'
]) {
    assert.ok(migration.includes(snippet), `migration is missing: ${snippet}`);
}

assert.ok(
    !/CREATE\s+TABLE/i.test(migration),
    'email-only activation must not create a duplicate table'
);
for (const [name, source] of [
    ['migration', migration],
    ['rollback', rollback]
]) {
    for (const delimiter of ['$function$', '$block$']) {
        assert.equal(
            (source.split(delimiter).length - 1) % 2,
            0,
            `${name} ${delimiter} quotes should be balanced`
        );
    }
}
assert.ok(
    rollback.includes(
        'Complete email and mobile verification before continuing.'
    ),
    'rollback must restore the dual-verification gate'
);
assert.ok(
    verification.includes(
        'An email-confirmed profile remains verification_pending'
    ),
    'verification must check the email-confirmed backfill'
);
assert.ok(
    indexAuth.includes('const MOBILE_VERIFICATION_REQUIRED = false;'),
    'frontend must explicitly defer mobile verification'
);
assert.ok(
    indexAuth.includes('if (MOBILE_VERIFICATION_REQUIRED)'),
    'frontend must retain a controlled future mobile-verification path'
);
assert.ok(
    indexAuth.includes(
        'Email verified. Opening your dashboard'
    ),
    'email verification must communicate direct activation'
);
assert.ok(
    indexHtml.includes(
        'Email verification is required before access is activated.'
    ),
    'registration guidance must describe the current activation policy'
);

console.log('Email-only activation static checks passed.');
