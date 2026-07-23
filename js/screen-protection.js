(function initialiseInsureGPTEScreenProtection(global) {
    'use strict';

    const PROTECTED_PAGE_CLASS = 'insuregpte-protected-screen';
    const STYLE_ID = 'insuregpte-screen-protection-style';
    const NOTICE_ID = 'insuregpte-screen-protection-notice';
    const PRINT_NOTICE_ID = 'insuregpte-print-protection-notice';
    const BLOCKED_EVENT_TYPES = new Set([
        'copy',
        'cut',
        'paste',
        'dragstart'
    ]);
    const BLOCKED_SHORTCUT_KEYS = new Set(['c', 'p', 'v', 'x']);
    let noticeTimer = null;

    function createProtectionStyle() {
        if (document.getElementById(STYLE_ID)) {
            return;
        }

        const style = document.createElement('style');
        style.id = STYLE_ID;
        style.textContent = `
            body.${PROTECTED_PAGE_CLASS} {
                -webkit-user-select: none;
                user-select: none;
            }

            body.${PROTECTED_PAGE_CLASS} input,
            body.${PROTECTED_PAGE_CLASS} select,
            body.${PROTECTED_PAGE_CLASS} textarea {
                -webkit-user-select: text;
                user-select: text;
            }

            body.${PROTECTED_PAGE_CLASS}::after {
                position: fixed;
                top: 50%;
                left: 50%;
                z-index: 2147483000;
                color: rgb(15 23 42 / 7%);
                content: attr(data-screen-protection-label);
                font-size: clamp(1.5rem, 5vw, 4rem);
                font-weight: 800;
                letter-spacing: 0.08em;
                pointer-events: none;
                text-align: center;
                text-transform: uppercase;
                transform: translate(-50%, -50%) rotate(-24deg);
                white-space: nowrap;
            }

            #${NOTICE_ID} {
                position: fixed;
                right: 1rem;
                bottom: 1rem;
                z-index: 2147483647;
                max-width: min(26rem, calc(100vw - 2rem));
                border: 1px solid rgb(251 191 36);
                border-radius: 0.75rem;
                background: rgb(255 251 235);
                box-shadow: 0 10px 30px rgb(15 23 42 / 18%);
                color: rgb(146 64 14);
                font: 600 0.875rem/1.4 Arial, Helvetica, sans-serif;
                opacity: 0;
                padding: 0.875rem 1rem;
                pointer-events: none;
                transform: translateY(0.5rem);
                transition: opacity 150ms ease, transform 150ms ease;
            }

            #${NOTICE_ID}[data-visible="true"] {
                opacity: 1;
                transform: translateY(0);
            }

            #${PRINT_NOTICE_ID} {
                display: none;
            }

            @media print {
                body.${PROTECTED_PAGE_CLASS} > *:not(#${PRINT_NOTICE_ID}) {
                    display: none !important;
                }

                body.${PROTECTED_PAGE_CLASS}::after {
                    display: none !important;
                }

                #${PRINT_NOTICE_ID} {
                    display: block !important;
                    margin: 3rem;
                    border: 2px solid #991b1b;
                    padding: 2rem;
                    color: #991b1b;
                    font: 700 18pt/1.5 Arial, Helvetica, sans-serif;
                    text-align: center;
                }
            }
        `;
        document.head.appendChild(style);
    }

    function createProtectionNotice() {
        if (document.getElementById(NOTICE_ID)) {
            return;
        }

        const notice = document.createElement('div');
        notice.id = NOTICE_ID;
        notice.dataset.visible = 'false';
        notice.setAttribute('role', 'status');
        notice.setAttribute('aria-live', 'polite');
        document.body.appendChild(notice);

        const printNotice = document.createElement('div');
        printNotice.id = PRINT_NOTICE_ID;
        printNotice.textContent =
            'Printing is disabled for this protected InsureGPTE screen.';
        document.body.appendChild(printNotice);
    }

    function showProtectionNotice(message) {
        const notice = document.getElementById(NOTICE_ID);

        if (!notice) {
            return;
        }

        notice.textContent = message;
        notice.dataset.visible = 'true';

        if (noticeTimer) {
            global.clearTimeout(noticeTimer);
        }

        noticeTimer = global.setTimeout(() => {
            notice.dataset.visible = 'false';
        }, 2500);
    }

    function blockProtectedInteraction(event) {
        event.preventDefault();

        if (event.type === 'paste') {
            showProtectionNotice(
                'Pasting is disabled on this protected InsureGPTE screen.'
            );
            return;
        }

        showProtectionNotice(
            'Copying protected InsureGPTE screen content is disabled.'
        );
    }

    function blockProtectedShortcut(event) {
        const key = String(event.key || '').toLowerCase();
        const usesCommandModifier = event.ctrlKey || event.metaKey;
        const blocksCommandShortcut =
            usesCommandModifier && BLOCKED_SHORTCUT_KEYS.has(key);
        const blocksPasteShortcut = event.shiftKey && key === 'insert';
        const blocksScreenshotKey = key === 'printscreen';

        if (
            !blocksCommandShortcut &&
            !blocksPasteShortcut &&
            !blocksScreenshotKey
        ) {
            return;
        }

        event.preventDefault();

        if (key === 'p') {
            showProtectionNotice(
                'Printing is disabled on this protected InsureGPTE screen.'
            );
            return;
        }

        if (blocksScreenshotKey) {
            showProtectionNotice(
                'Screenshots are prohibited on this protected InsureGPTE screen.'
            );
            return;
        }

        showProtectionNotice(
            'Copy and paste are disabled on this protected InsureGPTE screen.'
        );
    }

    function blockProtectedContextMenu(event) {
        event.preventDefault();
        showProtectionNotice(
            'Right-click is disabled on this protected InsureGPTE screen.'
        );
    }

    function activateScreenProtection() {
        if (
            !document.body ||
            document.body.dataset.screenProtectionActive === 'true'
        ) {
            return;
        }

        document.body.dataset.screenProtectionActive = 'true';
        document.body.classList.add(PROTECTED_PAGE_CLASS);

        if (!document.body.dataset.screenProtectionLabel) {
            document.body.dataset.screenProtectionLabel =
                'InsureGPTE protected screen';
        }

        createProtectionStyle();
        createProtectionNotice();

        for (const eventType of BLOCKED_EVENT_TYPES) {
            document.addEventListener(
                eventType,
                blockProtectedInteraction
            );
        }

        document.addEventListener('keydown', blockProtectedShortcut);

        if (
            document.body.dataset.screenProtectionContextMenu === 'disabled'
        ) {
            document.addEventListener(
                'contextmenu',
                blockProtectedContextMenu
            );
        }

        global.addEventListener('beforeprint', () => {
            showProtectionNotice(
                'Printing is disabled on this protected InsureGPTE screen.'
            );
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener(
            'DOMContentLoaded',
            activateScreenProtection,
            { once: true }
        );
    } else {
        activateScreenProtection();
    }
})(window);
