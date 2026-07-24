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
    const startMarker = `function ${functionName}(`;
    const startIndex = source.indexOf(startMarker);

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
        scrolled: false,
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

console.log(
    'Quiz completion behavior checks passed: the final result remains visible, ' +
    'dashboard navigation is explicit, and attempt totals include all statuses.'
);
