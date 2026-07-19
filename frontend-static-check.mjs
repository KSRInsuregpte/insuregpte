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

const requiredSnippets = {
    'test.html': [
        'RPC_TIMEOUT_MS=20000',
        "callRpcWithTimeout('start_quiz_attempt'",
        "callRpcWithTimeout('get_attempt_questions'",
        "button.innerText='Creating Attempt...'",
        "button.innerText='Loading Questions...'",
        "window.location.replace('dashboard.html')"
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

if (failures.length > 0) {
    console.error('Frontend static checks failed:');

    for (const failure of failures) {
        console.error(`- ${failure}`);
    }

    process.exitCode = 1;
} else {
    console.log(
        `Frontend static checks passed for ${htmlFiles.length} HTML files.`
    );
}
