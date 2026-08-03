(function initialiseDashboard(global) {
    'use strict';

    const SUPABASE_URL = 'https://tvjsivuibvzybdbjtesq.supabase.co';
    const SUPABASE_ANON_KEY =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        + 'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2anNpdnVpYnZ6eWJkYmp0ZXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0MTI1MjksImV4cCI6MjA5ODk4ODUyOX0.'
        + 'meGmoVDJE25neU_na5xl8u3CYxA24M7tqcG5ez-emaU';
    const MAX_ATTEMPTS = 5;
    const sessionControl = global.InsureGPTESessionControl;
    const securityNotices = global.InsureGPTESecurityNotices;
    const client = global.supabase.createClient(
        SUPABASE_URL,
        SUPABASE_ANON_KEY,
        sessionControl.clientOptions()
    );

    function escapeHtml(value) {
        const element = document.createElement('div');
        element.textContent = String(value ?? '');
        return element.innerHTML;
    }

    function showMessage(message, type = 'error') {
        const box = document.getElementById('message-box');
        box.textContent = message;
        box.className = type === 'error'
            ? 'mb-5 rounded-xl bg-red-100 p-4 text-red-800'
            : 'mb-5 rounded-xl bg-blue-100 p-4 text-blue-800';
    }

    function countPracticeAttempts(attempts) {
        const counts = {};

        (attempts || [])
            .filter((attempt) => attempt.test_mode === 'practice')
            .forEach((attempt) => {
                const subjectId = String(attempt.subject_id);
                counts[subjectId] = (counts[subjectId] || 0) + 1;
            });

        return counts;
    }

    function renderSubjects(subjects, attempts) {
        const tableBody = document.getElementById('test-list');
        const counts = countPracticeAttempts(attempts);

        if (!subjects.length) {
            tableBody.innerHTML = `
                <tr>
                    <td colspan="4" class="px-5 py-10 text-center">
                        <p class="font-semibold text-slate-700">You do not have an active subject yet.</p>
                        <p class="mt-2 text-sm text-slate-500">Browse the catalogue, try a demo, and add a subject to your cart.</p>
                        <a href="catalogue.html" class="mt-4 inline-block rounded-lg bg-blue-700 px-5 py-3 font-bold text-white hover:bg-blue-800">
                            Browse Catalogue
                        </a>
                    </td>
                </tr>
            `;
            return;
        }

        tableBody.innerHTML = subjects.map((subject) => {
            const used = counts[String(subject.subject_id)] || 0;
            const remaining = Math.max(MAX_ATTEMPTS - used, 0);
            const limitReached = used >= MAX_ATTEMPTS;
            const query = `subject_id=${encodeURIComponent(subject.subject_id)}`
                + `&subject_code=${encodeURIComponent(subject.subject_code)}`;

            return `
                <tr class="hover:bg-slate-50">
                    <td class="border-b px-5 py-5">
                        <p class="font-bold text-blue-900">
                            ${escapeHtml(subject.subject_code)} — ${escapeHtml(subject.subject_title)}
                        </p>
                        <p class="mt-1 text-xs text-slate-500">
                            ${escapeHtml(subject.category_name || '')}
                        </p>
                        ${limitReached
                            ? '<p class="mt-1 text-xs text-red-600">Practice attempt limit reached</p>'
                            : `<p class="mt-1 text-xs text-slate-500">${remaining} practice attempt${remaining === 1 ? '' : 's'} remaining</p>`}
                    </td>
                    <td class="border-b px-5 py-5 text-center font-bold">${used}</td>
                    <td class="border-b px-5 py-5 text-center font-bold">${MAX_ATTEMPTS}</td>
                    <td class="border-b px-5 py-5">
                        <div class="flex flex-wrap justify-center gap-2">
                            <a href="subject.html?subject_id=${encodeURIComponent(subject.subject_id)}" class="rounded-lg bg-emerald-600 px-3 py-2 text-sm font-bold text-white hover:bg-emerald-700">
                                Learning
                            </a>
                            ${limitReached
                                ? '<span class="cursor-not-allowed rounded-lg bg-slate-200 px-3 py-2 text-sm font-bold text-slate-500">Practice Closed</span>'
                                : `<a href="test.html?${query}" class="rounded-lg bg-blue-700 px-3 py-2 text-sm font-bold text-white hover:bg-blue-800">Start Practice</a>`}
                        </div>
                    </td>
                </tr>
            `;
        }).join('');
    }

    async function logout() {
        const button = document.getElementById('logout-button');
        button.disabled = true;

        const result = await sessionControl.logoutEverywhere(client);
        if (!result.success) {
            button.disabled = false;
            showMessage('Unable to log out. Please try again.');
            return;
        }
        global.location.replace('index.html');
    }

    async function initialise() {
        const pageControl = sessionControl.acquirePageControl();
        if (!pageControl.acquired) {
            return;
        }

        try {
            const { data: { user }, error: userError } =
                await client.auth.getUser();

            if (userError || !user) {
                sessionControl.releasePageControl();
                global.location.replace('index.html');
                return;
            }

            if (!await sessionControl.activateProtectedPage(
                client,
                pageControl.tookOver
            )) {
                return;
            }

            securityNotices.start({
                client,
                sessionControl,
                panel: document.getElementById('security-notices'),
                list: document.getElementById('security-notices-list'),
                onError: showMessage
            });

            const firstName = String(
                user.user_metadata?.first_name || 'Member'
            ).trim();
            document.getElementById('welcome').textContent =
                `Welcome, ${firstName}`;

            const [
                { data: catalogue, error: catalogueError },
                { data: attempts, error: attemptsError },
                { data: isAdmin, error: adminError }
            ] = await Promise.all([
                client.rpc('get_subject_catalogue'),
                client.rpc('get_my_quiz_attempts'),
                client.rpc('fn_is_admin')
            ]);

            if (catalogueError) {
                throw catalogueError;
            }
            if (attemptsError) {
                throw attemptsError;
            }
            if (!adminError && isAdmin === true) {
                document.getElementById('admin-link').classList.remove(
                    'hidden'
                );
            }

            renderSubjects(
                (catalogue || []).filter((subject) => subject.is_entitled),
                attempts || []
            );
        } catch (error) {
            console.error('Dashboard loading error:', error);
            if (await sessionControl.handleInactiveSessionError(error)) {
                return;
            }
            showMessage(
                'Your practice access could not be loaded. Please try again.'
            );
            document.getElementById('test-list').innerHTML = `
                <tr>
                    <td colspan="4" class="px-5 py-10 text-center text-red-700">
                        Practice access is temporarily unavailable.
                    </td>
                </tr>
            `;
        }
    }

    document.getElementById('logout-button').addEventListener(
        'click',
        () => void logout()
    );
    void initialise();
}(window));
