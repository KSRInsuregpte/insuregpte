import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const repositoryRoot = path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    '..'
);

const testHtml = fs.readFileSync(
    path.join(repositoryRoot, 'test.html'),
    'utf8'
);
const dashboardHtml = fs.readFileSync(
    path.join(repositoryRoot, 'dashboard.html'),
    'utf8'
);

function extractFunction(source, functionName) {
    const asyncStartMarker = `async function ${functionName}(`;
    const syncStartMarker = `function ${functionName}(`;
    const asyncStartIndex = source.indexOf(asyncStartMarker);
    const startIndex = asyncStartIndex >= 0
        ? asyncStartIndex
        : source.indexOf(syncStartMarker);

    if (startIndex < 0) {
        throw new Error(`Function ${functionName} is missing.`);
    }

    const openingBrace = source.indexOf('{', startIndex);
    let depth = 0;

    for (let index = openingBrace; index < source.length; index += 1) {
        if (source[index] === '{') {
            depth += 1;
        } else if (source[index] === '}') {
            depth -= 1;

            if (depth === 0) {
                return source.slice(startIndex, index + 1);
            }
        }
    }

    throw new Error(`Function ${functionName} is incomplete.`);
}

function assert(condition, message) {
    if (!condition) {
        throw new Error(message);
    }
}

function createElement(initialClasses = []) {
    const classes = new Set(initialClasses);
    const attributes = new Map();

    return {
        classList: {
            add(value) {
                classes.add(value);
            },
            remove(value) {
                classes.delete(value);
            },
            contains(value) {
                return classes.has(value);
            }
        },
        innerText: '',
        disabled: false,
        focused: false,
        scrolled: false,
        setAttribute(name, value) {
            attributes.set(name, value);
        },
        getAttribute(name) {
            return attributes.get(name);
        },
        focus() {
            this.focused = true;
        },
        scrollIntoView() {
            this.scrolled = true;
        }
    };
}

const quizLayout = createElement(['grid']);
const startPanel = createElement();
const finalScore = createElement();
const finalResult = createElement(['hidden']);
let timersCleared = 0;
const automaticNavigation = [];

const finalContext = {
    answeredCount: 50,
    totalQuestions: 50,
    currentScore: 42,
    attemptInProgress: true,
    clearTimers() {
        timersCleared += 1;
    },
    updateExitActions() {},
    document: {
        getElementById(id) {
            return {
                'quiz-layout': quizLayout,
                'start-panel': startPanel,
                'final-score': finalScore,
                'final-result': finalResult
            }[id];
        }
    },
    window: {
        location: {
            replace(url) {
                automaticNavigation.push(url);
            }
        }
    }
};

vm.createContext(finalContext);
vm.runInContext(
    `${extractFunction(testHtml, 'showFinal')}\nshowFinal();`,
    finalContext
);

assert(timersCleared === 1, 'Quiz timers were not stopped after completion.');
assert(
    finalContext.attemptInProgress === false,
    'The completed attempt remained marked as in progress.'
);
assert(
    quizLayout.classList.contains('hidden') &&
        !quizLayout.classList.contains('grid'),
    'The question layout remained visible after completion.'
);
assert(
    !finalResult.classList.contains('hidden') && finalResult.scrolled,
    'The completion confirmation was not shown to the learner.'
);
assert(
    finalScore.innerText.includes('50 of 50') &&
        finalScore.innerText.includes('42 out of 50'),
    'The completion summary did not show the authoritative attempt totals.'
);
assert(
    automaticNavigation.length === 0,
    'Completing the final answer must not navigate away automatically.'
);

const backButton = createElement();
const dashboardExitButton = createElement();
const logoutButton = createElement();
const finishAttemptButton = createElement();
const exitActionElements = {
    'back-button': backButton,
    'dashboard-exit-button': dashboardExitButton,
    'logout-button': logoutButton,
    'finish-attempt-button': finishAttemptButton
};
const exitLabelContext = {
    attemptInProgress: true,
    document: {
        getElementById(id) {
            return exitActionElements[id];
        }
    }
};

vm.createContext(exitLabelContext);
vm.runInContext(
    `${extractFunction(testHtml, 'updateExitActions')}\n` +
        'updateExitActions();',
    exitLabelContext
);

assert(
    backButton.innerText === 'Finish Attempt & Return' &&
        dashboardExitButton.innerText === 'Finish Attempt & Return' &&
        logoutButton.innerText === 'Finish Attempt & Logout',
    'Active-attempt exit actions did not clearly state that they finish the quiz.'
);

exitLabelContext.attemptInProgress = false;
vm.runInContext('updateExitActions();', exitLabelContext);

assert(
    backButton.innerText === '← Back' &&
        dashboardExitButton.innerText === '← Back to Dashboard' &&
        logoutButton.innerText === 'Logout',
    'Normal Back and Logout labels were not restored after finalization.'
);

const exitConfirmation = createElement(['hidden']);
const exitConfirmationTitle = createElement();
const confirmExitButton = createElement();
const continueQuizButton = createElement();
const triggerButton = createElement();
const confirmationElements = {
    'exit-confirmation': exitConfirmation,
    'exit-confirmation-title': exitConfirmationTitle,
    'confirm-exit-button': confirmExitButton,
    'continue-quiz-button': continueQuizButton
};
const confirmationContext = {
    pendingExitAction: null,
    lastExitTrigger: null,
    document: {
        activeElement: triggerButton,
        getElementById(id) {
            return confirmationElements[id];
        }
    }
};

vm.createContext(confirmationContext);
vm.runInContext(
    `${extractFunction(testHtml, 'showExitConfirmation')}\n` +
        `${extractFunction(testHtml, 'closeExitConfirmation')}\n` +
        "showExitConfirmation('logout');",
    confirmationContext
);

assert(
    confirmationContext.pendingExitAction === 'logout' &&
        !exitConfirmation.classList.contains('hidden') &&
        exitConfirmation.classList.contains('flex') &&
        exitConfirmation.getAttribute('aria-hidden') === 'false',
    'The active-attempt confirmation did not open accessibly.'
);
assert(
    exitConfirmationTitle.innerText === 'Finish attempt and logout?' &&
        confirmExitButton.innerText === 'Finish Attempt & Logout' &&
        continueQuizButton.focused,
    'The logout confirmation did not provide the approved learner choices.'
);

vm.runInContext('closeExitConfirmation();', confirmationContext);

assert(
    confirmationContext.pendingExitAction === null &&
        exitConfirmation.classList.contains('hidden') &&
        !exitConfirmation.classList.contains('flex') &&
        triggerButton.focused,
    'Continue Quiz did not close the confirmation and restore focus.'
);

async function runConfirmedExit(action, finalisationResult, logoutResult = true) {
    const calls = {
        closed: 0,
        finalised: [],
        dashboard: 0,
        logout: 0,
        finalResult: 0
    };
    const context = {
        pendingExitAction: action,
        closeExitConfirmation() {
            calls.closed += 1;
        },
        async finaliseAttempt(message, showResult) {
            calls.finalised.push([message, showResult]);
            return finalisationResult;
        },
        navigateToDashboard() {
            calls.dashboard += 1;
        },
        async logoutWithoutFinalising() {
            calls.logout += 1;
            return logoutResult;
        },
        showFinal() {
            calls.finalResult += 1;
        }
    };

    vm.createContext(context);
    vm.runInContext(
        `${extractFunction(testHtml, 'confirmExit')}\n` +
            'exitPromise = confirmExit();',
        context
    );
    await context.exitPromise;
    return calls;
}

const dashboardExit = await runConfirmedExit('dashboard', true);
assert(
    dashboardExit.closed === 1 &&
        dashboardExit.finalised.length === 1 &&
        dashboardExit.finalised[0][0] === null &&
        dashboardExit.finalised[0][1] === false &&
        dashboardExit.dashboard === 1 &&
        dashboardExit.logout === 0,
    'Finish Attempt & Return did not finalize before dashboard navigation.'
);

const rejectedDashboardExit = await runConfirmedExit('dashboard', false);
assert(
    rejectedDashboardExit.dashboard === 0 &&
        rejectedDashboardExit.logout === 0,
    'A failed finalization incorrectly allowed the learner to leave the quiz.'
);

const logoutExit = await runConfirmedExit('logout', true);
assert(
    logoutExit.finalised.length === 1 &&
        logoutExit.logout === 1 &&
        logoutExit.dashboard === 0,
    'Finish Attempt & Logout did not finalize before signing out.'
);

const failedLogout = await runConfirmedExit('logout', true, false);
assert(
    failedLogout.logout === 1 && failedLogout.finalResult === 1,
    'A completed attempt was not shown when the subsequent logout failed.'
);

function runExitRequest(functionName, attemptIsActive) {
    const calls = {
        confirmation: [],
        dashboard: 0,
        logout: 0
    };
    const activeElement = createElement();
    const context = {
        attemptInProgress: attemptIsActive,
        document: {
            activeElement
        },
        showExitConfirmation(action, trigger) {
            calls.confirmation.push([action, trigger]);
        },
        navigateToDashboard() {
            calls.dashboard += 1;
        },
        async logoutWithoutFinalising() {
            calls.logout += 1;
            return true;
        }
    };

    vm.createContext(context);
    vm.runInContext(
        `${extractFunction(testHtml, functionName)}\n${functionName}();`,
        context
    );
    return { calls, activeElement };
}

const preStartBack = runExitRequest('requestDashboardExit', false);
assert(
    preStartBack.calls.dashboard === 1 &&
        preStartBack.calls.confirmation.length === 0,
    'Back did not retain normal navigation before an attempt started.'
);

const activeBack = runExitRequest('requestDashboardExit', true);
assert(
    activeBack.calls.dashboard === 0 &&
        activeBack.calls.confirmation.length === 1 &&
        activeBack.calls.confirmation[0][0] === 'dashboard' &&
        activeBack.calls.confirmation[0][1] === activeBack.activeElement,
    'Active Back did not require the approved finish confirmation.'
);

const preStartLogout = runExitRequest('logout', false);
assert(
    preStartLogout.calls.logout === 1 &&
        preStartLogout.calls.confirmation.length === 0,
    'Logout did not retain normal behavior before an attempt started.'
);

const activeLogout = runExitRequest('logout', true);
assert(
    activeLogout.calls.logout === 0 &&
        activeLogout.calls.confirmation.length === 1 &&
        activeLogout.calls.confirmation[0][0] === 'logout',
    'Active Logout did not require the approved finish confirmation.'
);

let releasedPageControl = 0;
const dashboardNavigation = [];
const navigationContext = {
    sessionControl: {
        releasePageControl() {
            releasedPageControl += 1;
        }
    },
    window: {
        location: {
            replace(url) {
                dashboardNavigation.push(url);
            }
        }
    }
};

vm.createContext(navigationContext);
vm.runInContext(
    `${extractFunction(testHtml, 'navigateToDashboard')}\n` +
        'navigateToDashboard();',
    navigationContext
);

assert(
    releasedPageControl === 1,
    'The quiz page did not release page control before dashboard navigation.'
);
assert(
    dashboardNavigation.length === 1 &&
        dashboardNavigation[0] === 'dashboard.html',
    'The completion action did not return to subject selection.'
);

const attemptCountContext = {};
vm.createContext(attemptCountContext);
vm.runInContext(
    `${extractFunction(dashboardHtml, 'countAttemptsBySubject')}\n` +
        'result = countAttemptsBySubject([' +
        "{subject_id: 1, attempt_status: 'completed'}," +
        "{subject_id: 1, attempt_status: 'in_progress'}," +
        "{subject_id: 2, attempt_status: 'abandoned'}" +
        ']);',
    attemptCountContext
);

assert(
    attemptCountContext.result['1'] === 2 &&
        attemptCountContext.result['2'] === 1,
    'Dashboard attempt totals must count every created attempt status.'
);
assert(
    testHtml.includes(
        "if(r.completed){attemptInProgress=false;clearReview();showFinal()}"
    ),
    'The final-answer completion branch is missing.'
);
assert(
    testHtml.includes(
        "document.getElementById('return-dashboard-button').onclick=" +
        'navigateToDashboard'
    ),
    'The learner-controlled dashboard return action is missing.'
);
assert(
    testHtml.includes(
        'This will finish the attempt. Submitted answers will be scored and ' +
        'unanswered questions will receive zero.'
    ) &&
        testHtml.includes('>Continue Quiz</button>'),
    'The approved active-attempt warning and Continue Quiz action are missing.'
);
assert(
    !testHtml.includes('<a href="dashboard.html"'),
    'The quiz still contains a dashboard link that can bypass finalization.'
);
assert(
    testHtml.includes(
        "client.rpc('finalize_quiz_attempt',{p_attempt_id:currentAttemptId})"
    ),
    'Active exits are not using the existing finalize_quiz_attempt RPC.'
);

console.log(
    'Quiz completion behavior checks passed: the final result remains visible, ' +
    'active exits finalize before navigation or logout, Continue Quiz remains ' +
    'available, and attempt totals include all statuses.'
);
