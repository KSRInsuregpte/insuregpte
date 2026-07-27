(function initialiseAdminPortal(global) {
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

    const state = {
        summary: null,
        subjects: [],
        questions: [],
        users: [],
        examInformation: [],
        auditEvents: []
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

    function populateReferenceSelects() {
        const summary = state.summary || {};
        const qualificationLevels = summary.qualification_levels || [];
        const programmes = summary.training_programmes || [];
        const sections = summary.programme_sections || [];
        const authorities = summary.exam_authorities || [];

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
                <td class="px-4 py-4 font-bold">${escapeHtml(question.correct_option)}</td>
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
            question.correct_option || 'A';
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
                            <select data-user-status="${escapeHtml(user.user_id)}" class="rounded-lg border p-2" ${isAdmin ? 'disabled' : ''}>
                                <option value="active" ${user.status === 'active' ? 'selected' : ''}>Active</option>
                                <option value="verification_pending" ${user.status === 'verification_pending' ? 'selected' : ''}>Verification pending</option>
                            </select>
                            <button type="button" data-save-user-status="${escapeHtml(user.user_id)}" class="rounded-lg bg-blue-800 px-3 py-2 font-bold text-white disabled:opacity-50" ${isAdmin ? 'disabled' : ''}>Save</button>
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
