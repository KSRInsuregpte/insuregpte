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
    'test.html'
];

const javascriptFiles = [
    'js/session-control.js',
    'js/registration-validation.js',
    'js/index-auth.js'
];

const requiredSnippets = {
    'index.html': [
        'js/session-control.js',
        'js/registration-validation.js',
        'js/index-auth.js',
        'insuregpte-turnstile-site-key',
        'registration-captcha',
        'email-otp-view',
        'mobile-otp-view'
    ],
    'dashboard.html': [
        'js/session-control.js',
        'sessionControl.clientOptions()',
        'sessionControl.activateProtectedPage',
        'sessionControl.logoutEverywhere'
    ],
    'test.html': [
        'js/session-control.js',
        'sessionControl.clientOptions()',
        'sessionControl.activateProtectedPage',
        'sessionControl.logoutEverywhere',
        'insuregpte:session-inactive',
        'RPC_TIMEOUT_MS=20000',
        "callRpcWithTimeout('start_quiz_attempt'",
        "callRpcWithTimeout('get_attempt_questions'",
        "button.innerText='Creating Attempt...'",
        "button.innerText='Loading Questions...'",
        "window.location.replace('dashboard.html')"
    ]
};

const requiredJavascriptSnippets = {
    'js/session-control.js': [
        'x-insuregpte-client-id',
        "client.rpc('claim_active_client'",
        "'heartbeat_active_client'",
        "'release_active_client'",
        "client.auth.signOut({ scope: 'others' })",
        'another browser or page',
        'insuregpte:session-inactive'
    ],
    'js/registration-validation.js': [
        'InsureGPTERegistrationValidation',
        'password.length >= 12',
        'MOBILE_PATTERN',
        'Select at least one subject.'
    ],
    'js/index-auth.js': [
        'sessionControl.clientOptions()',
        'sessionControl.acquirePageControl',
        'sessionControl.activateAfterSignIn',
        'captchaToken',
        'registration_security_version',
        "type: 'email'",
        "type: 'phone_change'",
        'client.auth.updateUser',
        'registration_source'
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

if (failures.length > 0) {
    console.error('Frontend static checks failed:');

    for (const failure of failures) {
        console.error(`- ${failure}`);
    }

    process.exitCode = 1;
} else {
    console.log(
        `Frontend static checks passed for ${htmlFiles.length} HTML files ` +
        `and ${javascriptFiles.length} shared JavaScript file.`
    );
}
