import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const repositoryRoot = path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    '..'
);
const sessionControlSource = fs.readFileSync(
    path.join(repositoryRoot, 'js/session-control.js'),
    'utf8'
);

class MemoryStorage {
    constructor(values = new Map()) {
        this.values = values;
    }

    getItem(key) {
        return this.values.has(key) ? this.values.get(key) : null;
    }

    setItem(key, value) {
        this.values.set(key, String(value));
    }

    removeItem(key) {
        this.values.delete(key);
    }
}

function createBrowser({ sharedLocalStorage, confirmations = [] } = {}) {
    const eventListeners = new Map();
    const documentListeners = new Map();
    const alerts = [];
    const redirects = [];
    let timerId = 0;

    const documentObject = {
        body: {
            append() {},
            style: {}
        },
        documentElement: {
            style: {}
        },
        visibilityState: 'visible',
        addEventListener(type, listener) {
            documentListeners.set(type, listener);
        },
        getElementById() {
            return null;
        },
        createElement() {
            return {
                append() {},
                setAttribute() {},
                style: {},
                textContent: ''
            };
        }
    };

    const windowObject = {
        crypto: {
            randomUUID: crypto.randomUUID,
            getRandomValues: crypto.getRandomValues
        },
        sessionStorage: new MemoryStorage(),
        localStorage: sharedLocalStorage || new MemoryStorage(),
        document: documentObject,
        location: {
            reload() {},
            replace(value) {
                redirects.push(value);
            }
        },
        confirm() {
            return confirmations.length ? confirmations.shift() : false;
        },
        alert(message) {
            alerts.push(message);
        },
        addEventListener(type, listener) {
            const listeners = eventListeners.get(type) || [];
            listeners.push(listener);
            eventListeners.set(type, listeners);
        },
        setInterval() {
            timerId += 1;
            return timerId;
        },
        clearInterval() {},
        setTimeout() {
            timerId += 1;
            return timerId;
        },
        CustomEvent: class CustomEvent {
            constructor(type) {
                this.type = type;
            }
        }
    };

    windowObject.dispatchEvent = event => {
        for (const listener of eventListeners.get(event.type) || []) {
            listener(event);
        }
    };
    windowObject.window = windowObject;

    const context = vm.createContext({
        console,
        CustomEvent: windowObject.CustomEvent,
        Uint8Array,
        window: windowObject
    });

    new vm.Script(sessionControlSource, {
        filename: 'js/session-control.js'
    }).runInContext(context);

    return {
        alerts,
        control: windowObject.InsureGPTESessionControl,
        redirects
    };
}

function createClient(claimResults = []) {
    const authCalls = [];
    const rpcCalls = [];

    return {
        authCalls,
        rpcCalls,
        auth: {
            async signOut(options) {
                authCalls.push(options || null);
                return { error: null };
            }
        },
        async rpc(functionName, parameters) {
            rpcCalls.push({ functionName, parameters });

            if (functionName === 'claim_active_client') {
                const result = claimResults.shift();
                return {
                    data: result ? [result] : null,
                    error: null
                };
            }

            if (functionName === 'release_active_client') {
                return { data: true, error: null };
            }

            return { data: null, error: null };
        }
    };
}

{
    const browser = createBrowser();
    const page = browser.control.acquirePageControl();
    const options = browser.control.clientOptions();

    assert.equal(page.acquired, true);
    assert.match(
        options.global.headers['x-insuregpte-client-id'],
        /^[0-9a-f-]{36}$/i
    );

    const client = createClient([
        {
            claim_status: 'acquired',
            conflict: false,
            lease_expires_at: '2026-07-20T00:00:00Z'
        }
    ]);

    assert.equal(
        await browser.control.activateAfterSignIn(client, false),
        true
    );
    assert.equal(client.rpcCalls[0].functionName, 'claim_active_client');
    assert.equal(client.rpcCalls[0].parameters.p_takeover, false);
    assert.equal(client.authCalls.length, 1);
    assert.equal(client.authCalls[0].scope, 'others');
}

{
    const browser = createBrowser({ confirmations: [false] });
    const client = createClient([
        {
            claim_status: 'conflict',
            conflict: true,
            lease_expires_at: null
        }
    ]);

    assert.equal(
        await browser.control.activateAfterSignIn(client, false),
        false
    );
    assert.equal(client.authCalls.length, 1);
    assert.equal(client.authCalls[0].scope, 'local');
    assert.equal(browser.alerts.length, 1);
}

{
    const browser = createBrowser({ confirmations: [true] });
    const client = createClient([
        {
            claim_status: 'conflict',
            conflict: true,
            lease_expires_at: null
        },
        {
            claim_status: 'taken_over',
            conflict: false,
            lease_expires_at: '2026-07-20T00:00:00Z'
        }
    ]);

    assert.equal(
        await browser.control.activateAfterSignIn(client, false),
        true
    );
    assert.deepEqual(
        client.rpcCalls.map(call => call.parameters.p_takeover),
        [false, true]
    );
    assert.equal(client.authCalls.length, 1);
    assert.equal(client.authCalls[0].scope, 'others');
}

{
    const sharedLocalStorage = new MemoryStorage();
    const firstBrowserPage = createBrowser({ sharedLocalStorage });
    const cancelledDuplicate = createBrowser({
        sharedLocalStorage,
        confirmations: [false]
    });

    assert.equal(
        firstBrowserPage.control.acquirePageControl().acquired,
        true
    );
    assert.equal(
        cancelledDuplicate.control.acquirePageControl({
            blockOnCancel: false
        }).acquired,
        false
    );

    const transferredDuplicate = createBrowser({
        sharedLocalStorage,
        confirmations: [true]
    });
    const transfer = transferredDuplicate.control.acquirePageControl();

    assert.equal(transfer.acquired, true);
    assert.equal(transfer.tookOver, true);
}

{
    const browser = createBrowser();
    const client = createClient();

    browser.control.acquirePageControl();

    const result = await browser.control.logoutEverywhere(client);

    assert.equal(result.success, true);
    assert.equal(client.rpcCalls[0].functionName, 'release_active_client');
    assert.deepEqual(client.authCalls, [null]);
}

console.log('Session-control behavior checks passed.');
