(function initialiseCatalogue(global) {
    'use strict';

    const sessionControl = global.InsureGPTESessionControl;
    const securityNotices = global.InsureGPTESecurityNotices;
    const supabaseModule = global.InsureGPTESupabase;
    // Safeguard: sessionControl.clientOptions()
    const client = supabaseModule.getClient();

    const state = {
        signedIn: false,
        pageControl: null,
        subjects: [],
        category: 'all',
        search: ''
    };

    function escapeHtml(value) {
        const element = document.createElement('div');
        element.textContent = String(value ?? '');
        return element.innerHTML;
    }

    function categoryKey(subject) {
        return String(subject.category_code || 'other')
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, '-');
    }

    function categoryName(subject) {
        return subject.category_name || 'Other insurance programmes';
    }

    function subjectIcon(subject) {
        const category = `${subject.category_name || ''} ${subject.programme_category || ''}`.toLowerCase();

        if (category.includes('broker')) {
            return '↔';
        }
        if (category.includes('fellow')) {
            return '★';
        }
        if (category.includes('associate')) {
            return '◆';
        }
        if (category.includes('diploma') || category.includes('special')) {
            return '▤';
        }
        return '✓';
    }

    function money(subject) {
        const amount = Number(subject.price || 0);
        const currency = subject.currency_code || 'INR';

        if (amount <= 0) {
            return 'Price to be announced';
        }

        try {
            return new Intl.NumberFormat('en-IN', {
                style: 'currency',
                currency,
                maximumFractionDigits: 2
            }).format(amount);
        } catch (error) {
            return `${currency} ${amount.toFixed(2)}`;
        }
    }

    function authDestination(next) {
        return `index.html?next=${encodeURIComponent(next)}`;
    }

    function demoUrl(subject) {
        return `test.html?subject_id=${encodeURIComponent(subject.subject_id)}`
            + `&subject_code=${encodeURIComponent(subject.subject_code)}`
            + '&mode=demo';
    }

    function card(subject) {
        const entitled = Boolean(subject.is_entitled);
        const inCart = Boolean(subject.is_in_cart);
        const requiredDemoQuestions = Math.min(
            10,
            Number(subject.demo_question_limit || 0)
        );
        const demoReady = Boolean(subject.is_demo_available)
            && requiredDemoQuestions > 0
            && Number(subject.advanced_question_count || 0)
                >= requiredDemoQuestions;
        const description = subject.subject_description
            || `Prepare for ${subject.subject_code} with structured learning and practice support.`;
        const learningUrl = `subject.html?subject_id=${encodeURIComponent(subject.subject_id)}`;
        const demoTarget = demoUrl(subject);
        const demoHref = state.signedIn
            ? demoTarget
            : authDestination(demoTarget);
        let purchaseButton;

        if (entitled) {
            purchaseButton = `
                <a
                    href="test.html?subject_id=${encodeURIComponent(subject.subject_id)}&subject_code=${encodeURIComponent(subject.subject_code)}"
                    class="rounded-lg bg-blue-700 px-4 py-2 text-center font-bold text-white hover:bg-blue-800"
                >
                    Open Practice
                </a>
            `;
        } else if (inCart) {
            purchaseButton = `
                <a
                    href="cart.html"
                    class="rounded-lg bg-sky-600 px-4 py-2 text-center font-bold text-white hover:bg-sky-700"
                >
                    View in Cart
                </a>
            `;
        } else {
            purchaseButton = `
                <button
                    type="button"
                    data-add-cart="${escapeHtml(subject.subject_id)}"
                    class="rounded-lg bg-sky-600 px-4 py-2 font-bold text-white hover:bg-sky-700 disabled:cursor-not-allowed disabled:opacity-60"
                >
                    Add to Cart
                </button>
            `;
        }

        return `
            <article class="flex h-full flex-col rounded-2xl border border-slate-200 bg-white p-6 shadow-sm transition hover:-translate-y-1 hover:shadow-lg">
                <div class="flex items-start justify-between gap-4">
                    <div class="flex h-16 w-16 items-center justify-center rounded-2xl border-2 border-blue-600 bg-blue-50 text-3xl font-black text-red-600">
                        ${subjectIcon(subject)}
                    </div>
                    <div class="text-right text-xs font-bold uppercase tracking-wide text-slate-500">
                        ${escapeHtml(subject.exam_authority || subject.qualification_level || '')}
                    </div>
                </div>
                <h3 class="mt-5 text-2xl font-extrabold leading-snug text-blue-900">
                    ${escapeHtml(subject.subject_code)} — ${escapeHtml(subject.subject_title)}
                </h3>
                <p class="mt-3 flex-1 leading-7 text-slate-600">
                    ${escapeHtml(description)}
                </p>
                <div class="mt-4 flex flex-wrap gap-2 text-xs font-semibold">
                    ${subject.programme_section ? `<span class="rounded-full bg-slate-100 px-3 py-1">${escapeHtml(subject.programme_section)}</span>` : ''}
                    ${subject.has_learning_content ? '<span class="rounded-full bg-emerald-100 px-3 py-1 text-emerald-800">Learning content available</span>' : '<span class="rounded-full bg-amber-100 px-3 py-1 text-amber-800">Learning content being prepared</span>'}
                    ${entitled ? '<span class="rounded-full bg-blue-100 px-3 py-1 text-blue-800">Access active</span>' : ''}
                </div>
                <p class="mt-5 font-bold text-slate-800">${escapeHtml(money(subject))}</p>
                <div class="mt-5 grid grid-cols-1 gap-2 sm:grid-cols-3">
                    <a href="${learningUrl}" class="rounded-lg bg-emerald-600 px-4 py-2 text-center font-bold text-white hover:bg-emerald-700">
                        Learning
                    </a>
                    ${demoReady ? `
                        <a href="${demoHref}" class="rounded-lg bg-red-600 px-4 py-2 text-center font-bold text-white hover:bg-red-700">
                            Free Demo
                        </a>
                    ` : `
                        <span title="Ten active advanced questions are required" class="cursor-not-allowed rounded-lg bg-slate-200 px-4 py-2 text-center font-bold text-slate-500">
                            Demo Soon
                        </span>
                    `}
                    ${purchaseButton}
                </div>
            </article>
        `;
    }

    function filteredSubjects() {
        const search = state.search.toLowerCase();

        return state.subjects.filter((subject) => {
            const matchesCategory = state.category === 'all'
                || categoryKey(subject) === state.category;
            const haystack = [
                subject.subject_code,
                subject.subject_title,
                subject.subject_description,
                subject.category_name,
                subject.qualification_level,
                subject.exam_authority,
                subject.programme_name,
                subject.programme_category,
                subject.programme_section
            ].join(' ').toLowerCase();

            return matchesCategory && (!search || haystack.includes(search));
        });
    }

    function renderTabs() {
        const categories = new Map();

        state.subjects.forEach((subject) => {
            categories.set(categoryKey(subject), categoryName(subject));
        });

        const tabs = [['all', 'All subjects'], ...categories.entries()];
        document.getElementById('category-tabs').innerHTML = tabs
            .map(([key, label]) => `
                <button
                    type="button"
                    data-category="${escapeHtml(key)}"
                    class="${state.category === key ? 'bg-blue-700 text-white' : 'bg-slate-100 text-slate-700 hover:bg-slate-200'} rounded-full px-4 py-2 text-sm font-bold"
                >
                    ${escapeHtml(label)}
                </button>
            `)
            .join('');

        document.querySelectorAll('[data-category]').forEach((button) => {
            button.addEventListener('click', () => {
                state.category = button.dataset.category;
                renderTabs();
                renderGroups();
            });
        });
    }

    function renderGroups() {
        const container = document.getElementById('catalogue-groups');
        const subjects = filteredSubjects();
        const groups = new Map();

        subjects.forEach((subject) => {
            const name = categoryName(subject);
            if (!groups.has(name)) {
                groups.set(name, []);
            }
            groups.get(name).push(subject);
        });

        if (!subjects.length) {
            container.innerHTML = `
                <div class="rounded-2xl border border-slate-200 bg-white p-10 text-center text-slate-500">
                    No subjects match this filter.
                </div>
            `;
            return;
        }

        container.innerHTML = [...groups.entries()]
            .map(([name, groupSubjects]) => `
                <section>
                    <div class="mb-5">
                        <p class="text-sm font-bold uppercase tracking-[0.2em] text-blue-700">
                            Insurance examination stream
                        </p>
                        <h2 class="mt-1 text-3xl font-extrabold text-slate-900">
                            ${escapeHtml(name)}
                        </h2>
                    </div>
                    <div class="grid gap-6 md:grid-cols-2 xl:grid-cols-3">
                        ${groupSubjects.map(card).join('')}
                    </div>
                </section>
            `)
            .join('');

        document.querySelectorAll('[data-add-cart]').forEach((button) => {
            button.addEventListener('click', () => {
                void addToCart(button);
            });
        });
    }

    function showMessage(message, type = 'error') {
        const box = document.getElementById('message-box');
        box.textContent = message;
        box.className = type === 'success'
            ? 'mb-6 rounded-xl bg-emerald-100 p-4 text-emerald-900'
            : 'mb-6 rounded-xl bg-red-100 p-4 text-red-900';
    }

    async function addToCart(button) {
        const subjectId = Number(button.dataset.addCart);

        if (!state.signedIn) {
            global.location.href = authDestination('catalogue.html');
            return;
        }

        button.disabled = true;
        button.textContent = 'Adding…';

        try {
            const { error } = await client.rpc('add_subject_to_cart', {
                p_subject_id: subjectId
            });

            if (error) {
                throw error;
            }

            const subject = state.subjects.find(
                (item) => Number(item.subject_id) === subjectId
            );
            if (subject) {
                subject.is_in_cart = true;
            }

            showMessage('The subject was added to your cart.', 'success');
            renderGroups();
            updateCartCount();
        } catch (error) {
            console.error('Unable to add subject to cart:', error);
            if (await sessionControl.handleInactiveSessionError(error)) {
                return;
            }
            showMessage(
                error.message || 'The subject could not be added to your cart.'
            );
            button.disabled = false;
            button.textContent = 'Add to Cart';
        }
    }

    function updateCartCount() {
        const count = state.subjects.filter(
            (subject) => subject.is_in_cart
        ).length;
        document.getElementById('cart-count').textContent = String(count);
    }

    async function initialiseSession() {
        const { data: { user } } = await client.auth.getUser();

        if (!user) {
            return;
        }

        state.pageControl = sessionControl.acquirePageControl({
            blockOnCancel: false
        });
        if (!state.pageControl.acquired) {
            return;
        }

        if (!await sessionControl.activateProtectedPage(
            client,
            state.pageControl.tookOver
        )) {
            return;
        }

        securityNotices.start({ client, sessionControl });

        state.signedIn = true;
        document.getElementById('dashboard-link').classList.remove('hidden');
        document.getElementById('cart-link').classList.remove('hidden');
        const authLink = document.getElementById('auth-link');
        authLink.href = 'dashboard.html';
        authLink.textContent = 'My Account';
    }

    async function initialise() {
        try {
            await initialiseSession();

            const { data, error } = await client.rpc(
                'get_subject_catalogue'
            );
            if (error) {
                throw error;
            }

            state.subjects = data || [];
            document.getElementById('catalogue-loading').classList.add('hidden');
            updateCartCount();
            renderTabs();
            renderGroups();
        } catch (error) {
            console.error('Catalogue loading error:', error);
            if (await sessionControl.handleInactiveSessionError(error)) {
                return;
            }
            document.getElementById('catalogue-loading').classList.add('hidden');
            showMessage(
                'The catalogue is temporarily unavailable. Please try again shortly.'
            );
        }
    }

    document.getElementById('catalogue-search')
        .addEventListener('input', (event) => {
            state.search = event.target.value.trim();
            renderGroups();
        });

    void initialise();
}(window));
