(function initialiseCart(global) {
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
    let items = [];

    function escapeHtml(value) {
        const element = document.createElement('div');
        element.textContent = String(value ?? '');
        return element.innerHTML;
    }

    function money(amount, currency = 'INR') {
        try {
            return new Intl.NumberFormat('en-IN', {
                style: 'currency',
                currency,
                maximumFractionDigits: 2
            }).format(Number(amount || 0));
        } catch (error) {
            return `${currency} ${Number(amount || 0).toFixed(2)}`;
        }
    }

    function showMessage(message, type = 'error') {
        const box = document.getElementById('message-box');
        box.textContent = message;
        box.className = type === 'success'
            ? 'mb-5 rounded-xl bg-emerald-100 p-4 text-emerald-900'
            : 'mb-5 rounded-xl bg-red-100 p-4 text-red-900';
    }

    function render() {
        const container = document.getElementById('cart-items');

        if (!items.length) {
            container.innerHTML = `
                <div class="p-10 text-center">
                    <p class="font-semibold text-slate-700">Your cart is empty.</p>
                    <a href="catalogue.html" class="mt-4 inline-block rounded-lg bg-blue-700 px-5 py-3 font-bold text-white hover:bg-blue-800">
                        Browse Subjects
                    </a>
                </div>
            `;
            document.getElementById('cart-total').textContent = '₹0.00';
            return;
        }

        container.innerHTML = items.map((item) => `
            <article class="flex flex-col gap-4 p-5 sm:flex-row sm:items-center sm:justify-between">
                <div>
                    <p class="font-bold text-blue-900">
                        ${escapeHtml(item.subject_code)} — ${escapeHtml(item.subject_title)}
                    </p>
                    <p class="mt-1 text-sm text-slate-500">
                        Added ${new Date(item.added_at).toLocaleDateString('en-IN')}
                    </p>
                </div>
                <div class="flex items-center gap-4">
                    <strong>${escapeHtml(money(item.unit_price, item.currency_code))}</strong>
                    <button
                        type="button"
                        data-remove-subject="${escapeHtml(item.subject_id)}"
                        class="rounded-lg border border-red-200 px-3 py-2 text-sm font-bold text-red-700 hover:bg-red-50"
                    >
                        Remove
                    </button>
                </div>
            </article>
        `).join('');

        const currency = items[0].currency_code || 'INR';
        const total = items.reduce(
            (sum, item) => sum + Number(item.unit_price || 0),
            0
        );
        document.getElementById('cart-total').textContent =
            money(total, currency);

        document.querySelectorAll('[data-remove-subject]')
            .forEach((button) => {
                button.addEventListener('click', () => {
                    void removeItem(button);
                });
            });
    }

    async function removeItem(button) {
        const subjectId = Number(button.dataset.removeSubject);
        button.disabled = true;
        button.textContent = 'Removing…';

        try {
            const { error } = await client.rpc(
                'remove_subject_from_cart',
                { p_subject_id: subjectId }
            );
            if (error) {
                throw error;
            }

            items = items.filter(
                (item) => Number(item.subject_id) !== subjectId
            );
            showMessage('The subject was removed from your cart.', 'success');
            render();
        } catch (error) {
            console.error('Cart update error:', error);
            if (await sessionControl.handleInactiveSessionError(error)) {
                return;
            }
            showMessage('The cart could not be updated. Please try again.');
            button.disabled = false;
            button.textContent = 'Remove';
        }
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
                global.location.replace(
                    `index.html?next=${encodeURIComponent('cart.html')}`
                );
                return;
            }

            if (!await sessionControl.activateProtectedPage(
                client,
                pageControl.tookOver
            )) {
                return;
            }

            const { data, error } = await client.rpc('get_my_cart');
            if (error) {
                throw error;
            }

            items = data || [];
            render();
        } catch (error) {
            console.error('Cart loading error:', error);
            if (await sessionControl.handleInactiveSessionError(error)) {
                return;
            }
            showMessage('Your cart could not be loaded. Please try again.');
            document.getElementById('cart-items').innerHTML =
                '<p class="p-8 text-center text-red-700">Cart unavailable.</p>';
        }
    }

    void initialise();
}(window));
