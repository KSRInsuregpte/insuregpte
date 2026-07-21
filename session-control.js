(function initialiseInsureGPTESessionControl(windowObject) {
    'use strict';

    const CLIENT_STORAGE_KEY = 'insuregpte.active-client-id.v1';
    const PAGE_LOCK_KEY = 'insuregpte.active-page-lock.v1';
    const CLIENT_HEADER = 'x-insuregpte-client-id';
    const PAGE_LOCK_LIFETIME_MS = 100000;
    const PAGE_LOCK_RENEW_MS = 5000;
    const HEARTBEAT_MS = 10000;
    const ACTIVITY_HEARTBEAT_MINIMUM_MS = 3000;
    const UUID_PATTERN =
        /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

    const pageInstanceId = createUuid();
    const clientId = readOrCreateClientId();

    let ownsPageControl = false;
    let pageLockRenewal = null;
    let heartbeatTimer = null;
    let heartbeatClient = null;
    let heartbeatPromise = null;
    let lastHeartbeatStartedAt = 0;
    let inactiveRedirectStarted = false;
    let activityListenersInstalled = false;

    function createUuid() {
        if (typeof windowObject.crypto?.randomUUID === 'function') {
            return windowObject.crypto.randomUUID();
        }

        const bytes = new Uint8Array(16);
        windowObject.crypto.getRandomValues(bytes);
        bytes[6] = (bytes[6] & 0x0f) | 0x40;
        bytes[8] = (bytes[8] & 0x3f) | 0x80;

        const hexadecimal = Array.from(
            bytes,
            value => value.toString(16).padStart(2, '0')
        ).join('');

        return [
            hexadecimal.slice(0, 8),
            hexadecimal.slice(8, 12),
            hexadecimal.slice(12, 16),
            hexadecimal.slice(16, 20),
            hexadecimal.slice(20)
        ].join('-');
    }

    function readOrCreateClientId() {
        try {
            const existing = windowObject.sessionStorage.getItem(
                CLIENT_STORAGE_KEY
            );

            if (existing && UUID_PATTERN.test(existing)) {
                return existing;
            }

            const created = createUuid();
            windowObject.sessionStorage.setItem(
                CLIENT_STORAGE_KEY,
                created
            );
            return created;
        } catch (error) {
            console.error('Unable to initialise browser session control:', error);
            return createUuid();
        }
    }

    function clientOptions() {
        return {
            global: {
                headers: {
                    [CLIENT_HEADER]: clientId
                }
            }
        };
    }

    function readPageLock() {
        try {
            const rawValue = windowObject.localStorage.getItem(PAGE_LOCK_KEY);

            if (!rawValue) {
                return null;
            }

            const parsed = JSON.parse(rawValue);

            if (
                typeof parsed?.owner !== 'string' ||
                typeof parsed?.expiresAt !== 'number'
            ) {
                return null;
            }

            return parsed;
        } catch (error) {
            console.error('Unable to read the active-page control:', error);
            return null;
        }
    }

    function writePageLock() {
        const lock = {
            owner: pageInstanceId,
            expiresAt: Date.now() + PAGE_LOCK_LIFETIME_MS
        };

        windowObject.localStorage.setItem(
            PAGE_LOCK_KEY,
            JSON.stringify(lock)
        );

        const storedLock = readPageLock();
        return storedLock?.owner === pageInstanceId;
    }

    function pageControlWarning() {
        return (
            'InsureGPTE is already active in another tab of this browser.\n\n' +
            'Select OK to use this page and disable the other page.\n' +
            'Select Cancel to keep the existing page active.'
        );
    }

    function acquirePageControl(options) {
        const settings = {
            allowTakeoverPrompt: true,
            blockOnCancel: true,
            ...(options || {})
        };

        let existingLock;

        try {
            existingLock = readPageLock();

            if (
                existingLock &&
                existingLock.owner !== pageInstanceId &&
                existingLock.expiresAt > Date.now()
            ) {
                if (
                    !settings.allowTakeoverPrompt ||
                    !windowObject.confirm(pageControlWarning())
                ) {
                    if (settings.blockOnCancel) {
                        blockPage(
                            'This duplicate page is disabled. ' +
                            'Continue using the page that was already active.'
                        );
                    }

                    return {
                        acquired: false,
                        tookOver: false
                    };
                }

                if (!writePageLock()) {
                    throw new Error(
                        'Another page acquired control at the same time.'
                    );
                }

                ownsPageControl = true;
                startPageLockRenewal();

                return {
                    acquired: true,
                    tookOver: true
                };
            }

            if (!writePageLock()) {
                throw new Error('Unable to acquire active-page control.');
            }

            ownsPageControl = true;
            startPageLockRenewal();

            return {
                acquired: true,
                tookOver: false
            };
        } catch (error) {
            console.error('Unable to acquire active-page control:', error);

            if (settings.blockOnCancel) {
                blockPage(
                    'InsureGPTE could not safely confirm that this is the ' +
                    'only active page. Close other InsureGPTE pages and reload.'
                );
            }

            return {
                acquired: false,
                tookOver: false
            };
        }
    }

    function startPageLockRenewal() {
        if (pageLockRenewal) {
            windowObject.clearInterval(pageLockRenewal);
        }

        pageLockRenewal = windowObject.setInterval(() => {
            if (!ownsPageControl) {
                return;
            }

            const currentLock = readPageLock();

            if (
                currentLock &&
                currentLock.owner !== pageInstanceId &&
                currentLock.expiresAt > Date.now()
            ) {
                deactivateAndRedirect(
                    'This page was disabled because another page was selected ' +
                    'as the active InsureGPTE login.'
                );
                return;
            }

            try {
                if (!writePageLock()) {
                    throw new Error('The active-page control was replaced.');
                }
            } catch (error) {
                console.error('Unable to renew active-page control:', error);
                deactivateAndRedirect(
                    'This page can no longer confirm that it is the active ' +
                    'InsureGPTE page.'
                );
            }
        }, PAGE_LOCK_RENEW_MS);
    }

    function releasePageControl() {
        if (pageLockRenewal) {
            windowObject.clearInterval(pageLockRenewal);
            pageLockRenewal = null;
        }

        if (!ownsPageControl) {
            return;
        }

        try {
            const currentLock = readPageLock();

            if (currentLock?.owner === pageInstanceId) {
                windowObject.localStorage.removeItem(PAGE_LOCK_KEY);
            }
        } catch (error) {
            console.error('Unable to release active-page control:', error);
        }

        ownsPageControl = false;
    }

    function isInactiveSessionError(error) {
        return error?.code === 'PT401';
    }

    async function claimActiveClient(client, takeOver) {
        const { data, error } = await client.rpc('claim_active_client', {
            p_client_id: clientId,
            p_takeover: Boolean(takeOver)
        });

        if (error) {
            throw error;
        }

        const result = Array.isArray(data) ? data[0] : data;

        if (!result?.claim_status) {
            throw new Error(
                'The active-login service did not return a valid result.'
            );
        }

        return result;
    }

    function remoteLoginWarning() {
        return (
            'This account is already active in another browser or page.\n\n' +
            'Select OK to use this login and disable the other login.\n' +
            'Select Cancel to keep the first login active.'
        );
    }

    async function resolveDatabaseClaim(client, takeoverAlreadyApproved) {
        let result = await claimActiveClient(
            client,
            Boolean(takeoverAlreadyApproved)
        );

        if (!result.conflict) {
            return result;
        }

        if (!windowObject.confirm(remoteLoginWarning())) {
            return null;
        }

        result = await claimActiveClient(client, true);

        if (result.conflict) {
            throw new Error(
                'The other login changed while control was being transferred. ' +
                'Please try again.'
            );
        }

        return result;
    }

    async function activateAfterSignIn(client, takeoverAlreadyApproved) {
        const result = await resolveDatabaseClaim(
            client,
            takeoverAlreadyApproved
        );

        if (!result) {
            const { error: localSignOutError } =
                await client.auth.signOut({ scope: 'local' });

            if (localSignOutError) {
                console.error(
                    'Unable to clear the cancelled login:',
                    localSignOutError
                );
            }

            releasePageControl();

            windowObject.alert(
                'The second login was cancelled. The first login remains active.'
            );

            return false;
        }

        const { error: revokeError } =
            await client.auth.signOut({ scope: 'others' });

        if (revokeError) {
            // The database lease already blocks every other client. A failed
            // cleanup of older refresh sessions must not surrender that lease.
            console.error('Unable to clean up older Auth sessions:', revokeError);
        }

        return true;
    }

    async function activateProtectedPage(client, takeoverAlreadyApproved) {
        const result = await resolveDatabaseClaim(
            client,
            takeoverAlreadyApproved
        );

        if (!result) {
            const { error: localSignOutError } =
                await client.auth.signOut({ scope: 'local' });

            if (localSignOutError) {
                console.error(
                    'Unable to clear the cancelled login:',
                    localSignOutError
                );
            }

            releasePageControl();
            windowObject.location.replace('index.html?session=conflict');
            return false;
        }

        startHeartbeat(client);
        return true;
    }

    function startHeartbeat(client) {
        heartbeatClient = client;

        if (heartbeatTimer) {
            windowObject.clearInterval(heartbeatTimer);
        }

        heartbeatTimer = windowObject.setInterval(
            () => void verifyActiveClient(),
            HEARTBEAT_MS
        );

        installActivityListeners();
    }

    function stopHeartbeat() {
        if (heartbeatTimer) {
            windowObject.clearInterval(heartbeatTimer);
            heartbeatTimer = null;
        }

        heartbeatClient = null;
    }

    async function verifyActiveClient() {
        if (!heartbeatClient || inactiveRedirectStarted) {
            return;
        }

        let currentLock = readPageLock();

        if (!ownsPageControl) {
            deactivateAndRedirect(
                'This duplicate page is no longer the active InsureGPTE page.'
            );
            return;
        }

        if (
            currentLock?.owner !== pageInstanceId &&
            currentLock?.expiresAt > Date.now()
        ) {
            deactivateAndRedirect(
                'This duplicate page is no longer the active InsureGPTE page.'
            );
            return;
        }

        if (!currentLock || currentLock.expiresAt <= Date.now()) {
            try {
                if (!writePageLock()) {
                    throw new Error('Another page acquired control.');
                }

                currentLock = readPageLock();
            } catch (error) {
                console.error('Unable to recover active-page control:', error);
                deactivateAndRedirect(
                    'This page can no longer confirm that it is the active ' +
                    'InsureGPTE page.'
                );
                return;
            }
        }

        if (heartbeatPromise) {
            return heartbeatPromise;
        }

        lastHeartbeatStartedAt = Date.now();
        const activeClient = heartbeatClient;
        heartbeatPromise = (async () => {
            const { error } = await activeClient.rpc(
                'heartbeat_active_client',
                { p_client_id: clientId }
            );

            if (!error) {
                return;
            }

            if (!isInactiveSessionError(error)) {
                console.error('Unable to verify the active login:', error);
                return;
            }

            try {
                const recovery = await claimActiveClient(
                    activeClient,
                    false
                );

                if (!recovery.conflict) {
                    return;
                }
            } catch (claimError) {
                console.error(
                    'Unable to recover the active-login lease:',
                    claimError
                );
            }

            deactivateAndRedirect(
                'This page was disabled because another browser or page is ' +
                'now the active InsureGPTE login.'
            );
        })().finally(() => {
            heartbeatPromise = null;
        });

        return heartbeatPromise;
    }

    function requestActivityVerification() {
        if (
            Date.now() - lastHeartbeatStartedAt <
            ACTIVITY_HEARTBEAT_MINIMUM_MS
        ) {
            return;
        }

        void verifyActiveClient();
    }

    function installActivityListeners() {
        if (activityListenersInstalled) {
            return;
        }

        activityListenersInstalled = true;

        windowObject.addEventListener('focus', requestActivityVerification);
        windowObject.addEventListener('pointerdown', requestActivityVerification, true);
        windowObject.addEventListener('keydown', requestActivityVerification, true);
        windowObject.addEventListener('wheel', requestActivityVerification, {
            capture: true,
            passive: true
        });
        windowObject.addEventListener('touchstart', requestActivityVerification, {
            capture: true,
            passive: true
        });

        windowObject.document.addEventListener('visibilitychange', () => {
            if (windowObject.document.visibilityState === 'visible') {
                requestActivityVerification();
            }
        });
    }

    async function handleInactiveSessionError(error) {
        if (!isInactiveSessionError(error)) {
            return false;
        }

        deactivateAndRedirect(
            'This page was disabled because it is no longer the active login.'
        );
        return true;
    }

    function deactivateAndRedirect(message) {
        if (inactiveRedirectStarted) {
            return;
        }

        inactiveRedirectStarted = true;
        stopHeartbeat();
        releasePageControl();

        windowObject.dispatchEvent(
            new CustomEvent('insuregpte:session-inactive')
        );

        blockPage(message);

        windowObject.setTimeout(() => {
            windowObject.location.replace('index.html?session=replaced');
        }, 100);
    }

    function blockPage(message) {
        if (!windowObject.document.body) {
            windowObject.document.addEventListener(
                'DOMContentLoaded',
                () => blockPage(message),
                { once: true }
            );
            return;
        }

        let overlay = windowObject.document.getElementById(
            'insuregpte-session-overlay'
        );

        if (!overlay) {
            overlay = windowObject.document.createElement('div');
            overlay.id = 'insuregpte-session-overlay';
            overlay.setAttribute('role', 'alert');
            overlay.style.cssText = [
                'position:fixed',
                'inset:0',
                'z-index:2147483647',
                'display:flex',
                'align-items:center',
                'justify-content:center',
                'padding:24px',
                'background:rgba(15,23,42,0.96)',
                'color:white',
                'text-align:center'
            ].join(';');

            const panel = windowObject.document.createElement('div');
            panel.style.cssText = [
                'max-width:560px',
                'padding:28px',
                'border-radius:18px',
                'background:#1e3a8a',
                'box-shadow:0 20px 50px rgba(0,0,0,0.35)',
                'font:600 18px/1.5 system-ui,sans-serif'
            ].join(';');

            const heading = windowObject.document.createElement('h2');
            heading.textContent = 'This page is no longer active';
            heading.style.cssText = 'font-size:26px;margin:0 0 12px';

            const detail = windowObject.document.createElement('p');
            detail.id = 'insuregpte-session-overlay-message';
            detail.style.cssText = 'margin:0';

            panel.append(heading, detail);
            overlay.append(panel);
            windowObject.document.body.append(overlay);
        }

        const detail = windowObject.document.getElementById(
            'insuregpte-session-overlay-message'
        );

        if (detail) {
            detail.textContent = message;
        }

        windowObject.document.documentElement.style.overflow = 'hidden';
        windowObject.document.body.style.overflow = 'hidden';
    }

    async function logoutEverywhere(client) {
        stopHeartbeat();

        const { error: releaseError } = await client.rpc(
            'release_active_client',
            { p_client_id: clientId }
        );

        if (releaseError && isInactiveSessionError(releaseError)) {
            deactivateAndRedirect(
                'This page cannot log out the account because another login ' +
                'is already active.'
            );
            return {
                success: false,
                error: releaseError
            };
        }

        if (releaseError) {
            startHeartbeat(client);
            return {
                success: false,
                error: releaseError
            };
        }

        const { error: signOutError } = await client.auth.signOut();

        if (signOutError) {
            console.error('Unable to complete global Auth logout:', signOutError);

            const { error: localSignOutError } =
                await client.auth.signOut({ scope: 'local' });

            if (localSignOutError) {
                console.error(
                    'Unable to clear the local Auth session:',
                    localSignOutError
                );
            }
        }

        releasePageControl();

        try {
            windowObject.sessionStorage.removeItem(CLIENT_STORAGE_KEY);
        } catch (error) {
            console.error('Unable to clear the browser client id:', error);
        }

        return {
            success: true,
            error: signOutError || null
        };
    }

    windowObject.addEventListener('storage', event => {
        if (
            event.key !== PAGE_LOCK_KEY ||
            !ownsPageControl ||
            inactiveRedirectStarted
        ) {
            return;
        }

        const currentLock = readPageLock();

        if (
            currentLock &&
            currentLock.owner !== pageInstanceId &&
            currentLock.expiresAt > Date.now()
        ) {
            deactivateAndRedirect(
                'This page was disabled because another tab was selected as ' +
                'the active InsureGPTE page.'
            );
        }
    });

    windowObject.addEventListener('pagehide', () => {
        stopHeartbeat();
        releasePageControl();
    });

    windowObject.addEventListener('pageshow', event => {
        if (event.persisted) {
            windowObject.location.reload();
        }
    });

    windowObject.InsureGPTESessionControl = Object.freeze({
        acquirePageControl,
        activateAfterSignIn,
        activateProtectedPage,
        clientOptions,
        handleInactiveSessionError,
        isInactiveSessionError,
        logoutEverywhere,
        releasePageControl
    });
})(window);
