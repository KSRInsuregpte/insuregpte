(function initialiseAdminPortal(global) {
    'use strict';

    const SUPABASE_URL = 'https://tvjsivuibvzybdbjtesq.supabase.co';
    const SUPABASE_ANON_KEY =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        + 'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2anNpdnVpYnZ6eWJkYmp0ZXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0MTI1MjksImV4cCI6MjA5ODk4ODUyOX0.'
        + 'meGmoVDJE25neU_na5xl8u3CYxA24M7tqcG5ez-emaU';
    const sessionControl = global.InsureGPTESessionControl;
    const bulkUploadService = global.InsureGPTEAdminBulkUpload;
    const client = global.supabase.createClient(
        SUPABASE_URL,
        SUPABASE_ANON_KEY,
        sessionControl.clientOptions()
    );

    const state = {
        summary: null,
        subjects: [],
        questions: [],
        users: [],
        examInformation: [],
        auditEvents: [],
        securitySummary: null,
        securityEvents: [],
        enforcementCases: [],
        notificationOutbox: [],
        bulkUpload: null
    };
    const adminActionDialogState = {
        resolve: null,
        returnFocus: null
    };

    function byId(id) {
        return document.getElementById(id);
    }

    function escapeHtml(value) {
        const element = document.createElement('div');
        element.textContent = String(value ?? '');
        return element.innerHTML;
    }

    function optionalNumber(value) {
        return value === '' || value === null || value === undefined
            ? null
            : Number(value);
    }

    function showMessage(message, type = 'error') {
        const box = byId('message-box');
        box.textContent = message;
        box.className = type === 'success'
            ? 'mb-5 rounded-xl bg-emerald-100 p-4 text-emerald-800'
            : 'mb-5 rounded-xl bg-red-100 p-4 text-red-800';
        box.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }

    function clearMessage() {
        byId('message-box').className = 'hidden mb-5 rounded-xl p-4';
        byId('message-box').textContent = '';
    }

    function setBusy(button, busy, busyText) {
        if (!button.dataset.defaultText) {
            button.dataset.defaultText = button.textContent.trim();
        }
        button.disabled = busy;
        button.textContent = busy
            ? busyText
            : button.dataset.defaultText;
        button.classList.toggle('opacity-60', busy);
    }

    function difficultyLabel(value) {
        return {
            foundation: 'Easy',
            intermediate: 'Moderate',
            advanced: 'Hard'
        }[value] || value || 'Not set';
    }

    function difficultyInput(value) {
        return {
            foundation: 'easy',
            intermediate: 'moderate',
            advanced: 'hard'
        }[value] || 'easy';
    }

    const QUESTION_OPTION_TAGS = ['A', 'B', 'C', 'D'];

    function questionOptionValue(question, tag) {
        return String(
            question[`option_${String(tag).toLowerCase()}`] || ''
        ).trim();
    }

    function correctOptionTag(question) {
        const storedAnswer = String(
            question.correct_option || ''
        ).trim();
        const matchingTag = QUESTION_OPTION_TAGS.find(
            (tag) => questionOptionValue(question, tag) === storedAnswer
        );

        if (matchingTag) {
            return matchingTag;
        }

        const legacyTag = storedAnswer.toUpperCase();
        return storedAnswer.length === 1
            && QUESTION_OPTION_TAGS.includes(legacyTag)
            ? legacyTag
            : '';
    }

    function correctAnswerText(question) {
        const storedAnswer = String(
            question.correct_option || ''
        ).trim();
        const matchingTag = QUESTION_OPTION_TAGS.find(
            (tag) => questionOptionValue(question, tag) === storedAnswer
        );

        if (matchingTag) {
            return storedAnswer;
        }

        const legacyTag = correctOptionTag(question);
        return legacyTag
            ? questionOptionValue(question, legacyTag) || storedAnswer
            : storedAnswer;
    }

    function populateSelect(select, records, options = {}) {
        const {
            placeholder = 'Not assigned',
            valueKey = 'id',
            label = (record) => record.name,
            selectedValue = ''
        } = options;

        select.innerHTML = [
            `<option value="">${escapeHtml(placeholder)}</option>`,
            ...records.map((record) => (
                `<option value="${escapeHtml(record[valueKey])}">`
                + `${escapeHtml(label(record))}</option>`
            ))
        ].join('');
        select.value = selectedValue === null || selectedValue === undefined
            ? ''
            : String(selectedValue);
    }

    function renderOverview() {
        const counts = state.summary?.counts || {};
        byId('count-subjects').textContent = counts.subjects || 0;
        byId('count-active-subjects').textContent =
            `${counts.active_subjects || 0} active`;
        byId('count-questions').textContent = counts.questions || 0;
        byId('count-active-questions').textContent =
            `${counts.active_questions || 0} active`;
        byId('count-users').textContent = counts.users || 0;
        byId('count-active-users').textContent =
            `${counts.active_users || 0} active`;
        byId('count-exam-information').textContent =
            counts.exam_information || 0;
        byId('count-current-exam-information').textContent =
            `${counts.current_exam_information || 0} current`;
    }

    const DEFAULT_SUBJECT_CATEGORIES = Object.freeze([
        'General Insurance',
        'Life Insurance',
        'Common (Life & Non-Life)',
        'Regulation and Compliance'
    ]);

    function populateSubjectCategoryOptions() {
        const categories = new Set(DEFAULT_SUBJECT_CATEGORIES);
        state.subjects.forEach((subject) => {
            const category = String(subject.category || '').trim();
            if (category) {
                categories.add(category);
            }
        });
        byId('subject-category-options').innerHTML = [...categories]
            .sort((left, right) => left.localeCompare(right))
            .map((category) =>
                `<option value="${escapeHtml(category)}"></option>`
            )
            .join('');
    }

    function populateReferenceSelects() {
        const summary = state.summary || {};
        const qualificationLevels = summary.qualification_levels || [];
        const programmes = summary.training_programmes || [];
        const sections = summary.programme_sections || [];
        const authorities = summary.exam_authorities || [];

        populateSubjectCategoryOptions();

        populateSelect(
            byId('subject-qualification'),
            qualificationLevels
        );
        populateSelect(byId('subject-programme'), programmes);
        populateSelect(byId('subject-section'), sections);
        populateSelect(
            byId('exam-authority'),
            authorities,
            { placeholder: 'Select authority' }
        );
        populateSelect(byId('exam-programme'), programmes);
        populateSelect(byId('exam-section'), sections);
        populateSelect(
            byId('exam-subject'),
            state.subjects,
            {
                placeholder: 'All subjects / not subject-specific',
                valueKey: 'subject_id',
                label: (subject) =>
                    `${subject.subject_code} — ${subject.subject_title}`
            }
        );
        populateSelect(
            byId('question-subject-filter'),
            state.subjects,
            {
                placeholder: 'Select subject',
                valueKey: 'subject_id',
                label: (subject) =>
                    `${subject.subject_code} — ${subject.subject_title}`
            }
        );
    }

    function renderSubjects() {
        const table = byId('subjects-table');

        if (!state.subjects.length) {
            table.innerHTML = '<tr><td colspan="5" class="px-4 py-8 text-center text-slate-500">No subjects found.</td></tr>';
            return;
        }

        table.innerHTML = state.subjects.map((subject) => `
            <tr class="border-b align-top">
                <td class="px-4 py-4">
                    <p class="font-bold text-blue-950">${escapeHtml(subject.subject_code)} — ${escapeHtml(subject.subject_title)}</p>
                    <p class="mt-1 text-xs text-slate-500">${escapeHtml(subject.qualification_level || subject.category || '')}</p>
                </td>
                <td class="px-4 py-4">${escapeHtml(subject.currency_code)} ${escapeHtml(subject.price)}</td>
                <td class="px-4 py-4">${escapeHtml(subject.active_question_count)}</td>
                <td class="px-4 py-4">
                    <span class="rounded-full px-2 py-1 text-xs font-bold ${subject.is_active ? 'bg-emerald-100 text-emerald-800' : 'bg-slate-200 text-slate-700'}">
                        ${subject.is_active ? 'Active' : 'Inactive'}
                    </span>
                </td>
                <td class="px-4 py-4">
                    <button type="button" data-edit-subject="${subject.subject_id}" class="font-bold text-blue-700 hover:text-blue-900">Edit</button>
                </td>
            </tr>
        `).join('');
    }

    function resetSubjectForm() {
        byId('subject-form').reset();
        byId('subject-id').value = '';
        byId('subject-display-order').value = '1';
        byId('subject-demo-limit').value = '10';
        byId('subject-price').value = '0';
        byId('subject-currency').value = 'INR';
        byId('subject-form-title').textContent = 'New Subject';
        populateReferenceSelects();
    }

    function editSubject(subjectId) {
        const subject = state.subjects.find(
            (item) => String(item.subject_id) === String(subjectId)
        );
        if (!subject) {
            return;
        }

        byId('subject-id').value = subject.subject_id;
        byId('subject-code').value = subject.subject_code || '';
        byId('subject-title').value = subject.subject_title || '';
        byId('subject-description').value =
            subject.subject_description || '';
        byId('subject-qualification').value =
            subject.qualification_level_id || '';
        byId('subject-programme').value =
            subject.training_programme_id || '';
        byId('subject-section').value =
            subject.programme_section_id || '';
        byId('subject-category').value = subject.category || '';
        byId('subject-syllabus').value =
            subject.syllabus_version || '';
        byId('subject-display-order').value =
            subject.display_order || 1;
        byId('subject-demo-limit').value =
            subject.demo_question_limit ?? 10;
        byId('subject-price').value = subject.price ?? 0;
        byId('subject-currency').value =
            subject.currency_code || 'INR';
        byId('subject-demo-available').checked =
            Boolean(subject.is_demo_available);
        byId('subject-active').checked = Boolean(subject.is_active);
        byId('subject-form-title').textContent =
            `Edit ${subject.subject_code}`;
        byId('subject-form').scrollIntoView({
            behavior: 'smooth',
            block: 'start'
        });
    }

    async function saveSubject(event) {
        event.preventDefault();
        clearMessage();
        const button = byId('save-subject-button');
        const payload = {
            id: optionalNumber(byId('subject-id').value),
            code: byId('subject-code').value,
            title: byId('subject-title').value,
            description: byId('subject-description').value,
            qualification_level_id:
                optionalNumber(byId('subject-qualification').value),
            training_programme_id:
                optionalNumber(byId('subject-programme').value),
            programme_section_id:
                optionalNumber(byId('subject-section').value),
            category: byId('subject-category').value,
            syllabus_version: byId('subject-syllabus').value,
            display_order: Number(byId('subject-display-order').value),
            demo_question_limit:
                Number(byId('subject-demo-limit').value),
            price: Number(byId('subject-price').value),
            currency_code: byId('subject-currency').value,
            is_demo_available: byId('subject-demo-available').checked,
            is_active: byId('subject-active').checked
        };

        setBusy(button, true, 'Saving subject…');
        try {
            const { error } = await client.rpc('admin_save_subject', {
                p_subject: payload
            });
            if (error) {
                throw error;
            }
            await refreshCoreData();
            resetSubjectForm();
            showMessage('Subject saved and recorded in the audit history.', 'success');
        } catch (error) {
            console.error('Unable to save subject:', error);
            showMessage(error.message || 'Unable to save the subject.');
        } finally {
            setBusy(button, false, '');
        }
    }

    function renderQuestions() {
        const table = byId('questions-table');

        if (!state.questions.length) {
            table.innerHTML = '<tr><td colspan="5" class="px-4 py-8 text-center text-slate-500">Select a subject or add its first question.</td></tr>';
            return;
        }

        table.innerHTML = state.questions.map((question) => `
            <tr class="border-b align-top">
                <td class="max-w-md px-4 py-4">
                    <p class="font-semibold text-slate-900">${escapeHtml(question.question_text)}</p>
                    <p class="mt-1 text-xs text-slate-500">Order ${escapeHtml(question.display_order)}</p>
                </td>
                <td class="px-4 py-4">${escapeHtml(difficultyLabel(question.difficulty_level))}</td>
                <td class="px-4 py-4 font-bold">${escapeHtml(correctAnswerText(question))}</td>
                <td class="px-4 py-4">${question.is_active ? 'Active' : 'Inactive'}</td>
                <td class="px-4 py-4">
                    <button type="button" data-edit-question="${question.question_id}" class="font-bold text-blue-700 hover:text-blue-900">Edit</button>
                </td>
            </tr>
        `).join('');
    }

    function resetQuestionForm() {
        byId('question-form').reset();
        byId('question-id').value = '';
        byId('question-correct-option').value = 'A';
        byId('question-difficulty').value = 'easy';
        byId('question-marks').value = '1';
        byId('question-negative-marks').value = '0';
        byId('question-display-order').value = '1';
        byId('question-active').checked = true;
        byId('question-form-title').textContent = 'New Question';
    }

    function editQuestion(questionId) {
        const question = state.questions.find(
            (item) => String(item.question_id) === String(questionId)
        );
        if (!question) {
            return;
        }

        byId('question-id').value = question.question_id;
        byId('question-text').value = question.question_text || '';
        byId('question-option-a').value = question.option_a || '';
        byId('question-option-b').value = question.option_b || '';
        byId('question-option-c').value = question.option_c || '';
        byId('question-option-d').value = question.option_d || '';
        byId('question-correct-option').value =
            correctOptionTag(question);
        byId('question-difficulty').value =
            difficultyInput(question.difficulty_level);
        byId('question-explanation').value =
            question.explanation || '';
        byId('question-marks').value = question.marks ?? 1;
        byId('question-negative-marks').value =
            question.negative_marks ?? 0;
        byId('question-display-order').value =
            question.display_order || 1;
        byId('question-active').checked = Boolean(question.is_active);
        byId('question-form-title').textContent =
            `Edit Question ${question.question_id}`;
        byId('question-form').scrollIntoView({
            behavior: 'smooth',
            block: 'start'
        });
    }

    async function loadQuestions() {
        const subjectId = optionalNumber(
            byId('question-subject-filter').value
        );
        resetQuestionForm();

        if (!subjectId) {
            state.questions = [];
            renderQuestions();
            return;
        }

        const { data, error } = await client.rpc('admin_list_questions', {
            p_subject_id: subjectId
        });
        if (error) {
            throw error;
        }
        state.questions = data || [];
        renderQuestions();
    }

    async function saveQuestion(event) {
        event.preventDefault();
        clearMessage();
        const button = byId('save-question-button');
        const subjectId = optionalNumber(
            byId('question-subject-filter').value
        );
        if (!subjectId) {
            showMessage('Select the subject before saving a question.');
            return;
        }

        const payload = {
            id: optionalNumber(byId('question-id').value),
            subject_id: subjectId,
            question_text: byId('question-text').value,
            option_a: byId('question-option-a').value,
            option_b: byId('question-option-b').value,
            option_c: byId('question-option-c').value,
            option_d: byId('question-option-d').value,
            correct_option: byId('question-correct-option').value,
            explanation: byId('question-explanation').value,
            difficulty_level: byId('question-difficulty').value,
            marks: Number(byId('question-marks').value),
            negative_marks:
                Number(byId('question-negative-marks').value),
            display_order:
                Number(byId('question-display-order').value),
            is_active: byId('question-active').checked
        };

        setBusy(button, true, 'Saving question…');
        try {
            const { error } = await client.rpc('admin_save_question', {
                p_question: payload
            });
            if (error) {
                throw error;
            }
            await Promise.all([loadQuestions(), refreshSummary()]);
            resetQuestionForm();
            showMessage('Question saved and recorded in the audit history.', 'success');
        } catch (error) {
            console.error('Unable to save question:', error);
            showMessage(error.message || 'Unable to save the question.');
        } finally {
            setBusy(button, false, '');
        }
    }

    function renderUsers() {
        const table = byId('users-table');
        table.innerHTML = state.users.map((user) => {
            const isAdmin = user.role === 'admin';
            const isSafetyManaged = ['suspended', 'closed'].includes(
                user.status
            );
            const statusLocked = isAdmin || isSafetyManaged;
            return `
                <tr class="border-b align-top">
                    <td class="px-4 py-4">
                        <p class="font-bold text-blue-950">${escapeHtml([user.first_name, user.last_name].filter(Boolean).join(' ') || 'Unnamed user')}</p>
                        <p class="mt-1 text-xs text-slate-500">${escapeHtml(user.email)}</p>
                    </td>
                    <td class="px-4 py-4">${escapeHtml(user.mobile || '—')}</td>
                    <td class="px-4 py-4">${user.email_verified_at ? 'Yes' : 'No'}</td>
                    <td class="px-4 py-4 font-semibold">${escapeHtml(user.role)}</td>
                    <td class="px-4 py-4">
                        <div class="flex min-w-56 gap-2">
                            <select data-user-status="${escapeHtml(user.user_id)}" class="rounded-lg border p-2" ${statusLocked ? 'disabled' : ''}>
                                <option value="active" ${user.status === 'active' ? 'selected' : ''}>Active</option>
                                <option value="verification_pending" ${user.status === 'verification_pending' ? 'selected' : ''}>Verification pending</option>
                                ${isSafetyManaged
                                    ? `<option value="${escapeHtml(user.status)}" selected>${escapeHtml(securityEventLabel(user.status))} — manage in Security & Alerts</option>`
                                    : ''}
                            </select>
                            <button type="button" data-save-user-status="${escapeHtml(user.user_id)}" class="rounded-lg bg-blue-800 px-3 py-2 font-bold text-white disabled:opacity-50" ${statusLocked ? 'disabled' : ''}>Save</button>
                        </div>
                    </td>
                </tr>
            `;
        }).join('');
    }

    async function loadUsers() {
        const { data, error } = await client.rpc('admin_list_users');
        if (error) {
            throw error;
        }
        state.users = data || [];
        renderUsers();
    }

    async function saveUserStatus(userId, button) {
        const select = document.querySelector(
            `[data-user-status="${CSS.escape(String(userId))}"]`
        );
        if (!select) {
            return;
        }

        setBusy(button, true, 'Saving…');
        try {
            const { error } = await client.rpc('admin_set_user_status', {
                p_user_id: userId,
                p_status: select.value
            });
            if (error) {
                throw error;
            }
            await Promise.all([loadUsers(), refreshSummary()]);
            showMessage('User activation status saved.', 'success');
        } catch (error) {
            console.error('Unable to save user status:', error);
            showMessage(error.message || 'Unable to save user status.');
        } finally {
            setBusy(button, false, '');
        }
    }

    function renderExamInformation() {
        const table = byId('exam-information-table');
        if (!state.examInformation.length) {
            table.innerHTML = '<tr><td colspan="5" class="px-4 py-8 text-center text-slate-500">No examination information found.</td></tr>';
            return;
        }

        table.innerHTML = state.examInformation.map((information) => `
            <tr class="border-b align-top">
                <td class="max-w-sm px-4 py-4">
                    <p class="font-bold text-blue-950">${escapeHtml(information.title)}</p>
                    <p class="mt-1 text-xs text-slate-500">${escapeHtml(information.authority_code)} · ${escapeHtml(information.document_type)}</p>
                </td>
                <td class="px-4 py-4">${escapeHtml(information.session_code || '—')}</td>
                <td class="px-4 py-4">${escapeHtml(information.valid_until || '—')}</td>
                <td class="px-4 py-4">${information.is_active ? 'Active' : 'Retired'}</td>
                <td class="px-4 py-4">
                    <div class="flex gap-3">
                        <button type="button" data-edit-exam-information="${information.information_id}" class="font-bold text-blue-700">Edit</button>
                        ${information.is_active ? `<button type="button" data-retire-exam-information="${information.information_id}" class="font-bold text-red-700">Retire</button>` : ''}
                    </div>
                </td>
            </tr>
        `).join('');
    }

    function todayIso() {
        return new Date().toISOString().slice(0, 10);
    }

    function resetExamInformationForm() {
        byId('exam-information-form').reset();
        byId('exam-information-id').value = '';
        byId('exam-geographic-scope').value = 'all';
        byId('exam-content-usage').value = 'metadata_only';
        byId('exam-verification-status').value =
            'official_url_verified';
        byId('exam-verified-on').value = todayIso();
        byId('exam-active').checked = true;
        byId('exam-information-form-title').textContent =
            'New Information';
        populateReferenceSelects();
    }

    function editExamInformation(informationId) {
        const information = state.examInformation.find(
            (item) =>
                String(item.information_id) === String(informationId)
        );
        if (!information) {
            return;
        }

        byId('exam-information-id').value = information.information_id;
        byId('exam-source-document-id').value =
            information.source_document_id || '';
        byId('exam-title').value = information.title || '';
        byId('exam-authority').value =
            information.exam_authority_id || '';
        byId('exam-document-type').value =
            information.document_type || 'schedule';
        byId('exam-subject').value = information.subject_id || '';
        byId('exam-programme').value =
            information.training_programme_id || '';
        byId('exam-section').value =
            information.programme_section_id || '';
        byId('exam-session-code').value =
            information.session_code || '';
        byId('exam-geographic-scope').value =
            information.geographic_scope || 'all';
        byId('exam-verification-status').value =
            information.verification_status || 'official_url_verified';
        byId('exam-official-url').value =
            information.official_url || '';
        byId('exam-discovery-url').value =
            information.discovery_url || '';
        byId('exam-published-on').value =
            information.published_on || '';
        byId('exam-effective-from').value =
            information.effective_from || '';
        byId('exam-valid-until').value =
            information.valid_until || '';
        byId('exam-verified-on').value =
            information.verified_on || todayIso();
        byId('exam-content-usage').value =
            information.content_usage || 'metadata_only';
        byId('exam-active').checked = Boolean(information.is_active);
        byId('exam-information-form-title').textContent =
            `Edit Information ${information.information_id}`;
        byId('exam-information-form').scrollIntoView({
            behavior: 'smooth',
            block: 'start'
        });
    }

    async function loadExamInformation() {
        const { data, error } =
            await client.rpc('admin_list_exam_information');
        if (error) {
            throw error;
        }
        state.examInformation = data || [];
        renderExamInformation();
    }

    async function saveExamInformation(event) {
        event.preventDefault();
        clearMessage();
        const button = byId('save-exam-information-button');
        const payload = {
            id: optionalNumber(byId('exam-information-id').value),
            source_document_id: byId('exam-source-document-id').value,
            title: byId('exam-title').value,
            exam_authority_id:
                optionalNumber(byId('exam-authority').value),
            document_type: byId('exam-document-type').value,
            subject_id: optionalNumber(byId('exam-subject').value),
            training_programme_id:
                optionalNumber(byId('exam-programme').value),
            programme_section_id:
                optionalNumber(byId('exam-section').value),
            session_code: byId('exam-session-code').value,
            geographic_scope: byId('exam-geographic-scope').value,
            verification_status:
                byId('exam-verification-status').value,
            official_url: byId('exam-official-url').value,
            discovery_url: byId('exam-discovery-url').value,
            published_on: byId('exam-published-on').value,
            effective_from: byId('exam-effective-from').value,
            valid_until: byId('exam-valid-until').value,
            verified_on: byId('exam-verified-on').value,
            content_usage: byId('exam-content-usage').value,
            is_active: byId('exam-active').checked
        };

        setBusy(button, true, 'Saving information…');
        try {
            const { error } = await client.rpc(
                'admin_save_exam_information',
                { p_information: payload }
            );
            if (error) {
                throw error;
            }
            await Promise.all([loadExamInformation(), refreshSummary()]);
            resetExamInformationForm();
            showMessage('Examination information saved and audited.', 'success');
        } catch (error) {
            console.error('Unable to save exam information:', error);
            showMessage(
                error.message || 'Unable to save examination information.'
            );
        } finally {
            setBusy(button, false, '');
        }
    }

    async function retireExamInformation(informationId) {
        if (!global.confirm(
            'Retire this information? It will stop appearing to learners but remain in the audit history.'
        )) {
            return;
        }

        try {
            const { error } = await client.rpc(
                'admin_retire_exam_information',
                { p_information_id: Number(informationId) }
            );
            if (error) {
                throw error;
            }
            await Promise.all([loadExamInformation(), refreshSummary()]);
            showMessage('Examination information retired.', 'success');
        } catch (error) {
            console.error('Unable to retire exam information:', error);
            showMessage(
                error.message || 'Unable to retire examination information.'
            );
        }
    }

    function renderAuditEvents() {
        const table = byId('audit-table');
        if (!state.auditEvents.length) {
            table.innerHTML = '<tr><td colspan="5" class="px-4 py-8 text-center text-slate-500">No administrator changes have been recorded yet.</td></tr>';
            return;
        }

        table.innerHTML = state.auditEvents.map((event) => `
            <tr class="border-b align-top">
                <td class="px-4 py-4">${escapeHtml(new Date(event.created_at).toLocaleString())}</td>
                <td class="px-4 py-4">${escapeHtml(event.actor_email)}</td>
                <td class="px-4 py-4 font-semibold">${escapeHtml(event.action)}</td>
                <td class="px-4 py-4">${escapeHtml(event.entity_type)} #${escapeHtml(event.entity_key)}</td>
                <td class="max-w-md px-4 py-4 text-xs text-slate-600">${escapeHtml(JSON.stringify(event.change_summary || {}))}</td>
            </tr>
        `).join('');
    }

    async function loadAuditEvents() {
        const { data, error } = await client.rpc(
            'admin_list_audit_events',
            { p_limit: 100 }
        );
        if (error) {
            throw error;
        }
        state.auditEvents = data || [];
        renderAuditEvents();
    }

    function finishAdminActionDialog(confirmed) {
        const dialog = byId('admin-action-dialog');
        const input = byId('admin-action-dialog-input');
        const resolve = adminActionDialogState.resolve;

        dialog.classList.add('hidden');
        dialog.classList.remove('flex');
        adminActionDialogState.resolve = null;

        if (adminActionDialogState.returnFocus?.isConnected) {
            adminActionDialogState.returnFocus.focus();
        }
        adminActionDialogState.returnFocus = null;

        if (resolve) {
            resolve({
                confirmed,
                value: confirmed ? input.value.trim() : ''
            });
        }
    }

    function requestAdminAction(options) {
        const settings = options || {};
        const dialog = byId('admin-action-dialog');
        const input = byId('admin-action-dialog-input');
        const confirmButton = byId('admin-action-dialog-confirm');

        if (adminActionDialogState.resolve) {
            finishAdminActionDialog(false);
        }

        byId('admin-action-dialog-title').textContent = settings.title || '';
        byId('admin-action-dialog-description').textContent =
            settings.description || '';
        byId('admin-action-dialog-label').textContent =
            settings.inputLabel || 'Administrator note';
        byId('admin-action-dialog-guidance').textContent =
            settings.guidance || '';
        input.value = settings.value || '';
        input.required = settings.required !== false;
        confirmButton.textContent = settings.confirmLabel || 'Confirm';
        confirmButton.className = settings.danger
            ? 'rounded-xl bg-red-700 px-5 py-3 font-bold text-white hover:bg-red-800'
            : 'rounded-xl bg-blue-700 px-5 py-3 font-bold text-white hover:bg-blue-800';
        adminActionDialogState.returnFocus = document.activeElement;

        return new Promise((resolve) => {
            adminActionDialogState.resolve = resolve;
            dialog.classList.remove('hidden');
            dialog.classList.add('flex');
            global.setTimeout(() => input.focus(), 0);
        });
    }

    function securitySeverityClass(severity) {
        return {
            critical: 'bg-red-100 text-red-800',
            high: 'bg-orange-100 text-orange-800',
            medium: 'bg-amber-100 text-amber-800',
            low: 'bg-blue-100 text-blue-800',
            info: 'bg-slate-200 text-slate-700'
        }[severity] || 'bg-slate-200 text-slate-700';
    }

    function securityEventLabel(eventType) {
        return String(eventType || '')
            .split('_')
            .filter(Boolean)
            .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
            .join(' ');
    }

    function renderSecuritySummary() {
        const summary = state.securitySummary || {};
        byId('security-open-events').textContent =
            summary.open_events || 0;
        byId('security-critical-events').textContent =
            summary.critical_events || 0;
        byId('security-active-cases').textContent =
            summary.active_cases || 0;
        byId('security-suspended-users').textContent =
            summary.suspended_users || 0;
        byId('security-long-sessions').textContent =
            summary.sessions_over_48_hours || 0;
        byId('security-pending-emails').textContent =
            summary.pending_email_notifications || 0;
    }

    function renderSecurityEvents() {
        const table = byId('security-events-table');
        if (!state.securityEvents.length) {
            table.innerHTML = '<tr><td colspan="7" class="px-4 py-8 text-center text-slate-500">No safety alerts have been recorded.</td></tr>';
            return;
        }

        table.innerHTML = state.securityEvents.map((event) => {
            const learner = event.user_email
                ? `${escapeHtml(event.user_name || 'Learner')}<br><span class="text-xs text-slate-500">${escapeHtml(event.user_email)}</span>`
                : '<span class="text-slate-500">Platform event</span>';
            const canOpenCase = Boolean(event.user_id)
                && event.severity !== 'info'
                && event.event_type !== 'registration_confirmed'
                && ['open', 'under_review'].includes(event.status);
            const canDismiss = ['open', 'under_review'].includes(
                event.status
            );

            return `
                <tr class="border-b align-top">
                    <td class="px-4 py-4">
                        <span class="rounded-full px-2 py-1 text-xs font-bold ${securitySeverityClass(event.severity)}">
                            ${escapeHtml(event.severity)}
                        </span>
                    </td>
                    <td class="px-4 py-4">
                        <p class="font-bold text-blue-950">${escapeHtml(securityEventLabel(event.event_type))}</p>
                        <p class="mt-1 text-xs text-slate-500">${escapeHtml(event.source)}</p>
                    </td>
                    <td class="px-4 py-4">${learner}</td>
                    <td class="px-4 py-4">
                        ${escapeHtml(new Date(event.occurred_at).toLocaleString())}
                        ${event.occurrence_count > 1
                            ? `<p class="mt-1 text-xs text-slate-500">Seen ${escapeHtml(event.occurrence_count)} times</p>`
                            : ''}
                    </td>
                    <td class="max-w-sm px-4 py-4 text-slate-600">${escapeHtml(event.recommended_action || 'Review the evidence before taking action.')}</td>
                    <td class="px-4 py-4 font-semibold">${escapeHtml(event.status)}</td>
                    <td class="px-4 py-4">
                        <div class="flex min-w-36 flex-col gap-2">
                            ${canOpenCase
                                ? `<button type="button" data-open-security-case="${event.event_id}" class="rounded-lg bg-amber-600 px-3 py-2 font-bold text-white">Open Case</button>`
                                : ''}
                            ${canDismiss
                                ? `<button type="button" data-dismiss-security-event="${event.event_id}" class="rounded-lg border border-slate-400 px-3 py-2 font-bold text-slate-700">Dismiss</button>`
                                : '<span class="text-xs text-slate-500">Reviewed</span>'}
                        </div>
                    </td>
                </tr>
            `;
        }).join('');
    }

    function renderEnforcementCases() {
        const table = byId('enforcement-cases-table');
        if (!state.enforcementCases.length) {
            table.innerHTML = '<tr><td colspan="6" class="px-4 py-8 text-center text-slate-500">No learner enforcement cases are open.</td></tr>';
            return;
        }

        table.innerHTML = state.enforcementCases.map((item) => {
            const warningAllowed = ['monitoring', 'warned'].includes(
                item.status
            ) && item.warning_count < 3;
            const suspensionAllowed = ['monitoring', 'warned'].includes(
                item.status
            );
            const restoreAllowed = item.status === 'suspended';

            return `
                <tr class="border-b align-top">
                    <td class="px-4 py-4">
                        <p class="font-bold text-blue-950">${escapeHtml(item.user_name || 'Learner')}</p>
                        <p class="mt-1 text-xs text-slate-500">${escapeHtml(item.user_email)}</p>
                    </td>
                    <td class="max-w-sm px-4 py-4">
                        <p class="font-semibold">${escapeHtml(securityEventLabel(item.reason_code))}</p>
                        <p class="mt-1 text-xs text-slate-600">${escapeHtml(item.reason_summary)}</p>
                        ${item.source_severity === 'critical'
                            ? '<p class="mt-1 text-xs font-bold text-red-700">Critical-event override available</p>'
                            : ''}
                    </td>
                    <td class="px-4 py-4 font-bold">${escapeHtml(item.warning_count)} / 3</td>
                    <td class="px-4 py-4 font-semibold">${escapeHtml(item.status)}</td>
                    <td class="px-4 py-4">${escapeHtml(new Date(item.updated_at).toLocaleString())}</td>
                    <td class="px-4 py-4">
                        <div class="flex min-w-40 flex-col gap-2">
                            ${warningAllowed
                                ? `<button type="button" data-warn-enforcement-case="${item.case_id}" class="rounded-lg bg-amber-600 px-3 py-2 font-bold text-white">Issue Warning</button>`
                                : ''}
                            ${suspensionAllowed
                                ? `<button type="button" data-suspend-enforcement-case="${item.case_id}" class="rounded-lg bg-red-700 px-3 py-2 font-bold text-white">Suspend Access</button>`
                                : ''}
                            ${restoreAllowed
                                ? `<button type="button" data-restore-enforcement-case="${item.case_id}" class="rounded-lg bg-emerald-700 px-3 py-2 font-bold text-white">Restore Access</button>`
                                : ''}
                            ${!warningAllowed && !suspensionAllowed && !restoreAllowed
                                ? '<span class="text-xs text-slate-500">No action available</span>'
                                : ''}
                        </div>
                    </td>
                </tr>
            `;
        }).join('');
    }

    function renderNotificationOutbox() {
        const table = byId('notification-outbox-table');
        if (!state.notificationOutbox.length) {
            table.innerHTML = '<tr><td colspan="6" class="px-4 py-8 text-center text-slate-500">No safety notifications have been queued.</td></tr>';
            return;
        }

        table.innerHTML = state.notificationOutbox.map((item) => `
            <tr class="border-b align-top">
                <td class="px-4 py-4">${escapeHtml(new Date(item.created_at).toLocaleString())}</td>
                <td class="px-4 py-4">${escapeHtml(securityEventLabel(item.notification_type))}</td>
                <td class="px-4 py-4">${escapeHtml(item.channel)}</td>
                <td class="px-4 py-4">${escapeHtml(item.recipient_kind)}</td>
                <td class="max-w-sm px-4 py-4">${escapeHtml(item.subject)}</td>
                <td class="px-4 py-4 font-semibold">${escapeHtml(item.status)}</td>
            </tr>
        `).join('');
    }

    async function loadSecurityData() {
        const [
            { data: summary, error: summaryError },
            { data: events, error: eventsError },
            { data: cases, error: casesError },
            { data: outbox, error: outboxError }
        ] = await Promise.all([
            client.rpc('get_admin_security_summary'),
            client.rpc('admin_list_security_events', { p_limit: 100 }),
            client.rpc('admin_list_enforcement_cases', { p_limit: 100 }),
            client.rpc('admin_list_notification_outbox', { p_limit: 100 })
        ]);

        const error = summaryError || eventsError || casesError
            || outboxError;
        if (error) {
            throw error;
        }

        state.securitySummary = summary || {};
        state.securityEvents = events || [];
        state.enforcementCases = cases || [];
        state.notificationOutbox = outbox || [];
        renderSecuritySummary();
        renderSecurityEvents();
        renderEnforcementCases();
        renderNotificationOutbox();
    }

    async function scanLongRunningSessions(button) {
        clearMessage();
        setBusy(button, true, 'Checking sessions\u2026');
        try {
            const { data, error } = await client.rpc(
                'fn_scan_long_running_sessions'
            );
            if (error) {
                throw error;
            }
            await Promise.all([loadSecurityData(), loadAuditEvents()]);
            showMessage(
                `${Number(data) || 0} continuously active session(s) crossed the 48-hour review threshold.`,
                'success'
            );
        } catch (error) {
            console.error('Unable to scan long-running sessions:', error);
            showMessage(
                error.message || 'Unable to check long-running sessions.'
            );
        } finally {
            setBusy(button, false, '');
        }
    }

    async function reviewSecurityEvent(eventId, decision) {
        const actionLabel = decision === 'open_case'
            ? 'open a controlled learner case'
            : 'dismiss this alert';
        const action = await requestAdminAction({
            title: decision === 'open_case'
                ? 'Open controlled learner case'
                : 'Dismiss safety alert',
            description:
                `Confirm that you want to ${actionLabel}. The decision will be audited.`,
            inputLabel: 'Review note',
            guidance:
                'Keep the note concise. Do not include passwords, OTPs, tokens, full IP addresses, or quiz answers.',
            confirmLabel: decision === 'open_case' ? 'Open Case' : 'Dismiss Alert',
            danger: decision === 'dismiss'
        });
        if (!action.confirmed) {
            return;
        }

        try {
            const { error } = await client.rpc(
                'admin_review_security_event',
                {
                    p_event_id: Number(eventId),
                    p_decision: decision,
                    p_note: action.value
                }
            );
            if (error) {
                throw error;
            }
            await Promise.all([loadSecurityData(), loadAuditEvents()]);
            showMessage('The security review decision was saved.', 'success');
        } catch (error) {
            console.error('Unable to review security event:', error);
            showMessage(error.message || 'Unable to save the review decision.');
        }
    }

    async function issueSecurityWarning(caseId) {
        const action = await requestAdminAction({
            title: 'Issue learner warning',
            description:
                'This audited warning will appear in the learner account. A maximum of three confirmed warnings is allowed.',
            inputLabel: 'Warning message',
            guidance:
                'Explain the concern and the expected corrective action without including protected data.',
            confirmLabel: 'Issue Warning'
        });
        if (!action.confirmed) {
            return;
        }

        try {
            const { data, error } = await client.rpc(
                'admin_issue_security_warning',
                {
                    p_case_id: Number(caseId),
                    p_message: action.value
                }
            );
            if (error) {
                throw error;
            }
            await Promise.all([loadSecurityData(), loadAuditEvents()]);
            showMessage(`Warning ${Number(data)} of 3 was issued.`, 'success');
        } catch (error) {
            console.error('Unable to issue security warning:', error);
            showMessage(error.message || 'Unable to issue the warning.');
        }
    }

    async function suspendEnforcementCase(caseId) {
        const action = await requestAdminAction({
            title: 'Suspend learner access',
            description:
                'Ordinary cases require three confirmed warnings. If approved, protected access stops and the active learner page is displaced.',
            inputLabel: 'Suspension reason',
            guidance:
                'This reason is recorded in the audit history and queued for delivery to the learner.',
            confirmLabel: 'Suspend Access',
            danger: true
        });
        if (!action.confirmed) {
            return;
        }

        try {
            const { error } = await client.rpc(
                'admin_suspend_user_access',
                {
                    p_case_id: Number(caseId),
                    p_reason: action.value,
                    p_suspended_until: null
                }
            );
            if (error) {
                throw error;
            }
            await Promise.all([
                loadSecurityData(),
                loadAuditEvents(),
                loadUsers()
            ]);
            showMessage('Learner access was suspended and audited.', 'success');
        } catch (error) {
            console.error('Unable to suspend learner access:', error);
            showMessage(error.message || 'Unable to suspend learner access.');
        }
    }

    async function restoreEnforcementCase(caseId) {
        const action = await requestAdminAction({
            title: 'Restore learner access',
            description:
                'Restoring access permits the learner to sign in and use entitled learning and practice services again.',
            inputLabel: 'Restoration reason',
            guidance: 'The restoration decision and reason will be audited.',
            confirmLabel: 'Restore Access'
        });
        if (!action.confirmed) {
            return;
        }

        try {
            const { error } = await client.rpc(
                'admin_restore_user_access',
                {
                    p_case_id: Number(caseId),
                    p_note: action.value
                }
            );
            if (error) {
                throw error;
            }
            await Promise.all([
                loadSecurityData(),
                loadAuditEvents(),
                loadUsers()
            ]);
            showMessage('Learner access was restored and audited.', 'success');
        } catch (error) {
            console.error('Unable to restore learner access:', error);
            showMessage(error.message || 'Unable to restore learner access.');
        }
    }

    function syncBulkTemplateLink() {
        const entity = byId('bulk-upload-entity').value;
        const format = bulkUploadService.FORMATS[entity];
        if (!format) {
            return;
        }
        const link = byId('download-selected-template');
        link.href = `admin-upload-templates/${format.fileName}`;
        link.download = format.fileName;
        byId('selected-template-description').textContent =
            `${format.label} · ${format.fileName}`;
    }

    function resetBulkUpload() {
        syncBulkTemplateLink();
        state.bulkUpload = null;
        byId('bulk-upload-file').value = '';
        byId('bulk-upload-summary').textContent =
            'Select the matching upload type and CSV file to begin.';
        byId('bulk-upload-errors').className =
            'mt-4 hidden rounded-xl bg-red-100 p-4 text-sm text-red-800';
        byId('bulk-upload-errors').textContent = '';
        byId('bulk-upload-preview-head').innerHTML = '';
        byId('bulk-upload-preview-body').innerHTML =
            '<tr><td class="px-4 py-8 text-center text-slate-500">No CSV preview loaded.</td></tr>';
        const importButton = byId('run-bulk-upload-button');
        if (importButton.dataset.defaultText) {
            importButton.textContent = importButton.dataset.defaultText;
        }
        importButton.disabled = true;
        importButton.classList.add('opacity-60');
    }

    function renderBulkUploadPreview(fileName, result) {
        const errorBox = byId('bulk-upload-errors');
        const importButton = byId('run-bulk-upload-button');
        byId('bulk-upload-summary').textContent =
            `${fileName}: ${result.rows.length} data row(s) checked.`;

        if (result.errors.length > 0) {
            errorBox.className =
                'mt-4 rounded-xl bg-red-100 p-4 text-sm text-red-800';
            errorBox.innerHTML = [
                '<p class="font-bold">Correct these items before importing:</p>',
                '<ul class="mt-2 list-disc space-y-1 pl-5">',
                ...result.errors.slice(0, 25).map((error) => (
                    `<li>CSV row ${escapeHtml(error.row)}: `
                    + `${escapeHtml(error.message)}</li>`
                )),
                result.errors.length > 25
                    ? `<li>${escapeHtml(result.errors.length - 25)} additional issue(s) are not shown.</li>`
                    : '',
                '</ul>'
            ].join('');
        } else {
            errorBox.className =
                'mt-4 rounded-xl bg-emerald-100 p-4 text-sm text-emerald-800';
            errorBox.innerHTML =
                '<span class="font-bold">Ready to import.</span> All browser checks passed. The database will validate every row again.';
        }

        byId('bulk-upload-preview-head').innerHTML = `
            <tr>${result.headers.map(
                (header) => `<th class="whitespace-nowrap px-3 py-3">${escapeHtml(header)}</th>`
            ).join('')}</tr>
        `;
        byId('bulk-upload-preview-body').innerHTML =
            result.rows.length > 0
                ? result.rows.slice(0, 5).map((row) => `
                    <tr class="border-t">${result.headers.map(
                        (header) => `<td class="max-w-72 truncate px-3 py-3">${escapeHtml(row[header])}</td>`
                    ).join('')}</tr>
                `).join('')
                : '<tr><td class="px-4 py-8 text-center text-slate-500">No valid data rows are available to preview.</td></tr>';

        importButton.disabled =
            result.errors.length > 0 || result.rows.length === 0;
        importButton.classList.toggle(
            'opacity-60',
            importButton.disabled
        );
    }

    async function reviewBulkUploadFile() {
        clearMessage();
        const fileInput = byId('bulk-upload-file');
        const file = fileInput.files[0];
        if (!file) {
            resetBulkUpload();
            return;
        }

        if (file.size > 5 * 1024 * 1024) {
            resetBulkUpload();
            showMessage(
                'The CSV is larger than 5 MB. Split it into smaller files containing no more than 250 rows.'
            );
            return;
        }

        try {
            const entity = byId('bulk-upload-entity').value;
            const result = bulkUploadService.validateCsv(
                entity,
                await file.text()
            );
            state.bulkUpload = {
                entity,
                fileName: file.name,
                result
            };
            renderBulkUploadPreview(file.name, result);
        } catch (error) {
            console.error('Unable to review bulk upload:', error);
            resetBulkUpload();
            showMessage(
                error.message || 'Unable to read the selected CSV file.'
            );
        }
    }

    async function runBulkUpload() {
        const upload = state.bulkUpload;
        if (!upload
            || upload.result.errors.length > 0
            || upload.result.rows.length === 0) {
            showMessage('Review a valid CSV file before importing.');
            return;
        }

        if (!global.confirm(
            `Import all ${upload.result.rows.length} reviewed `
            + `${upload.entity} row(s)? If one row fails, none will be saved.`
        )) {
            return;
        }

        const button = byId('run-bulk-upload-button');
        setBusy(button, true, 'Importing reviewed rows...');
        try {
            const { data, error } = await client.rpc(
                'admin_bulk_import',
                {
                    p_entity: upload.entity,
                    p_rows: upload.result.rows
                }
            );
            if (error) {
                throw error;
            }

            const processedCount =
                Number(data?.processed_count) || upload.result.rows.length;
            const entity = upload.entity;
            resetBulkUpload();
            await refreshCoreData();

            if (entity === 'users') {
                await loadUsers();
            } else if (entity === 'exam_information') {
                await loadExamInformation();
            } else if (
                entity === 'questions'
                && byId('question-subject-filter').value
            ) {
                await loadQuestions();
            }

            showMessage(
                `${processedCount} ${entity} row(s) imported and audited successfully.`,
                'success'
            );
        } catch (error) {
            console.error('Administrator bulk import failed:', error);
            if (await sessionControl.handleInactiveSessionError(error)) {
                return;
            }
            showMessage(
                error.message
                    || 'The CSV was not imported. No rows were saved.'
            );
        } finally {
            if (state.bulkUpload) {
                setBusy(button, false, '');
            }
        }
    }

    async function refreshSummary() {
        const { data, error } =
            await client.rpc('get_admin_portal_summary');
        if (error) {
            throw error;
        }
        state.summary = data || {};
        renderOverview();
    }

    async function refreshCoreData() {
        const [
            { data: summary, error: summaryError },
            { data: subjects, error: subjectsError }
        ] = await Promise.all([
            client.rpc('get_admin_portal_summary'),
            client.rpc('admin_list_subjects')
        ]);

        if (summaryError) {
            throw summaryError;
        }
        if (subjectsError) {
            throw subjectsError;
        }

        state.summary = summary || {};
        state.subjects = subjects || [];
        renderOverview();
        renderSubjects();
        populateReferenceSelects();
    }

    async function showTab(tabName) {
        clearMessage();
        document.querySelectorAll('[data-admin-panel]').forEach((panel) => {
            panel.classList.toggle(
                'hidden',
                panel.id !== `panel-${tabName}`
            );
        });
        document.querySelectorAll('[data-admin-tab]').forEach((button) => {
            const active = button.dataset.adminTab === tabName;
            button.classList.toggle('bg-blue-800', active);
            button.classList.toggle('text-white', active);
            button.classList.toggle('text-slate-700', !active);
        });

        try {
            if (tabName === 'users') {
                await loadUsers();
            } else if (tabName === 'exam-information') {
                await loadExamInformation();
            } else if (tabName === 'security') {
                await loadSecurityData();
            } else if (tabName === 'audit') {
                await loadAuditEvents();
            }
        } catch (error) {
            console.error(`Unable to load ${tabName}:`, error);
            if (await sessionControl.handleInactiveSessionError(error)) {
                return;
            }
            showMessage(`Unable to load ${tabName.replace('-', ' ')}.`);
        }
    }

    async function logout() {
        const button = byId('logout-button');
        setBusy(button, true, 'Logging out…');
        const result = await sessionControl.logoutEverywhere(client);
        if (!result.success) {
            setBusy(button, false, '');
            showMessage('Unable to log out. Please try again.');
            return;
        }
        global.location.replace('index.html');
    }

    function installListeners() {
        byId('admin-action-dialog-form').addEventListener(
            'submit',
            (event) => {
                event.preventDefault();
                finishAdminActionDialog(true);
            }
        );
        byId('admin-action-dialog-cancel').addEventListener(
            'click',
            () => finishAdminActionDialog(false)
        );
        byId('admin-action-dialog').addEventListener(
            'click',
            (event) => {
                if (event.target === event.currentTarget) {
                    finishAdminActionDialog(false);
                }
            }
        );
        document.addEventListener('keydown', (event) => {
            if (
                event.key === 'Escape'
                && adminActionDialogState.resolve
            ) {
                finishAdminActionDialog(false);
            }
        });
        document.querySelectorAll('[data-admin-tab]').forEach((button) => {
            button.addEventListener(
                'click',
                () => void showTab(button.dataset.adminTab)
            );
        });
        byId('logout-button').addEventListener('click', () => void logout());
        byId('subject-form').addEventListener('submit', saveSubject);
        byId('new-subject-button').addEventListener(
            'click',
            resetSubjectForm
        );
        byId('cancel-subject-edit').addEventListener(
            'click',
            resetSubjectForm
        );
        byId('subjects-table').addEventListener('click', (event) => {
            const button = event.target.closest('[data-edit-subject]');
            if (button) {
                editSubject(button.dataset.editSubject);
            }
        });
        byId('question-subject-filter').addEventListener(
            'change',
            () => void loadQuestions().catch((error) => {
                console.error('Unable to load questions:', error);
                showMessage('Unable to load the selected question bank.');
            })
        );
        byId('question-form').addEventListener('submit', saveQuestion);
        byId('new-question-button').addEventListener(
            'click',
            resetQuestionForm
        );
        byId('cancel-question-edit').addEventListener(
            'click',
            resetQuestionForm
        );
        byId('questions-table').addEventListener('click', (event) => {
            const button = event.target.closest('[data-edit-question]');
            if (button) {
                editQuestion(button.dataset.editQuestion);
            }
        });
        byId('users-table').addEventListener('click', (event) => {
            const button = event.target.closest('[data-save-user-status]');
            if (button) {
                void saveUserStatus(
                    button.dataset.saveUserStatus,
                    button
                );
            }
        });
        byId('refresh-security-button').addEventListener(
            'click',
            () => void loadSecurityData().catch((error) => {
                console.error('Unable to refresh safety alerts:', error);
                showMessage('Unable to refresh safety alerts.');
            })
        );
        byId('scan-long-sessions-button').addEventListener(
            'click',
            (event) => void scanLongRunningSessions(event.currentTarget)
        );
        byId('security-events-table').addEventListener(
            'click',
            (event) => {
                const openButton = event.target.closest(
                    '[data-open-security-case]'
                );
                if (openButton) {
                    void reviewSecurityEvent(
                        openButton.dataset.openSecurityCase,
                        'open_case'
                    );
                    return;
                }
                const dismissButton = event.target.closest(
                    '[data-dismiss-security-event]'
                );
                if (dismissButton) {
                    void reviewSecurityEvent(
                        dismissButton.dataset.dismissSecurityEvent,
                        'dismiss'
                    );
                }
            }
        );
        byId('enforcement-cases-table').addEventListener(
            'click',
            (event) => {
                const warnButton = event.target.closest(
                    '[data-warn-enforcement-case]'
                );
                if (warnButton) {
                    void issueSecurityWarning(
                        warnButton.dataset.warnEnforcementCase
                    );
                    return;
                }
                const suspendButton = event.target.closest(
                    '[data-suspend-enforcement-case]'
                );
                if (suspendButton) {
                    void suspendEnforcementCase(
                        suspendButton.dataset.suspendEnforcementCase
                    );
                    return;
                }
                const restoreButton = event.target.closest(
                    '[data-restore-enforcement-case]'
                );
                if (restoreButton) {
                    void restoreEnforcementCase(
                        restoreButton.dataset.restoreEnforcementCase
                    );
                }
            }
        );
        byId('bulk-upload-entity').addEventListener(
            'change',
            () => resetBulkUpload()
        );
        byId('bulk-upload-file').addEventListener(
            'change',
            () => void reviewBulkUploadFile()
        );
        byId('clear-bulk-upload-button').addEventListener(
            'click',
            resetBulkUpload
        );
        byId('run-bulk-upload-button').addEventListener(
            'click',
            () => void runBulkUpload()
        );
        byId('exam-information-form').addEventListener(
            'submit',
            saveExamInformation
        );
        byId('cancel-exam-information-edit').addEventListener(
            'click',
            resetExamInformationForm
        );
        byId('exam-information-table').addEventListener(
            'click',
            (event) => {
                const editButton = event.target.closest(
                    '[data-edit-exam-information]'
                );
                if (editButton) {
                    editExamInformation(
                        editButton.dataset.editExamInformation
                    );
                    return;
                }
                const retireButton = event.target.closest(
                    '[data-retire-exam-information]'
                );
                if (retireButton) {
                    void retireExamInformation(
                        retireButton.dataset.retireExamInformation
                    );
                }
            }
        );
    }

    async function initialise() {
        const pageControl = sessionControl.acquirePageControl();
        if (!pageControl.acquired) {
            return;
        }

        try {
            if (!bulkUploadService) {
                throw new Error(
                    'The administrator bulk-upload validator is unavailable.'
                );
            }

            const { data: { user }, error: userError } =
                await client.auth.getUser();
            if (userError || !user) {
                sessionControl.releasePageControl();
                global.location.replace(
                    'index.html?next=admin-dashboard.html'
                );
                return;
            }

            if (!await sessionControl.activateProtectedPage(
                client,
                pageControl.tookOver
            )) {
                return;
            }

            const { data: isAdmin, error: adminError } =
                await client.rpc('fn_is_admin');
            if (adminError) {
                throw adminError;
            }
            if (isAdmin !== true) {
                byId('admin-loading').classList.add('hidden');
                byId('admin-denied').classList.remove('hidden');
                return;
            }

            await refreshCoreData();
            resetSubjectForm();
            resetQuestionForm();
            resetExamInformationForm();
            resetBulkUpload();
            installListeners();
            byId('admin-loading').classList.add('hidden');
            byId('admin-portal').classList.remove('hidden');
        } catch (error) {
            console.error('Admin portal loading error:', error);
            if (await sessionControl.handleInactiveSessionError(error)) {
                return;
            }
            byId('admin-loading').classList.add('hidden');
            byId('admin-denied').classList.remove('hidden');
        }
    }

    void initialise();
}(window));
