(function initialiseSubjectPage(global) {
    'use strict';

    const SUPABASE_URL = 'https://tvjsivuibvzybdbjtesq.supabase.co';
    const SUPABASE_ANON_KEY =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        + 'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2anNpdnVpYnZ6eWJkYmp0ZXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0MTI1MjksImV4cCI6MjA5ODk4ODUyOX0.'
        + 'meGmoVDJE25neU_na5xl8u3CYxA24M7tqcG5ez-emaU';
    const sessionControl = global.InsureGPTESessionControl;
    const client = global.supabase.createClient(
        SUPABASE_URL,
        SUPABASE_ANON_KEY,
        sessionControl.clientOptions()
    );
    let signedIn = false;

    function escapeHtml(value) {
        const element = document.createElement('div');
        element.textContent = String(value ?? '');
        return element.innerHTML;
    }

    function showMessage(message) {
        const box = document.getElementById('message-box');
        box.textContent = message;
        box.className = 'mb-6 rounded-xl bg-red-100 p-4 text-red-900';
    }

    function authDestination(next) {
        return `index.html?next=${encodeURIComponent(next)}`;
    }

    function subjectId() {
        const value = Number(
            new URLSearchParams(global.location.search).get('subject_id')
        );
        return Number.isInteger(value) && value > 0 ? value : null;
    }

    function render(subject) {
        const currentUrl = `subject.html?subject_id=${encodeURIComponent(subject.subject_id)}`;
        const demoUrl = `test.html?subject_id=${encodeURIComponent(subject.subject_id)}`
            + `&subject_code=${encodeURIComponent(subject.subject_code)}&mode=demo`;
        const practiceUrl = `test.html?subject_id=${encodeURIComponent(subject.subject_id)}`
            + `&subject_code=${encodeURIComponent(subject.subject_code)}`;
        const requiredDemoQuestions = Math.min(
            10,
            Number(subject.demo_question_limit || 0)
        );
        const demoReady = subject.is_demo_available
            && requiredDemoQuestions > 0
            && Number(subject.advanced_question_count || 0)
                >= requiredDemoQuestions;
        let primaryAction;

        if (subject.is_entitled) {
            primaryAction = `
                <a href="${practiceUrl}" class="rounded-xl bg-white px-5 py-3 font-bold text-blue-950 hover:bg-blue-50">
                    Start Practice
                </a>
            `;
        } else if (subject.is_in_cart) {
            primaryAction = `
                <a href="cart.html" class="rounded-xl bg-white px-5 py-3 font-bold text-blue-950 hover:bg-blue-50">
                    View Cart
                </a>
            `;
        } else {
            primaryAction = `
                <button id="add-cart-button" type="button" class="rounded-xl bg-white px-5 py-3 font-bold text-blue-950 hover:bg-blue-50">
                    Add to Cart
                </button>
            `;
        }

        document.getElementById('subject-stream').textContent =
            [
                subject.exam_authority,
                subject.category_name,
                subject.programme_section
            ].filter(Boolean).join(' • ');
        document.getElementById('subject-title').textContent =
            `${subject.subject_code} — ${subject.subject_title}`;
        document.getElementById('subject-description').textContent =
            subject.subject_description
            || 'Structured learning and exam-practice support for this insurance subject.';
        document.getElementById('learning-status').textContent =
            subject.has_learning_content
                ? 'Learning resources are available in the academic content hierarchy.'
                : 'The learning structure is ready; subject resources are being prepared.';
        document.getElementById('demo-status').textContent = demoReady
            ? `Try ${requiredDemoQuestions} active advanced-level questions before purchase.`
            : 'The demo will open after ten active advanced-level questions are available.';
        document.getElementById('practice-status').textContent =
            subject.is_entitled
                ? 'Your entitlement is active. The subject is available on your practice dashboard.'
                : 'Practice access becomes active only after verified payment or an approved complimentary grant.';
        document.getElementById('subject-actions').innerHTML = `
            ${demoReady ? `
                <a href="${signedIn ? demoUrl : authDestination(demoUrl)}" class="rounded-xl bg-red-600 px-5 py-3 font-bold text-white hover:bg-red-700">
                    Free Advanced Demo
                </a>
            ` : ''}
            ${primaryAction}
            <a href="catalogue.html" class="rounded-xl border border-blue-300 px-5 py-3 font-bold text-white hover:bg-blue-900">
                Other Subjects
            </a>
        `;

        document.getElementById('subject-loading').classList.add('hidden');
        document.getElementById('subject-content').classList.remove('hidden');

        document.getElementById('add-cart-button')?.addEventListener(
            'click',
            async (event) => {
                if (!signedIn) {
                    global.location.href = authDestination(currentUrl);
                    return;
                }

                const button = event.currentTarget;
                button.disabled = true;
                button.textContent = 'Adding…';
                const { error } = await client.rpc('add_subject_to_cart', {
                    p_subject_id: Number(subject.subject_id)
                });

                if (error) {
                    console.error('Unable to add to cart:', error);
                    if (await sessionControl.handleInactiveSessionError(error)) {
                        return;
                    }
                    showMessage(
                        error.message || 'The subject could not be added to the cart.'
                    );
                    button.disabled = false;
                    button.textContent = 'Add to Cart';
                    return;
                }

                global.location.href = 'cart.html';
            }
        );
    }

    async function initialise() {
        const id = subjectId();
        if (!id) {
            document.getElementById('subject-loading').classList.add('hidden');
            showMessage('No valid subject was selected.');
            return;
        }

        try {
            const { data: { user } } = await client.auth.getUser();
            if (user) {
                const pageControl = sessionControl.acquirePageControl({
                    blockOnCancel: false
                });
                if (!pageControl.acquired) {
                    return;
                }
                if (!await sessionControl.activateProtectedPage(
                    client,
                    pageControl.tookOver
                )) {
                    return;
                }
                signedIn = true;
                const accountLink = document.getElementById('account-link');
                accountLink.href = 'dashboard.html';
                accountLink.textContent = 'My Practice';
            }

            const { data, error } = await client.rpc(
                'get_subject_catalogue'
            );
            if (error) {
                throw error;
            }

            const subject = (data || []).find(
                (item) => Number(item.subject_id) === id
            );
            if (!subject) {
                throw new Error('The selected subject is not available.');
            }
            render(subject);
        } catch (error) {
            console.error('Subject loading error:', error);
            if (await sessionControl.handleInactiveSessionError(error)) {
                return;
            }
            document.getElementById('subject-loading').classList.add('hidden');
            showMessage(
                error.message || 'The subject could not be loaded.'
            );
        }
    }

    void initialise();
}(window));
