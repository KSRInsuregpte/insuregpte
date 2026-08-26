import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const repositoryRoot = path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    '..'
);

const htmlFiles = [
    'index.html',
    'dashboard.html',
    'test.html',
    'catalogue.html',
    'subject.html',
    'learning.html',
    'cart.html',
    'admin-dashboard.html'
];

const javascriptFiles = [
    'js/session-control.js',
    'js/screen-protection.js',
    'js/registration-validation.js',
    'js/index-auth.js',
    'js/dashboard.js',
    'js/catalogue.js',
    'js/subject.js',
    'js/learning.js',
    'js/cart.js',
    'js/admin.js'
];

const requiredSnippets = {
    'index.html': [
        'js/session-control.js',
        'js/screen-protection.js',
        'js/registration-validation.js',
        'js/index-auth.js',
        'insuregpte-turnstile-site-key',
        'registration-captcha',
        'email-otp-view',
        'mobile-otp-view',
        'mobile-country-code',
        'country-other',
        'data-password-toggle',
        'data-screen-protection-context-menu="disabled"'
    ],
    'dashboard.html': [
        'js/session-control.js',
        'js/dashboard.js',
        'id="admin-link"',
        'class="hidden'
    ],
    'catalogue.html': [
        'js/session-control.js',
        'js/catalogue.js',
        'Practice Test Login / Sign Up'
    ],
    'subject.html': [
        'js/session-control.js',
        'js/subject.js',
        'Learning content rollout'
    ],
    'learning.html': [
        'js/session-control.js',
        'js/security-notices.js',
        'js/learning.js',
        'id="hierarchy-list"',
        'id="resource-list"',
        'id="flashcard-list"',
        'id="complete-topic-button"'
    ],
    'cart.html': [
        'js/session-control.js',
        'js/cart.js',
        'Secure Checkout — Coming Soon'
    ],
    'admin-dashboard.html': [
        'js/session-control.js',
        'js/admin.js',
        'id="admin-portal"',
        'data-admin-tab="subjects"',
        'data-admin-tab="questions"',
        'data-admin-tab="users"',
        'data-admin-tab="exam-information"',
        'data-admin-tab="audit"'
    ],
    'test.html': [
        'js/session-control.js',
        'js/screen-protection.js',
        'sessionControl.clientOptions()',
        'sessionControl.activateProtectedPage',
        'sessionControl.logoutEverywhere',
        'insuregpte:session-inactive',
        'RPC_TIMEOUT_MS=20000',
        "callRpcWithTimeout('start_quiz_attempt'",
        "callRpcWithTimeout('get_attempt_questions'",
        "p_test_mode:currentTestMode",
        "p.get('mode')==='demo'",
        "button.innerText='Creating Attempt...'",
        "button.innerText='Loading Questions...'",
        'return-dashboard-button',
        "document.getElementById('final-result')",
        'sessionControl.releasePageControl()',
        "window.location.replace('dashboard.html')"
    ]
};

const dashboardJavascriptRequirements = [
        'sessionControl.clientOptions()',
        'sessionControl.activateProtectedPage',
        'sessionControl.logoutEverywhere',
        "client.rpc('get_subject_catalogue')",
        "client.rpc('get_my_quiz_attempts')",
        "client.rpc('fn_is_admin')",
        "attempt.test_mode === 'practice'"
];

const requiredJavascriptSnippets = {
    'js/dashboard.js': dashboardJavascriptRequirements,
    'js/catalogue.js': [
        'sessionControl.clientOptions()',
        'sessionControl.activateProtectedPage',
        "'get_subject_catalogue'",
        "client.rpc('add_subject_to_cart'",
        'advanced_question_count'
    ],
    'js/subject.js': [
        'sessionControl.clientOptions()',
        "'get_subject_catalogue'",
        "client.rpc('add_subject_to_cart'",
        '&mode=demo',
        'learning.html?subject_id='
    ],
    'js/learning.js': [
        'sessionControl.clientOptions()',
        'sessionControl.acquirePageControl',
        'sessionControl.activateProtectedPage',
        'sessionControl.logoutEverywhere',
        "callRpc('get_subject_hierarchy'",
        "callRpc('get_topic_details'",
        "callRpc('get_learning_resources'",
        "callRpc('get_flashcards'",
        "callRpc('record_learning_activity'",
        "callRpc('get_resume_learning'",
        "callRpc('get_learning_statistics'"
    ],
    'js/cart.js': [
        'sessionControl.clientOptions()',
        'sessionControl.activateProtectedPage',
        "client.rpc('get_my_cart')",
        "'remove_subject_from_cart'"
    ],
    'js/admin.js': [
        'sessionControl.clientOptions()',
        'sessionControl.activateProtectedPage',
        "client.rpc('fn_is_admin')",
        "client.rpc('admin_save_subject'",
        "client.rpc('admin_save_question'",
        "client.rpc('admin_list_users')",
        "client.rpc('admin_set_user_status'",
        "'admin_save_exam_information'",
        "'admin_retire_exam_information'",
        "'admin_list_audit_events'",
        'sessionControl.logoutEverywhere'
    ],
    'js/session-control.js': [
        'x-insuregpte-client-id',
        "client.rpc('claim_active_client'",
        "'heartbeat_active_client'",
        "'release_active_client'",
        "client.auth.signOut({ scope: 'others' })",
        'another browser or page',
        'insuregpte:session-inactive'
    ],
    'js/screen-protection.js': [
        'copy',
        'cut',
        'paste',
        'dragstart',
        'contextmenu',
        'printscreen',
        '@media print',
        'data-screen-protection-label',
        'screenProtectionContextMenu',
        'Screenshots are prohibited'
    ],
    'js/registration-validation.js': [
        'InsureGPTERegistrationValidation',
        'password.length >= 12',
        'MOBILE_PATTERN',
        'composeMobileNumber',
        'INDIA_PIN_PATTERN'
    ],
    'js/index-auth.js': [
        'sessionControl.clientOptions()',
        'sessionControl.acquirePageControl',
        'sessionControl.activateAfterSignIn',
        'captchaToken',
        'registration_security_version',
        'const MOBILE_VERIFICATION_REQUIRED = false;',
        'Email verified. Opening your dashboard',
        "type: 'email'",
        "type: 'phone_change'",
        'client.auth.updateUser',
        'registration_source',
        'updateMobileCallingCode',
        'updateCountrySelection',
        'togglePasswordVisibility'
    ]
};

const failures = [];

for (const relativeFile of htmlFiles) {
    const absoluteFile = path.join(repositoryRoot, relativeFile);

    if (!fs.existsSync(absoluteFile)) {
        failures.push(`${relativeFile}: file is missing`);
        continue;
    }

    const html = fs.readFileSync(absoluteFile, 'utf8');

    for (const snippet of requiredSnippets[relativeFile] || []) {
        if (!html.includes(snippet)) {
            failures.push(
                `${relativeFile}: required quiz-start safeguard is missing: ${snippet}`
            );
        }
    }

    const inlineScriptPattern = /<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi;
    let scriptMatch;
    let inlineScriptNumber = 0;

    while ((scriptMatch = inlineScriptPattern.exec(html)) !== null) {
        inlineScriptNumber += 1;

        try {
            new vm.Script(scriptMatch[1], {
                filename: `${relativeFile}:inline-script-${inlineScriptNumber}`
            });
        } catch (error) {
            failures.push(`${relativeFile}: ${error.message}`);
        }
    }

    const localReferencePattern = /(?:href|src)=["']([^"']+)["']/gi;
    let referenceMatch;

    while ((referenceMatch = localReferencePattern.exec(html)) !== null) {
        const reference = referenceMatch[1].trim();

        if (
            !reference ||
            reference.startsWith('#') ||
            reference.startsWith('//') ||
            /^[a-z][a-z\d+.-]*:/i.test(reference)
        ) {
            continue;
        }

        const localPath = reference.split(/[?#]/, 1)[0];
        const resolvedPath = path.resolve(
            path.dirname(absoluteFile),
            decodeURIComponent(localPath)
        );

        if (!fs.existsSync(resolvedPath)) {
            failures.push(
                `${relativeFile}: local reference does not exist: ${reference}`
            );
        }
    }
}

for (const relativeFile of javascriptFiles) {
    const absoluteFile = path.join(repositoryRoot, relativeFile);

    if (!fs.existsSync(absoluteFile)) {
        failures.push(`${relativeFile}: file is missing`);
        continue;
    }

    const source = fs.readFileSync(absoluteFile, 'utf8');

    for (const snippet of requiredJavascriptSnippets[relativeFile] || []) {
        if (!source.includes(snippet)) {
            failures.push(
                `${relativeFile}: required session safeguard is missing: ${snippet}`
            );
        }
    }

    try {
        new vm.Script(source, { filename: relativeFile });
    } catch (error) {
        failures.push(`${relativeFile}: ${error.message}`);
    }
}

const dashboardHtml = fs.readFileSync(
    path.join(repositoryRoot, 'dashboard.html'),
    'utf8'
);
const testHtml = fs.readFileSync(
    path.join(repositoryRoot, 'test.html'),
    'utf8'
);

if (dashboardHtml.includes('js/screen-protection.js')) {
    failures.push(
        'dashboard.html: protected-screen controls must remain limited to ' +
        'authentication and test pages'
    );
}

if (testHtml.includes('data-screen-protection-context-menu')) {
    failures.push(
        'test.html: right-click blocking must remain limited to the ' +
        'authentication and registration page'
    );
}

if (failures.length > 0) {
    console.error('Frontend static checks failed:');

    for (const failure of failures) {
        console.error(`- ${failure}`);
    }

    process.exitCode = 1;
} else {
    console.log(
        `Frontend static checks passed for ${htmlFiles.length} HTML files ` +
        `and ${javascriptFiles.length} shared JavaScript files.`
    );
}
