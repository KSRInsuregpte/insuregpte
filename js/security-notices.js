(function initialiseInsureGPTESecurityNotices(global) {
    'use strict';

    const REFRESH_INTERVAL_MS = 15000;

    function createDefaultMount() {
        const panel = document.createElement('section');
        panel.id = 'insuregpte-global-security-notices';
        panel.setAttribute('aria-live', 'polite');
        panel.style.cssText = [
            'position:fixed',
            'top:88px',
            'right:20px',
            'z-index:2147483000',
            'display:none',
            'width:min(420px,calc(100vw - 40px))',
            'max-height:calc(100vh - 112px)',
            'overflow:auto',
            'border:1px solid #f59e0b',
            'border-radius:16px',
            'background:#fffbeb',
            'padding:16px',
            'color:#451a03',
            'box-shadow:0 18px 45px rgba(15,23,42,0.22)',
            'font:400 14px/1.5 system-ui,sans-serif'
        ].join(';');

        const heading = document.createElement('h2');
        heading.textContent = 'Account Notice';
        heading.style.cssText = 'margin:0 0 12px;font-size:18px;font-weight:800';

        const list = document.createElement('div');
        list.id = 'insuregpte-global-security-notices-list';

        panel.append(heading, list);
        document.body.append(panel);
        return { panel, list, ownsMount: true };
    }

    function createNoticeCard(notice, acknowledge) {
        const article = document.createElement('article');
        article.style.cssText = [
            'border:1px solid #fde68a',
            'border-radius:12px',
            'background:white',
            'padding:14px'
        ].join(';');

        const subject = document.createElement('p');
        subject.textContent = String(notice.subject || 'Account notice');
        subject.style.cssText = 'margin:0;font-weight:800';

        const body = document.createElement('p');
        body.textContent = String(notice.message_body || '');
        body.style.cssText = 'margin:6px 0 0';

        const footer = document.createElement('div');
        footer.style.cssText = [
            'display:flex',
            'align-items:center',
            'justify-content:space-between',
            'gap:12px',
            'margin-top:12px',
            'flex-wrap:wrap'
        ].join(';');

        const created = document.createElement('span');
        created.textContent = notice.created_at
            ? new Date(notice.created_at).toLocaleString()
            : '';
        created.style.cssText = 'font-size:12px;color:#92400e';

        const button = document.createElement('button');
        button.type = 'button';
        button.textContent = 'I Understand';
        button.style.cssText = [
            'border:1px solid #d97706',
            'border-radius:9px',
            'background:white',
            'padding:8px 12px',
            'color:#78350f',
            'font-weight:800',
            'cursor:pointer'
        ].join(';');
        button.addEventListener('click', () => {
            void acknowledge(notice.notification_id, button);
        });

        footer.append(created, button);
        article.append(subject, body, footer);
        return article;
    }

    function start(options) {
        const settings = options || {};
        const client = settings.client;
        const sessionControl = settings.sessionControl;

        if (!client || !sessionControl) {
            throw new Error(
                'Account notices require the authenticated client and session control.'
            );
        }

        const suppliedPanel = settings.panel || null;
        const suppliedList = settings.list || null;
        const mount = suppliedPanel && suppliedList
            ? { panel: suppliedPanel, list: suppliedList, ownsMount: false }
            : createDefaultMount();
        let stopped = false;
        let refreshPromise = null;
        let timer = null;

        function render(notices) {
            mount.list.replaceChildren();

            if (!Array.isArray(notices) || notices.length === 0) {
                if (mount.ownsMount) {
                    mount.panel.style.display = 'none';
                } else {
                    mount.panel.classList.add('hidden');
                }
                return;
            }

            for (const notice of notices) {
                mount.list.append(createNoticeCard(notice, acknowledge));
            }

            if (mount.ownsMount) {
                mount.panel.style.display = 'block';
            } else {
                mount.panel.classList.remove('hidden');
            }
        }

        async function handleError(error, fallbackMessage) {
            if (await sessionControl.handleInactiveSessionError(error, client)) {
                return;
            }

            console.error(fallbackMessage, error);
            if (typeof settings.onError === 'function') {
                settings.onError(fallbackMessage);
            }
        }

        async function refresh() {
            if (stopped) {
                return;
            }
            if (refreshPromise) {
                return refreshPromise;
            }

            refreshPromise = (async () => {
                const { data, error } = await client.rpc(
                    'get_my_security_notices',
                    { p_limit: 10 }
                );
                if (error) {
                    await handleError(
                        error,
                        'Account notices could not be refreshed.'
                    );
                    return;
                }
                render(data || []);
            })().finally(() => {
                refreshPromise = null;
            });

            return refreshPromise;
        }

        async function acknowledge(notificationId, button) {
            button.disabled = true;
            const { error } = await client.rpc(
                'acknowledge_my_security_notice',
                { p_notification_id: Number(notificationId) }
            );
            if (error) {
                button.disabled = false;
                await handleError(
                    error,
                    'The account notice could not be acknowledged.'
                );
                return;
            }
            await refresh();
        }

        function refreshWhenVisible() {
            if (document.visibilityState === 'visible') {
                void refresh();
            }
        }

        function stop() {
            if (stopped) {
                return;
            }
            stopped = true;
            global.clearInterval(timer);
            global.removeEventListener('focus', refreshWhenVisible);
            document.removeEventListener('visibilitychange', refreshWhenVisible);
            if (mount.ownsMount) {
                mount.panel.remove();
            }
        }

        global.addEventListener('focus', refreshWhenVisible);
        document.addEventListener('visibilitychange', refreshWhenVisible);
        global.addEventListener('pagehide', stop, { once: true });
        timer = global.setInterval(() => void refresh(), REFRESH_INTERVAL_MS);
        void refresh();

        return Object.freeze({ refresh, stop });
    }

    global.InsureGPTESecurityNotices = Object.freeze({ start });
}(window));
