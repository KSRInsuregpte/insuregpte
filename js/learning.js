(function initialiseLearningModule(global) {
    'use strict';

    const SUPABASE_URL = 'https://tvjsivuibvzybdbjtesq.supabase.co';
    const SUPABASE_ANON_KEY =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        + 'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2anNpdnVpYnZ6eWJkYmp0ZXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0MTI1MjksImV4cCI6MjA5ODk4ODUyOX0.'
        + 'meGmoVDJE25neU_na5xl8u3CYxA24M7tqcG5ez-emaU';
    const sessionControl = global.InsureGPTESessionControl;
    const securityNotices = global.InsureGPTESecurityNotices;
    const client = global.supabase.createClient(
        SUPABASE_URL,
        SUPABASE_ANON_KEY,
        sessionControl.clientOptions()
    );

    let subject = null;
    let hierarchy = [];
    let currentTopic = null;
    let topicOpenedAt = null;

    function escapeHtml(value) {
        const element = document.createElement('div');
        element.textContent = String(value ?? '');
        return element.innerHTML;
    }

    function showMessage(message, type = 'error') {
        const box = document.getElementById('message-box');
        box.textContent = message;
        box.className = type === 'error'
            ? 'mb-5 rounded-xl bg-red-100 p-4 text-red-900'
            : 'mb-5 rounded-xl bg-emerald-100 p-4 text-emerald-900';
    }

    function clearMessage() {
        document.getElementById('message-box').className =
            'hidden mb-5 rounded-xl p-4';
    }

    function selectedSubjectId() {
        const value = Number(
            new URLSearchParams(global.location.search).get('subject_id')
        );
        return Number.isInteger(value) && value > 0 ? value : null;
    }

    function statusLabel(status) {
        return {
            not_started: 'Not started',
            in_progress: 'In progress',
            completed: 'Completed'
        }[status] || 'Not started';
    }

    function formatMinutes(minutes) {
        const total = Math.max(Number(minutes || 0), 0);
        if (total < 60) {
            return `${total} min`;
        }
        return `${Math.floor(total / 60)}h ${total % 60}m`;
    }

    function safeExternalUrl(value) {
        try {
            const url = new URL(String(value || ''));
            return url.protocol === 'https:' ? url.href : null;
        } catch {
            return null;
        }
    }

    async function callRpc(name, parameters) {
        const { data, error } = await client.rpc(name, parameters);
        if (error) {
            throw error;
        }
        return data || [];
    }

    function renderStatistics(statistics) {
        const row = statistics?.[0] || {};
        document.getElementById('stat-topics').textContent =
            String(row.total_topics || 0);
        document.getElementById('stat-completed').textContent =
            String(row.completed_topics || 0);
        document.getElementById('stat-progress').textContent =
            `${Number(row.completion_percentage || 0).toFixed(0)}%`;
        document.getElementById('stat-time').textContent =
            formatMinutes(row.total_time_spent_minutes);
    }

    function groupHierarchy(rows) {
        const modules = new Map();
        rows.forEach((row) => {
            if (!modules.has(row.module_id)) {
                modules.set(row.module_id, {
                    id: row.module_id,
                    title: row.module_title,
                    chapters: new Map()
                });
            }
            const module = modules.get(row.module_id);
            if (!module.chapters.has(row.chapter_id)) {
                module.chapters.set(row.chapter_id, {
                    id: row.chapter_id,
                    title: row.chapter_title,
                    topics: []
                });
            }
            module.chapters.get(row.chapter_id).topics.push(row);
        });
        return [...modules.values()];
    }

    function renderHierarchy() {
        const container = document.getElementById('hierarchy-list');
        const modules = groupHierarchy(hierarchy);

        if (!modules.length) {
            container.innerHTML = `
                <p class="p-5 text-center text-sm text-slate-500">
                    The learning hierarchy has not yet been published for this subject.
                </p>`;
            return;
        }

        container.innerHTML = modules.map((module, moduleIndex) => `
            <details class="mb-3 rounded-xl border border-slate-200" ${moduleIndex === 0 ? 'open' : ''}>
                <summary class="cursor-pointer p-4 font-bold text-blue-950">
                    ${escapeHtml(module.title)}
                </summary>
                <div class="border-t border-slate-100 p-2">
                    ${[...module.chapters.values()].map((chapter) => `
                        <div class="mb-3">
                            <p class="px-2 py-1 text-xs font-bold uppercase tracking-wide text-slate-500">
                                ${escapeHtml(chapter.title)}
                            </p>
                            ${chapter.topics.map((topic) => `
                                <button type="button" data-topic-id="${topic.topic_id}"
                                    class="topic-button mt-1 flex w-full items-center justify-between gap-3 rounded-lg px-3 py-3 text-left text-sm hover:bg-blue-50">
                                    <span>${escapeHtml(topic.topic_title)}</span>
                                    <span class="text-xs font-bold ${topic.progress_status === 'completed' ? 'text-emerald-700' : 'text-slate-500'}">
                                        ${topic.progress_status === 'completed' ? '✓' : `${Number(topic.completion_percentage || 0).toFixed(0)}%`}
                                    </span>
                                </button>
                            `).join('')}
                        </div>
                    `).join('')}
                </div>
            </details>
        `).join('');

        container.querySelectorAll('[data-topic-id]').forEach((button) => {
            button.addEventListener('click', () => {
                void selectTopic(Number(button.dataset.topicId));
            });
        });
    }

    function renderResources(resources) {
        const list = document.getElementById('resource-list');
        if (!resources.length) {
            list.innerHTML = '<p class="py-8 text-center text-slate-500">No active learning resources are available for this topic yet.</p>';
            return;
        }

        list.innerHTML = resources.map((resource) => {
            const externalUrl = safeExternalUrl(resource.external_url);
            return `
            <article class="rounded-xl border ${resource.is_locked ? 'border-amber-200 bg-amber-50' : 'border-slate-200'} p-5">
                <div class="flex flex-wrap items-start justify-between gap-3">
                    <div>
                        <p class="text-xs font-bold uppercase tracking-wide text-blue-700">${escapeHtml(resource.resource_type_name)}</p>
                        <h3 class="mt-1 text-lg font-bold text-slate-900">${escapeHtml(resource.resource_title)}</h3>
                        <p class="mt-2 text-sm leading-6 text-slate-600">${escapeHtml(resource.short_description || '')}</p>
                    </div>
                    <div class="text-right text-xs text-slate-500">
                        ${resource.estimated_read_minutes ? `${resource.estimated_read_minutes} min` : ''}
                        ${resource.is_premium ? '<p class="mt-1 font-bold text-amber-700">Premium</p>' : '<p class="mt-1 font-bold text-emerald-700">Open resource</p>'}
                    </div>
                </div>
                ${resource.is_locked ? `
                    <p class="mt-4 rounded-lg bg-amber-100 p-3 text-sm text-amber-900">
                        Active subject access is required to open this premium resource.
                    </p>
                ` : `
                    <button type="button" data-resource-toggle="${resource.resource_id}"
                        class="mt-4 rounded-lg bg-blue-700 px-4 py-2 text-sm font-bold text-white hover:bg-blue-800">
                        Open Resource
                    </button>
                    <div id="resource-${resource.resource_id}" class="hidden mt-4 rounded-lg bg-slate-50 p-4">
                        ${resource.content ? `<div class="whitespace-pre-wrap text-sm leading-7 text-slate-700">${escapeHtml(resource.content)}</div>` : ''}
                        ${externalUrl ? `<a href="${escapeHtml(externalUrl)}" target="_blank" rel="noopener noreferrer" class="mt-3 inline-block font-bold text-blue-700 underline">Open approved external resource</a>` : ''}
                        ${resource.attachment_path ? `<p class="mt-3 text-xs text-slate-500">Attachment reference: ${escapeHtml(resource.attachment_path)}</p>` : ''}
                    </div>
                `}
            </article>
        `;
        }).join('');

        resources.filter((resource) => !resource.is_locked).forEach((resource) => {
            list.querySelector(`[data-resource-toggle="${resource.resource_id}"]`)
                ?.addEventListener('click', (event) => {
                    document.getElementById(`resource-${resource.resource_id}`)
                        ?.classList.toggle('hidden');
                    event.currentTarget.textContent = 'Resource Opened';
                    void recordActivity(
                        resource.resource_type_code === 'note'
                            ? 'note_viewed'
                            : 'resource_viewed',
                        Number(resource.resource_id),
                        null
                    );
                }, { once: true });
        });
    }

    function renderTopic(details, resources) {
        currentTopic = details;
        topicOpenedAt = Date.now();
        document.getElementById('topic-breadcrumb').textContent =
            `${details.module_title} › ${details.chapter_title}`;
        document.getElementById('topic-title').textContent = details.topic_title;
        document.getElementById('topic-description').textContent =
            details.topic_description || 'Topic learning material';
        document.getElementById('topic-objective').textContent =
            details.learning_objective || 'Learning objective will be added with the approved content.';
        document.getElementById('topic-relevance').textContent =
            details.practical_relevance || 'Practical relevance will be added with the approved content.';
        document.getElementById('topic-status').textContent =
            `${statusLabel(details.progress_status)} · ${Number(details.completion_percentage || 0).toFixed(0)}%`;
        document.getElementById('complete-topic-button').disabled =
            details.progress_status === 'completed';
        document.getElementById('complete-topic-button').textContent =
            details.progress_status === 'completed'
                ? 'Topic Completed'
                : 'Mark Topic Complete';
        document.getElementById('flashcards-panel').classList.add('hidden');
        renderResources(resources);
        document.getElementById('topic-empty').classList.add('hidden');
        document.getElementById('topic-content').classList.remove('hidden');
    }

    async function selectTopic(topicId) {
        clearMessage();
        try {
            const [detailsRows, resources] = await Promise.all([
                callRpc('get_topic_details', { p_topic_id: topicId }),
                callRpc('get_learning_resources', { p_topic_id: topicId })
            ]);
            if (!detailsRows.length) {
                throw new Error('The selected topic is not available.');
            }
            renderTopic(detailsRows[0], resources);
            document.querySelectorAll('.topic-button').forEach((button) => {
                button.classList.toggle(
                    'bg-blue-100',
                    Number(button.dataset.topicId) === topicId
                );
            });
        } catch (error) {
            console.error('Topic loading error:', error);
            if (await sessionControl.handleInactiveSessionError(error)) {
                return;
            }
            showMessage('The selected learning topic could not be loaded.');
        }
    }

    async function recordActivity(activityType, referenceId, completion) {
        if (!currentTopic) {
            return null;
        }
        const duration = topicOpenedAt
            ? Math.min(Math.floor((Date.now() - topicOpenedAt) / 1000), 86400)
            : 0;
        const result = await callRpc('record_learning_activity', {
            p_topic_id: Number(currentTopic.topic_id),
            p_activity_type: activityType,
            p_reference_id: referenceId,
            p_duration_seconds: duration,
            p_completion_percentage: completion
        });
        topicOpenedAt = Date.now();
        return result;
    }

    async function loadFlashcards() {
        if (!currentTopic) {
            return;
        }
        const button = document.getElementById('flashcards-button');
        button.disabled = true;
        try {
            const flashcards = await callRpc('get_flashcards', {
                p_topic_id: Number(currentTopic.topic_id)
            });
            const list = document.getElementById('flashcard-list');
            list.innerHTML = flashcards.length ? flashcards.map((card) => `
                <article class="rounded-xl bg-white p-5 shadow-sm">
                    <p class="text-xs font-bold uppercase text-violet-700">${escapeHtml(card.difficulty_level)}</p>
                    <h3 class="mt-2 font-bold text-violet-950">${escapeHtml(card.question)}</h3>
                    <button type="button" data-flashcard-id="${card.flashcard_id}" class="mt-4 rounded-lg bg-violet-700 px-4 py-2 text-sm font-bold text-white">Reveal Answer</button>
                    <div id="flashcard-${card.flashcard_id}" class="hidden mt-4 border-t pt-4">
                        <p class="whitespace-pre-wrap text-sm leading-6 text-slate-700">${escapeHtml(card.answer)}</p>
                        ${card.explanation ? `<p class="mt-3 text-xs leading-5 text-slate-500">${escapeHtml(card.explanation)}</p>` : ''}
                    </div>
                </article>
            `).join('') : '<p class="text-violet-800">No active flashcards are available for this topic yet.</p>';
            flashcards.forEach((card) => {
                list.querySelector(`[data-flashcard-id="${card.flashcard_id}"]`)
                    ?.addEventListener('click', (event) => {
                        document.getElementById(`flashcard-${card.flashcard_id}`)
                            ?.classList.remove('hidden');
                        event.currentTarget.disabled = true;
                        event.currentTarget.textContent = 'Answer Revealed';
                        void recordActivity(
                            'flashcard_reviewed',
                            Number(card.flashcard_id),
                            null
                        );
                    }, { once: true });
            });
            document.getElementById('flashcards-panel').classList.remove('hidden');
        } catch (error) {
            console.error('Flashcard loading error:', error);
            if (await sessionControl.handleInactiveSessionError(error)) {
                return;
            }
            showMessage(
                error.code === 'PT403'
                    ? 'Active subject access is required to review flashcards.'
                    : 'Flashcards could not be loaded.'
            );
        } finally {
            button.disabled = false;
        }
    }

    async function completeTopic() {
        const button = document.getElementById('complete-topic-button');
        button.disabled = true;
        try {
            await recordActivity('topic_completed', null, 100);
            showMessage('Topic completed. Your learning progress has been updated.', 'success');
            await loadSubjectLearning(Number(currentTopic.topic_id));
        } catch (error) {
            console.error('Topic completion error:', error);
            if (await sessionControl.handleInactiveSessionError(error)) {
                return;
            }
            showMessage(
                error.code === 'PT403'
                    ? 'Active subject access is required to complete this topic.'
                    : 'Topic progress could not be updated.'
            );
            button.disabled = false;
        }
    }

    async function loadSubjectLearning(preferredTopicId = null) {
        const [hierarchyRows, statistics, resumeRows] = await Promise.all([
            callRpc('get_subject_hierarchy', { p_subject_id: subject.subject_id }),
            callRpc('get_learning_statistics', { p_subject_id: subject.subject_id }),
            callRpc('get_resume_learning', { p_subject_id: subject.subject_id })
        ]);
        hierarchy = hierarchyRows;
        renderStatistics(statistics);
        renderHierarchy();
        document.getElementById('learning-loading').classList.add('hidden');
        document.getElementById('learning-workspace').classList.remove('hidden');

        const initialTopicId = preferredTopicId
            || resumeRows?.[0]?.topic_id
            || hierarchy?.[0]?.topic_id;
        if (initialTopicId) {
            await selectTopic(Number(initialTopicId));
        }
    }

    async function logout() {
        const button = document.getElementById('logout-button');
        button.disabled = true;
        const result = await sessionControl.logoutEverywhere(client);
        if (!result.success) {
            button.disabled = false;
            showMessage('Unable to log out. Please try again.');
            return;
        }
        global.location.replace('index.html');
    }

    async function initialise() {
        const subjectId = selectedSubjectId();
        if (!subjectId) {
            document.getElementById('learning-loading').classList.add('hidden');
            showMessage('No valid subject was selected.');
            return;
        }

        const pageControl = sessionControl.acquirePageControl();
        if (!pageControl.acquired) {
            return;
        }

        try {
            const { data: { user }, error: userError } = await client.auth.getUser();
            if (userError || !user) {
                sessionControl.releasePageControl();
                global.location.replace(
                    `index.html?next=${encodeURIComponent(`learning.html?subject_id=${subjectId}`)}`
                );
                return;
            }
            if (!await sessionControl.activateProtectedPage(client, pageControl.tookOver)) {
                return;
            }
            securityNotices.start({
                client,
                sessionControl,
                panel: document.getElementById('security-notices'),
                list: document.getElementById('security-notices-list'),
                onError: showMessage
            });

            const catalogue = await callRpc('get_subject_catalogue');
            subject = catalogue.find(
                (item) => Number(item.subject_id) === subjectId
            );
            if (!subject) {
                throw new Error('The selected subject is not available.');
            }
            document.getElementById('subject-title').textContent =
                `${subject.subject_code} — ${subject.subject_title}`;
            document.getElementById('subject-description').textContent =
                subject.subject_description
                || 'Structured learning resources and progress tracking.';
            document.getElementById('subject-link').href =
                `subject.html?subject_id=${subjectId}`;
            await loadSubjectLearning();
        } catch (error) {
            console.error('Learning Module loading error:', error);
            if (await sessionControl.handleInactiveSessionError(error)) {
                return;
            }
            document.getElementById('learning-loading').classList.add('hidden');
            showMessage('The Learning Module could not be loaded. Please try again.');
        }
    }

    document.getElementById('logout-button').addEventListener('click', () => void logout());
    document.getElementById('flashcards-button').addEventListener('click', () => void loadFlashcards());
    document.getElementById('close-flashcards').addEventListener('click', () => {
        document.getElementById('flashcards-panel').classList.add('hidden');
    });
    document.getElementById('complete-topic-button').addEventListener('click', () => void completeTopic());
    void initialise();
}(window));
