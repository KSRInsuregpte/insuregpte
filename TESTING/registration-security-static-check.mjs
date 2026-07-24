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
    'supabase/migrations/20260721130000_protect_user_registration.sql'
);
const rollback = read(
    'supabase/rollbacks/20260721130000_protect_user_registration.sql'
);
const verification = read(
    'TESTING/sql/protected-registration-verification.sql'
);
const indexHtml = read('index.html');

for (const snippet of [
    'hook_validate_user_registration(event jsonb)',
    'registration_security_version',
    'registration_source',
    'email_verified_at',
    'mobile_verified_at',
    'trigger_activate_verified_user',
    'AFTER UPDATE OF email_confirmed_at, phone, phone_confirmed_at',
    'Complete email and mobile verification before continuing.',
    'TO supabase_auth_admin',
    'TO authenticated'
]) {
    assert.ok(migration.includes(snippet), `migration is missing: ${snippet}`);
}

assert.ok(
    /public\.save_user_profile\(\r?\n    user_id uuid,\r?\n    fname text/.test(
        migration
    ),
    'save_user_profile deployed signature must be preserved'
);
assert.ok(
    !/CREATE\s+TABLE/i.test(migration),
    'registration hardening must not create a duplicate application table'
);
assert.equal(
    (migration.match(/\$function\$/g) || []).length % 2,
    0,
    'migration function dollar quotes should be balanced'
);
assert.ok(
    rollback.includes(
        'DROP FUNCTION IF EXISTS public.hook_validate_user_registration(jsonb)'
    ),
    'rollback should remove the Auth hook function'
);
assert.ok(
    rollback.includes(
        'Rejects authenticated Data API requests unless the JWT session'
    ),
    'rollback should restore the prior strict active-client guard'
);
assert.ok(
    verification.includes('A valid registration was rejected'),
    'verification should exercise a valid hook event'
);
assert.ok(
    verification.includes('Anonymous signup was not rejected correctly'),
    'verification should exercise anonymous rejection'
);
assert.ok(
    !indexHtml.includes('REPLACE_WITH_CLOUDFLARE_TURNSTILE_SITE_KEY'),
    'production registration should not retain the Turnstile site-key placeholder'
);
assert.match(
    indexHtml,
    /name="insuregpte-turnstile-site-key"\s+content="0x[0-9A-Za-z_-]{20,}"/,
    'production registration should provide a Cloudflare Turnstile public site key'
);
assert.match(
    indexHtml,
    /id="btn-register"[\s\S]*?disabled[\s\S]*?aria-disabled="true"/,
    'registration submit should start disabled until Turnstile is ready'
);
for (const snippet of [
    'id="mobile-country-code"',
    'id="mobile-country-code-other"',
    'id="country-other"',
    'id="postal-code-guidance"',
    'data-password-toggle'
]) {
    assert.ok(
        indexHtml.includes(snippet),
        `registration accessibility control is missing: ${snippet}`
    );
}
const indexAuth = read('js/index-auth.js');
assert.ok(
    indexAuth.includes('setRegistrationEnabled(false)'),
    'registration should remain disabled while Turnstile is unavailable'
);
assert.ok(
    indexAuth.includes('setRegistrationEnabled(true)'),
    'registration should be enabled only after Turnstile renders'
);
for (const snippet of [
    'validation.composeMobileNumber(',
    'updateMobileCallingCode',
    'updateCountrySelection',
    'togglePasswordVisibility'
]) {
    assert.ok(
        indexAuth.includes(snippet),
        `registration interaction is missing: ${snippet}`
    );
}
assert.ok(
    !/\bonclick\s*=/i.test(indexHtml),
    'the refactored authentication page should not use inline click handlers'
);

console.log('Registration security static checks passed.');
