import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const repositoryRoot = path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    '..'
);
const source = fs.readFileSync(
    path.join(repositoryRoot, 'js', 'screen-protection.js'),
    'utf8'
);

function createEvent(type, values = {}) {
    return {
        type,
        defaultPrevented: false,
        preventDefault() {
            this.defaultPrevented = true;
        },
        ...values
    };
}

function createProtectedPage({ blockContextMenu = true } = {}) {
    const elements = new Map();
    const documentListeners = new Map();
    const windowListeners = new Map();

    function rememberElement(element) {
        if (element.id) {
            elements.set(element.id, element);
        }
    }

    const body = {
        classList: {
            values: new Set(),
            add(value) {
                this.values.add(value);
            }
        },
        dataset: {
            screenProtectionLabel: 'InsureGPTE test',
            ...(blockContextMenu
                ? { screenProtectionContextMenu: 'disabled' }
                : {})
        },
        appendChild(element) {
            rememberElement(element);
        }
    };
    const documentObject = {
        body,
        head: {
            appendChild(element) {
                rememberElement(element);
            }
        },
        readyState: 'complete',
        addEventListener(type, listener) {
            const listeners = documentListeners.get(type) || [];
            listeners.push(listener);
            documentListeners.set(type, listeners);
        },
        createElement() {
            return {
                dataset: {},
                id: '',
                setAttribute() {},
                textContent: ''
            };
        },
        getElementById(id) {
            return elements.get(id) || null;
        }
    };
    const windowObject = {
        document: documentObject,
        addEventListener(type, listener) {
            const listeners = windowListeners.get(type) || [];
            listeners.push(listener);
            windowListeners.set(type, listeners);
        },
        clearTimeout() {},
        setTimeout() {
            return 1;
        }
    };

    windowObject.window = windowObject;

    const context = vm.createContext({
        document: documentObject,
        Set,
        String,
        window: windowObject
    });

    new vm.Script(source, {
        filename: 'js/screen-protection.js'
    }).runInContext(context);

    return {
        body,
        dispatchDocumentEvent(event) {
            for (const listener of documentListeners.get(event.type) || []) {
                listener(event);
            }
        },
        elements
    };
}

const page = createProtectedPage();

assert.equal(page.body.dataset.screenProtectionActive, 'true');
assert.equal(
    page.body.classList.values.has('insuregpte-protected-screen'),
    true
);
assert.ok(page.elements.has('insuregpte-screen-protection-style'));
assert.ok(page.elements.has('insuregpte-screen-protection-notice'));
assert.ok(page.elements.has('insuregpte-print-protection-notice'));

const ordinaryTyping = createEvent('keydown', { key: 'a' });
page.dispatchDocumentEvent(ordinaryTyping);
assert.equal(
    ordinaryTyping.defaultPrevented,
    false,
    'ordinary typing must remain available'
);

for (const event of [
    createEvent('copy'),
    createEvent('cut'),
    createEvent('paste'),
    createEvent('dragstart'),
    createEvent('contextmenu'),
    createEvent('keydown', { ctrlKey: true, key: 'c' }),
    createEvent('keydown', { ctrlKey: true, key: 'v' }),
    createEvent('keydown', { ctrlKey: true, key: 'p' }),
    createEvent('keydown', { key: 'PrintScreen' })
]) {
    page.dispatchDocumentEvent(event);
    assert.equal(
        event.defaultPrevented,
        true,
        `${event.type} protection should prevent the browser default`
    );
}

const contextMenuAllowedPage = createProtectedPage({
    blockContextMenu: false
});
const allowedContextMenu = createEvent('contextmenu');

contextMenuAllowedPage.dispatchDocumentEvent(allowedContextMenu);
assert.equal(
    allowedContextMenu.defaultPrevented,
    false,
    'right-click must remain available when the page does not opt in'
);

const protectionStyle = page.elements.get(
    'insuregpte-screen-protection-style'
);
assert.match(protectionStyle.textContent, /@media print/);
assert.match(
    protectionStyle.textContent,
    /#insuregpte-print-protection-notice/
);

console.log('Screen-protection behavior checks passed.');
