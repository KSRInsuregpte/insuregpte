import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const repositoryRoot = resolve(
    dirname(fileURLToPath(import.meta.url)),
    '..'
);

const files = {
    migration: resolve(
        repositoryRoot,
        'supabase/migrations/20260802150000_add_safety_monitoring_and_enforcement.sql'
    ),
    rollback: resolve(
        repositoryRoot,
        'supabase/rollbacks/20260802150000_add_safety_monitoring_and_enforcement.sql'
    ),
    verification: resolve(
        repositoryRoot,
        'TESTING/sql/safety-system-verification.sql'
    ),
    adminHtml: resolve(repositoryRoot, 'admin-dashboard.html'),
    adminJavascript: resolve(repositoryRoot, 'js/admin.js'),
    dashboardHtml: resolve(repositoryRoot, 'dashboard.html'),
    dashboardJavascript: resolve(repositoryRoot, 'js/dashboard.js'),
    catalogueHtml: resolve(repositoryRoot, 'catalogue.html'),
    subjectHtml: resolve(repositoryRoot, 'subject.html'),
    cartHtml: resolve(repositoryRoot, 'cart.html'),
    testHtml: resolve(repositoryRoot, 'test.html'),
    catalogueJavascript: resolve(repositoryRoot, 'js/catalogue.js'),
    subjectJavascript: resolve(repositoryRoot, 'js/subject.js'),
    cartJavascript: resolve(repositoryRoot, 'js/cart.js'),
    securityNotices: resolve(repositoryRoot, 'js/security-notices.js'),
    sessionControl: resolve(repositoryRoot, 'js/session-control.js'),
    indexAuthentication: resolve(repositoryRoot, 'js/index-auth.js')
};

const source = Object.fromEntries(
    await Promise.all(
        Object.entries(files).map(async ([name, path]) => [
            name,
            await readFile(path, 'utf8')
        ])
    )
);

for (const relation of [
    'security_events',
    'account_enforcement_cases',
    'notification_outbox'
]) {
    assert.match(
        source.migration,
        new RegExp(`CREATE TABLE public\\.${relation}\\b`, 'i'),
        `Migration must create ${relation}.`
    );
    assert.match(
        source.migration,
        new RegExp(
            `ALTER TABLE public\\.${relation} ENABLE ROW LEVEL SECURITY`,
            'i'
        ),
        `${relation} must have RLS enabled.`
    );
    assert.match(
        source.rollback,
        new RegExp(`DROP TABLE public\\.${relation}`, 'i'),
        `Rollback must remove ${relation}.`
    );
}

for (const rpc of [
    'fn_scan_long_running_sessions',
    'record_security_event',
    'get_admin_security_summary',
    'admin_list_security_events',
    'admin_review_security_event',
    'admin_list_enforcement_cases',
    'admin_issue_security_warning',
    'admin_suspend_user_access',
    'admin_restore_user_access',
    'admin_list_notification_outbox',
    'get_my_security_notices',
    'acknowledge_my_security_notice',
    'claim_notification_outbox',
    'complete_notification_outbox'
]) {
    assert.match(
        source.migration,
        new RegExp(`CREATE FUNCTION public\\.${rpc}\\b`, 'i'),
        `Migration must create ${rpc}.`
    );
    assert.ok(
        source.rollback.includes(`public.${rpc}`),
        `Rollback must reference ${rpc}.`
    );
}

assert.match(
    source.migration,
    /warning_count\s+BETWEEN\s+0\s+AND\s+3/i,
    'Warning counts must be limited to three.'
);
assert.match(
    source.migration,
    /GRANT EXECUTE ON FUNCTION public\.record_security_event\([\s\S]*?\) TO service_role/i,
    'Only a trusted service-side monitor should ingest provider safety events.'
);
assert.match(
    source.migration,
    /v_case\.warning_count\s*<\s*3[\s\S]*v_source_severity[\s\S]*critical_attack/i,
    'Ordinary suspension must require three warnings while critical events may override.'
);
assert.match(
    source.migration,
    /v_user_role\s*=\s*'admin'[\s\S]*Administrator accounts cannot be suspended/i,
    'Learner enforcement must not suspend administrators.'
);
assert.match(
    source.migration,
    /claimed_at\s*<=\s*clock_timestamp\(\)\s*-\s*interval '48 hours'/i,
    'Long-session scanning must use the approved 48-hour threshold.'
);
assert.match(
    source.migration,
    /GRANT EXECUTE ON FUNCTION public\.claim_notification_outbox\(integer\)[\s\S]*TO service_role/i,
    'Only the service-side delivery worker should claim email rows.'
);
assert.doesNotMatch(
    source.migration,
    /password|confirmation_token|recovery_token|refresh_token|correct_option|option_[abcd]|ip_address/i,
    'Safety records and functions must not reference protected credentials, raw IP addresses, or quiz answers.'
);

assert.ok(
    source.adminHtml.includes('data-admin-tab="security"')
        && source.adminHtml.includes('id="panel-security"')
        && source.adminHtml.includes('id="security-events-table"')
        && source.adminHtml.includes('id="enforcement-cases-table"'),
    'The administrator portal must expose the Security & Alerts workflow.'
);

for (const rpcCall of [
    "'get_admin_security_summary'",
    "'admin_list_security_events'",
    "'admin_list_enforcement_cases'",
    "'admin_review_security_event'",
    "'admin_issue_security_warning'",
    "'admin_suspend_user_access'",
    "'admin_restore_user_access'"
]) {
    assert.ok(
        source.adminJavascript.includes(rpcCall),
        `Administrator frontend must call ${rpcCall}.`
    );
}

assert.ok(
    source.dashboardHtml.includes('id="security-notices"')
        && source.securityNotices.includes("'get_my_security_notices'")
        && source.securityNotices.includes(
            "'acknowledge_my_security_notice'"
        )
        && source.securityNotices.includes('REFRESH_INTERVAL_MS = 15000'),
    'Learners must receive, refresh, and acknowledge account warnings.'
);

for (const page of [
    'dashboardHtml',
    'catalogueHtml',
    'subjectHtml',
    'cartHtml',
    'testHtml'
]) {
    assert.ok(
        source[page].includes('js/security-notices.js'),
        `${page} must load the shared learner account-notice service.`
    );
}

for (const script of [
    'dashboardJavascript',
    'catalogueJavascript',
    'subjectJavascript',
    'cartJavascript'
]) {
    assert.ok(
        source[script].includes('securityNotices.start('),
        `${script} must start account-notice monitoring after authentication.`
    );
}
assert.ok(
    source.testHtml.includes('InsureGPTESecurityNotices.start('),
    'The protected quiz page must start account-notice monitoring.'
);

assert.ok(
    source.sessionControl.includes('isRestrictedAccountError')
        && source.sessionControl.includes("signOut({ scope: 'local' })")
        && source.sessionControl.includes('RESTRICTED_NOTICE_MS = 8000')
        && source.sessionControl.includes('returned to sign-in in 8 seconds')
        && source.sessionControl.includes("session=restricted")
        && source.indexAuthentication.includes("'restricted'].includes(sessionReason)")
        && source.indexAuthentication.includes('account access is suspended or inactive'),
    'A suspended or inactive account must receive a readable blocked notice, be signed out locally, and return to login with a clear explanation.'
);

assert.ok(
    source.adminHtml.includes('id="admin-action-dialog"')
        && source.adminJavascript.includes('requestAdminAction({'),
    'Safety decisions must use the accessible on-page administrator action dialog.'
);

const safetyActionStart = source.adminJavascript.indexOf(
    'async function reviewSecurityEvent'
);
const safetyActionEnd = source.adminJavascript.indexOf(
    'function syncBulkTemplateLink'
);
const safetyActions = source.adminJavascript.slice(
    safetyActionStart,
    safetyActionEnd
);
assert.doesNotMatch(
    safetyActions,
    /global\.(?:prompt|confirm)\(/,
    'Security review, warning, suspension, and restoration must not use blocking browser prompts.'
);

assert.match(
    source.verification,
    /Expected result: Success\. No rows returned\./,
    'Verification SQL must state its successful result.'
);
const verificationWithoutComments = source.verification.replace(
    /--.*$/gm,
    ''
).replace(/'(?:''|[^'])*'/g, "''");
assert.doesNotMatch(
    verificationWithoutComments,
    /\b(?:INSERT|UPDATE|DELETE|CREATE|ALTER|DROP|TRUNCATE)\b/i,
    'Verification SQL should remain structurally read-only outside its DO block checks.'
);

console.log('Safety-system static checks passed.');
