(function initialiseAdminBulkUpload(global) {
    'use strict';

    const MAX_ROWS = 250;
    const BOOLEAN_VALUES = new Set(['true', 'false']);
    const USER_STATUSES = new Set(['active', 'verification_pending']);
    const PROGRAMME_CATEGORIES = new Set([
        'professional_qualification',
        'broker_exam',
        'surveyor_exam',
        'specialized_diploma_exam'
    ]);
    const PROGRAMME_SECTION_CODES = new Set([
        'compulsory',
        'compulsory_optional',
        'optional_credit',
        'general_insurance',
        'life_insurance',
        'reinsurance',
        'broker',
        'surveyor',
        'spl_diploma'
    ]);
    const SUBJECT_CATEGORIES = new Set([
        'General Insurance',
        'Life Insurance',
        'Common (Life & Non-Life)',
        'Regulation and Compliance'
    ]);
    const DIFFICULTY_VALUES = new Set([
        'easy',
        'moderate',
        'hard',
        'foundation',
        'intermediate',
        'advanced'
    ]);
    const STORED_DIFFICULTY_VALUES = new Set([
        'foundation',
        'intermediate',
        'advanced'
    ]);
    const DOCUMENT_TYPES = new Set([
        'handbook',
        'syllabus',
        'credit_points',
        'subject_amendment',
        'withdrawal_notice',
        'official_notice',
        'schedule',
        'centre_list',
        'language_list'
    ]);

    function format(label, fileName, columns) {
        return Object.freeze({
            label,
            fileName,
            columns: Object.freeze(columns)
        });
    }

    const FORMATS = Object.freeze({
        users: format(
            'Existing users',
            'users.csv',
            ['email', 'status']
        ),
        qualification_levels: format(
            'Qualification levels',
            'qualification-levels.csv',
            [
                'code',
                'name',
                'description',
                'display_order',
                'is_active'
            ]
        ),
        exam_authorities: format(
            'Examination authorities',
            'exam-authorities.csv',
            [
                'code',
                'name',
                'short_name',
                'description',
                'official_website',
                'disclaimer_text',
                'display_order',
                'is_active'
            ]
        ),
        training_programmes: format(
            'Training programmes',
            'training-programmes.csv',
            [
                'authority_code',
                'code',
                'name',
                'programme_category',
                'description',
                'official_pass_percentage',
                'recommended_readiness_percentage',
                'exam_question_count',
                'exam_duration_minutes',
                'negative_marking',
                'display_order',
                'is_active'
            ]
        ),
        programme_sections: format(
            'Programme sections',
            'programme-sections.csv',
            [
                'programme_code',
                'code',
                'name',
                'description',
                'exam_question_count',
                'recommended_practice_question_count',
                'display_order',
                'is_active'
            ]
        ),
        subjects: format(
            'Subject master',
            'subjects.csv',
            [
                'id',
                'code',
                'title',
                'description',
                'qualification_level_id',
                'training_programme_id',
                'programme_section_id',
                'category',
                'syllabus_version',
                'display_order',
                'demo_question_limit',
                'price',
                'currency_code',
                'is_demo_available',
                'is_active'
            ]
        ),
        modules: format(
            'Learning modules',
            'modules.csv',
            [
                'subject_code',
                'code',
                'title',
                'description',
                'display_order',
                'is_active'
            ]
        ),
        chapters: format(
            'Learning chapters',
            'chapters.csv',
            [
                'subject_code',
                'module_code',
                'chapter_number',
                'code',
                'title',
                'description',
                'display_order',
                'is_active'
            ]
        ),
        topics: format(
            'Learning topics',
            'topics.csv',
            [
                'subject_code',
                'module_code',
                'chapter_code',
                'topic_number',
                'code',
                'title',
                'description',
                'learning_objective',
                'practical_relevance',
                'estimated_study_minutes',
                'difficulty_level',
                'display_order',
                'is_exam_relevant',
                'is_active'
            ]
        ),
        learning_resource_types: format(
            'Learning resource types',
            'learning-resource-types.csv',
            [
                'code',
                'name',
                'description',
                'icon_name',
                'display_order',
                'is_active'
            ]
        ),
        learning_resources: format(
            'Learning resources',
            'learning-resources.csv',
            [
                'subject_code',
                'module_code',
                'chapter_code',
                'topic_code',
                'resource_type_code',
                'code',
                'title',
                'short_description',
                'content',
                'external_url',
                'attachment_path',
                'author_name',
                'version_no',
                'estimated_read_minutes',
                'display_order',
                'is_exam_relevant',
                'is_premium',
                'is_active'
            ]
        ),
        flashcards: format(
            'Flashcards',
            'flashcards.csv',
            [
                'subject_code',
                'module_code',
                'chapter_code',
                'topic_code',
                'code',
                'question',
                'answer',
                'explanation',
                'display_order',
                'difficulty_level',
                'is_exam_relevant',
                'is_active'
            ]
        ),
        questions: format(
            'Question bank',
            'questions.csv',
            [
                'id',
                'subject_code',
                'question_text',
                'option_a',
                'option_b',
                'option_c',
                'option_d',
                'correct_option',
                'explanation',
                'difficulty_level',
                'marks',
                'negative_marks',
                'display_order',
                'is_active'
            ]
        ),
        exam_information: format(
            'Examination information',
            'exam-information.csv',
            [
                'id',
                'source_document_id',
                'authority_code',
                'subject_code',
                'programme_code',
                'section_code',
                'session_code',
                'document_type',
                'title',
                'geographic_scope',
                'official_url',
                'discovery_url',
                'published_on',
                'effective_from',
                'valid_until',
                'content_usage',
                'verification_status',
                'verified_on',
                'is_active'
            ]
        ),
        entitlements: format(
            'Non-payment entitlements',
            'entitlements.csv',
            [
                'id',
                'email',
                'subject_code',
                'access_type',
                'status',
                'valid_from',
                'valid_until',
                'source_reference'
            ]
        )
    });

    function parseCsv(csvText) {
        const text = String(csvText || '').replace(/^\uFEFF/, '');
        const rows = [];
        let row = [];
        let field = '';
        let quoted = false;

        for (let index = 0; index < text.length; index += 1) {
            const character = text[index];

            if (quoted) {
                if (character === '"' && text[index + 1] === '"') {
                    field += '"';
                    index += 1;
                } else if (character === '"') {
                    quoted = false;
                } else {
                    field += character;
                }
                continue;
            }

            if (character === '"' && field.length === 0) {
                quoted = true;
            } else if (character === ',') {
                row.push(field);
                field = '';
            } else if (character === '\n') {
                row.push(field);
                rows.push(row);
                row = [];
                field = '';
            } else if (character !== '\r') {
                field += character;
            }
        }

        if (quoted) {
            throw new Error('The CSV contains an unclosed quoted value.');
        }

        if (field.length > 0 || row.length > 0) {
            row.push(field);
            rows.push(row);
        }

        return rows.filter(
            (record) => record.some(
                (value) => String(value).trim() !== ''
            )
        );
    }

    function normalizedHeaders(record) {
        return record.map(
            (value) => String(value).trim().toLowerCase()
        );
    }

    function csvObjectRows(records, headers) {
        return records.slice(1).map((record, recordIndex) => {
            const values = {};
            headers.forEach((header, columnIndex) => {
                values[header] = String(
                    record[columnIndex] ?? ''
                ).trim();
            });
            return {
                csvRow: recordIndex + 2,
                values,
                columnCount: record.length
            };
        });
    }

    function addError(errors, row, message) {
        errors.push({ row: row.csvRow, message });
    }

    function validOptionalInteger(value, minimum = 1) {
        return value === ''
            || (/^\d+$/.test(value) && Number(value) >= minimum);
    }

    function validOptionalNumber(value, minimum = 0, exclusive = false) {
        if (value === '') {
            return true;
        }
        const numericValue = Number(value);
        return Number.isFinite(numericValue)
            && (exclusive
                ? numericValue > minimum
                : numericValue >= minimum);
    }

    function validDate(value) {
        return value === ''
            || (
                /^\d{4}-\d{2}-\d{2}$/.test(value)
                && !Number.isNaN(Date.parse(`${value}T00:00:00Z`))
            );
    }

    function validTimestamp(value) {
        return value === '' || !Number.isNaN(Date.parse(value));
    }

    function validateBoolean(row, field, errors) {
        if (!BOOLEAN_VALUES.has(row.values[field].toLowerCase())) {
            addError(errors, row, `${field} must be true or false.`);
        }
    }

    function validateRequired(row, fields, errors) {
        fields.forEach((field) => {
            if (row.values[field] === '') {
                addError(errors, row, `${field} is required.`);
            }
        });
    }

    function validateDisplayOrder(row, errors) {
        if (row.values.display_order === ''
            || !validOptionalInteger(row.values.display_order)) {
            addError(
                errors,
                row,
                'display_order must be at least 1.'
            );
        }
    }

    function validateCode(row, field, errors, upper = false) {
        const value = upper
            ? row.values[field].toUpperCase()
            : row.values[field].toLowerCase();
        const pattern = upper
            ? /^[A-Z0-9][A-Z0-9_:-]{1,119}$/
            : /^[a-z0-9][a-z0-9_-]{1,79}$/;
        if (!pattern.test(value)) {
            addError(
                errors,
                row,
                `${field} contains unsupported characters.`
            );
        }
    }

    function validateUnique(rows, fields, errors) {
        const seen = new Set();
        rows.forEach((row) => {
            const key = fields.map(
                (field) => row.values[field].toLowerCase()
            ).join('|');
            if (seen.has(key)) {
                addError(
                    errors,
                    row,
                    `The same ${fields.join(' + ')} appears more than once.`
                );
            }
            seen.add(key);
        });
    }

    function validateUsers(rows, errors) {
        validateUnique(rows, ['email'], errors);
        rows.forEach((row) => {
            const email = row.values.email.toLowerCase();
            const status = row.values.status.toLowerCase();

            if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
                addError(
                    errors,
                    row,
                    'Enter a valid existing user email address.'
                );
            }
            if (!USER_STATUSES.has(status)) {
                addError(
                    errors,
                    row,
                    'status must be active or verification_pending.'
                );
            }
        });
    }

    function validateSimpleMaster(
        rows,
        errors,
        requiredFields = ['code', 'name']
    ) {
        validateUnique(rows, ['code'], errors);
        rows.forEach((row) => {
            validateRequired(row, requiredFields, errors);
            validateCode(row, 'code', errors);
            validateDisplayOrder(row, errors);
            validateBoolean(row, 'is_active', errors);
        });
    }

    function validateExamAuthorities(rows, errors) {
        validateSimpleMaster(
            rows,
            errors,
            ['code', 'name', 'short_name']
        );
        rows.forEach((row) => {
            if (row.values.official_website !== ''
                && !/^https:\/\//i.test(
                    row.values.official_website
                )) {
                addError(
                    errors,
                    row,
                    'official_website must use HTTPS.'
                );
            }
        });
    }

    function validateProgrammes(rows, errors) {
        validateUnique(rows, ['code'], errors);
        rows.forEach((row) => {
            validateRequired(
                row,
                [
                    'authority_code',
                    'code',
                    'name',
                    'programme_category',
                    'official_pass_percentage',
                    'recommended_readiness_percentage'
                ],
                errors
            );
            validateCode(row, 'authority_code', errors);
            validateCode(row, 'code', errors);
            if (!PROGRAMME_CATEGORIES.has(
                row.values.programme_category.toLowerCase()
            )) {
                addError(
                    errors,
                    row,
                    'programme_category must use an approved frozen value.'
                );
            }
            for (const field of [
                'official_pass_percentage',
                'recommended_readiness_percentage'
            ]) {
                const value = Number(row.values[field]);
                if (!Number.isFinite(value) || value <= 0 || value > 100) {
                    addError(
                        errors,
                        row,
                        `${field} must be greater than 0 and no more than 100.`
                    );
                }
            }
            for (const field of [
                'exam_question_count',
                'exam_duration_minutes'
            ]) {
                if (!validOptionalInteger(row.values[field])) {
                    addError(
                        errors,
                        row,
                        `${field} must be blank or a positive whole number.`
                    );
                }
            }
            if (row.values.negative_marking !== '') {
                validateBoolean(row, 'negative_marking', errors);
            }
            validateDisplayOrder(row, errors);
            validateBoolean(row, 'is_active', errors);
        });
    }

    function validateProgrammeSections(rows, errors) {
        validateUnique(rows, ['programme_code', 'code'], errors);
        rows.forEach((row) => {
            validateRequired(
                row,
                ['programme_code', 'code', 'name'],
                errors
            );
            validateCode(row, 'programme_code', errors);
            validateCode(row, 'code', errors);
            if (!PROGRAMME_SECTION_CODES.has(
                row.values.code.toLowerCase()
            )) {
                addError(
                    errors,
                    row,
                    'code must use an approved frozen programme section.'
                );
            }
            for (const field of [
                'exam_question_count',
                'recommended_practice_question_count'
            ]) {
                if (!validOptionalInteger(row.values[field])) {
                    addError(
                        errors,
                        row,
                        `${field} must be blank or a positive whole number.`
                    );
                }
            }
            validateDisplayOrder(row, errors);
            validateBoolean(row, 'is_active', errors);
        });
    }

    function validateSubjects(rows, errors) {
        validateUnique(rows, ['code'], errors);
        rows.forEach((row) => {
            const values = row.values;
            const code = values.code.toUpperCase();

            if (values.id !== '' && !validOptionalInteger(values.id)) {
                addError(
                    errors,
                    row,
                    'id must be blank or a positive whole number.'
                );
            }
            if (!/^[A-Z0-9][A-Z0-9-]{1,19}$/.test(code)) {
                addError(
                    errors,
                    row,
                    'code must contain 2-20 letters, numbers, or hyphens.'
                );
            }
            if (values.title.length < 2 || values.title.length > 160) {
                addError(
                    errors,
                    row,
                    'title must contain 2-160 characters.'
                );
            }
            if (!SUBJECT_CATEGORIES.has(values.category.trim())) {
                addError(
                    errors,
                    row,
                    'category must use an approved frozen value.'
                );
            }
            for (const field of [
                'qualification_level_id',
                'training_programme_id',
                'programme_section_id'
            ]) {
                if (!validOptionalInteger(values[field])) {
                    addError(
                        errors,
                        row,
                        `${field} must be blank or a positive whole number.`
                    );
                }
            }
            validateDisplayOrder(row, errors);
            if (values.demo_question_limit === ''
                || !validOptionalInteger(
                    values.demo_question_limit,
                    0
                )
                || Number(values.demo_question_limit) > 50) {
                addError(
                    errors,
                    row,
                    'demo_question_limit must be between 0 and 50.'
                );
            }
            if (values.price === ''
                || !validOptionalNumber(values.price)) {
                addError(
                    errors,
                    row,
                    'price must be zero or a positive number.'
                );
            }
            if (!/^[A-Za-z]{3}$/.test(values.currency_code)) {
                addError(
                    errors,
                    row,
                    'currency_code must contain three letters.'
                );
            }
            validateBoolean(row, 'is_demo_available', errors);
            validateBoolean(row, 'is_active', errors);

            if (values.id === ''
                && values.is_active.toLowerCase() === 'true') {
                addError(
                    errors,
                    row,
                    'A new subject must be uploaded with is_active=false.'
                );
            }
        });
    }

    function validateModules(rows, errors) {
        validateUnique(rows, ['subject_code', 'code'], errors);
        rows.forEach((row) => {
            validateRequired(
                row,
                ['subject_code', 'code', 'title'],
                errors
            );
            validateCode(row, 'code', errors);
            validateDisplayOrder(row, errors);
            validateBoolean(row, 'is_active', errors);
        });
    }

    function validateChapters(rows, errors) {
        validateUnique(rows, ['subject_code', 'code'], errors);
        validateUnique(
            rows,
            ['subject_code', 'module_code', 'chapter_number'],
            errors
        );
        rows.forEach((row) => {
            validateRequired(
                row,
                [
                    'subject_code',
                    'module_code',
                    'chapter_number',
                    'code',
                    'title'
                ],
                errors
            );
            validateCode(row, 'module_code', errors);
            validateCode(row, 'code', errors);
            if (!validOptionalInteger(row.values.chapter_number)) {
                addError(
                    errors,
                    row,
                    'chapter_number must be a positive whole number.'
                );
            }
            validateDisplayOrder(row, errors);
            validateBoolean(row, 'is_active', errors);
        });
    }

    function validateTopics(rows, errors) {
        validateUnique(rows, ['subject_code', 'code'], errors);
        validateUnique(
            rows,
            [
                'subject_code',
                'module_code',
                'chapter_code',
                'topic_number'
            ],
            errors
        );
        rows.forEach((row) => {
            validateRequired(
                row,
                [
                    'subject_code',
                    'module_code',
                    'chapter_code',
                    'topic_number',
                    'code',
                    'title',
                    'difficulty_level'
                ],
                errors
            );
            for (const field of [
                'module_code',
                'chapter_code',
                'code'
            ]) {
                validateCode(row, field, errors);
            }
            if (!validOptionalInteger(row.values.topic_number)) {
                addError(
                    errors,
                    row,
                    'topic_number must be a positive whole number.'
                );
            }
            if (!validOptionalInteger(
                row.values.estimated_study_minutes
            )) {
                addError(
                    errors,
                    row,
                    'estimated_study_minutes must be blank or positive.'
                );
            }
            if (!STORED_DIFFICULTY_VALUES.has(
                row.values.difficulty_level.toLowerCase()
            )) {
                addError(
                    errors,
                    row,
                    'difficulty_level must be foundation, intermediate, or advanced.'
                );
            }
            validateDisplayOrder(row, errors);
            validateBoolean(row, 'is_exam_relevant', errors);
            validateBoolean(row, 'is_active', errors);
        });
    }

    function validateResourceTypes(rows, errors) {
        validateUnique(rows, ['code'], errors);
        rows.forEach((row) => {
            validateRequired(row, ['code', 'name'], errors);
            validateCode(row, 'code', errors, true);
            validateDisplayOrder(row, errors);
            validateBoolean(row, 'is_active', errors);
        });
    }

    function validateLearningResources(rows, errors) {
        validateUnique(rows, ['code'], errors);
        rows.forEach((row) => {
            const values = row.values;
            validateRequired(
                row,
                [
                    'subject_code',
                    'module_code',
                    'chapter_code',
                    'topic_code',
                    'resource_type_code',
                    'code',
                    'title',
                    'version_no'
                ],
                errors
            );
            for (const field of [
                'module_code',
                'chapter_code',
                'topic_code'
            ]) {
                validateCode(row, field, errors);
            }
            validateCode(row, 'resource_type_code', errors, true);
            validateCode(row, 'code', errors, true);
            if (values.content === ''
                && values.external_url === ''
                && values.attachment_path === '') {
                addError(
                    errors,
                    row,
                    'Supply content, external_url, or attachment_path.'
                );
            }
            if (values.external_url !== ''
                && !/^https:\/\//i.test(values.external_url)) {
                addError(
                    errors,
                    row,
                    'external_url must use HTTPS.'
                );
            }
            if (!validOptionalInteger(values.version_no)
                || !validOptionalInteger(
                    values.estimated_read_minutes
                )) {
                addError(
                    errors,
                    row,
                    'Version and optional reading time must be positive.'
                );
            }
            validateDisplayOrder(row, errors);
            validateBoolean(row, 'is_exam_relevant', errors);
            validateBoolean(row, 'is_premium', errors);
            validateBoolean(row, 'is_active', errors);
        });
    }

    function validateFlashcards(rows, errors) {
        validateUnique(rows, ['code'], errors);
        rows.forEach((row) => {
            validateRequired(
                row,
                [
                    'subject_code',
                    'module_code',
                    'chapter_code',
                    'topic_code',
                    'code',
                    'question',
                    'answer',
                    'difficulty_level'
                ],
                errors
            );
            for (const field of [
                'module_code',
                'chapter_code',
                'topic_code'
            ]) {
                validateCode(row, field, errors);
            }
            validateCode(row, 'code', errors, true);
            if (!STORED_DIFFICULTY_VALUES.has(
                row.values.difficulty_level.toLowerCase()
            )) {
                addError(
                    errors,
                    row,
                    'difficulty_level must be foundation, intermediate, or advanced.'
                );
            }
            validateDisplayOrder(row, errors);
            validateBoolean(row, 'is_exam_relevant', errors);
            validateBoolean(row, 'is_active', errors);
        });
    }

    function validateQuestions(rows, errors) {
        rows.forEach((row) => {
            const values = row.values;
            const options = [
                values.option_a,
                values.option_b,
                values.option_c,
                values.option_d
            ];

            if (values.id !== '' && !validOptionalInteger(values.id)) {
                addError(
                    errors,
                    row,
                    'id must be blank or a positive whole number.'
                );
            }
            if (!/^[A-Za-z0-9][A-Za-z0-9-]{1,19}$/.test(
                values.subject_code
            )) {
                addError(
                    errors,
                    row,
                    'Enter a valid subject_code.'
                );
            }
            if (values.question_text.length < 10
                || values.question_text.length > 5000) {
                addError(
                    errors,
                    row,
                    'question_text must contain 10-5000 characters.'
                );
            }
            if (options.some((option) => option.length === 0)) {
                addError(
                    errors,
                    row,
                    'All four answer options are required.'
                );
            } else if (new Set(options).size !== options.length) {
                addError(
                    errors,
                    row,
                    'All four answer options must be different.'
                );
            }
            if (!['A', 'B', 'C', 'D'].includes(
                values.correct_option.toUpperCase()
            )) {
                addError(
                    errors,
                    row,
                    'correct_option must be A, B, C, or D.'
                );
            }
            if (values.explanation.length < 5
                || values.explanation.length > 10000) {
                addError(
                    errors,
                    row,
                    'explanation must contain 5-10000 characters.'
                );
            }
            if (!DIFFICULTY_VALUES.has(
                values.difficulty_level.toLowerCase()
            )) {
                addError(
                    errors,
                    row,
                    'difficulty_level must be Easy, Moderate, or Hard.'
                );
            }
            if (values.marks === ''
                || !validOptionalNumber(values.marks, 0, true)) {
                addError(
                    errors,
                    row,
                    'marks must be greater than zero.'
                );
            }
            if (values.negative_marks === ''
                || !validOptionalNumber(values.negative_marks)) {
                addError(
                    errors,
                    row,
                    'negative_marks cannot be below zero.'
                );
            }
            validateDisplayOrder(row, errors);
            validateBoolean(row, 'is_active', errors);
        });
    }

    function validateExamInformation(rows, errors) {
        validateUnique(rows, ['source_document_id'], errors);
        rows.forEach((row) => {
            const values = row.values;
            validateRequired(
                row,
                [
                    'source_document_id',
                    'authority_code',
                    'document_type',
                    'title',
                    'geographic_scope',
                    'official_url',
                    'content_usage',
                    'verification_status',
                    'verified_on',
                    'is_active'
                ],
                errors
            );
            if (values.id !== '' && !validOptionalInteger(values.id)) {
                addError(
                    errors,
                    row,
                    'id must be blank or a positive whole number.'
                );
            }
            validateCode(row, 'authority_code', errors);
            if (values.programme_code !== '') {
                validateCode(row, 'programme_code', errors);
            }
            if (values.section_code !== '') {
                validateCode(row, 'section_code', errors);
                if (values.programme_code === '') {
                    addError(
                        errors,
                        row,
                        'programme_code is required with section_code.'
                    );
                }
            }
            if (!DOCUMENT_TYPES.has(
                values.document_type.toLowerCase()
            )) {
                addError(
                    errors,
                    row,
                    'document_type is not supported.'
                );
            }
            if (!['all', 'india', 'overseas'].includes(
                values.geographic_scope.toLowerCase()
            )) {
                addError(
                    errors,
                    row,
                    'geographic_scope must be all, india, or overseas.'
                );
            }
            if (!/^https:\/\//i.test(values.official_url)
                || (
                    values.discovery_url !== ''
                    && !/^https:\/\//i.test(values.discovery_url)
                )) {
                addError(
                    errors,
                    row,
                    'Official and optional discovery URLs must use HTTPS.'
                );
            }
            for (const field of [
                'published_on',
                'effective_from',
                'valid_until',
                'verified_on'
            ]) {
                if (!validDate(values[field])) {
                    addError(
                        errors,
                        row,
                        `${field} must use YYYY-MM-DD.`
                    );
                }
            }
            if ([
                'schedule',
                'centre_list',
                'language_list'
            ].includes(values.document_type.toLowerCase())
                && (
                    values.session_code === ''
                    || values.valid_until === ''
                )) {
                addError(
                    errors,
                    row,
                    'Session code and valid_until are required for session information.'
                );
            }
            if (!['metadata_only', 'reference_only'].includes(
                values.content_usage.toLowerCase()
            )) {
                addError(
                    errors,
                    row,
                    'content_usage must be metadata_only or reference_only.'
                );
            }
            if (![
                'official_url_verified',
                'visual_source_verified',
                'document_date_verified'
            ].includes(values.verification_status.toLowerCase())) {
                addError(
                    errors,
                    row,
                    'verification_status is not supported.'
                );
            }
            validateBoolean(row, 'is_active', errors);
        });
    }

    function validateEntitlements(rows, errors) {
        rows.forEach((row) => {
            const values = row.values;
            validateRequired(
                row,
                [
                    'email',
                    'subject_code',
                    'access_type',
                    'status',
                    'source_reference'
                ],
                errors
            );
            if (values.id !== ''
                && !/^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(values.id)) {
                addError(
                    errors,
                    row,
                    'id must be blank or an existing entitlement UUID.'
                );
            }
            if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(values.email)) {
                addError(
                    errors,
                    row,
                    'Enter a valid existing active user email.'
                );
            }
            if (![
                'complimentary',
                'promotional',
                'admin_grant'
            ].includes(values.access_type.toLowerCase())) {
                addError(
                    errors,
                    row,
                    'access_type may be complimentary, promotional, or admin_grant only.'
                );
            }
            if (![
                'active',
                'expired',
                'revoked',
                'pending'
            ].includes(values.status.toLowerCase())) {
                addError(
                    errors,
                    row,
                    'status must be active, expired, revoked, or pending.'
                );
            }
            for (const field of ['valid_from', 'valid_until']) {
                if (!validTimestamp(values[field])) {
                    addError(
                        errors,
                        row,
                        `${field} must be blank or a valid ISO date/time.`
                    );
                }
            }
            if (values.source_reference.length < 3
                || values.source_reference.length > 180) {
                addError(
                    errors,
                    row,
                    'source_reference must contain 3-180 characters.'
                );
            }
        });
    }

    const VALIDATORS = Object.freeze({
        users: validateUsers,
        qualification_levels: validateSimpleMaster,
        exam_authorities: validateExamAuthorities,
        training_programmes: validateProgrammes,
        programme_sections: validateProgrammeSections,
        subjects: validateSubjects,
        modules: validateModules,
        chapters: validateChapters,
        topics: validateTopics,
        learning_resource_types: validateResourceTypes,
        learning_resources: validateLearningResources,
        flashcards: validateFlashcards,
        questions: validateQuestions,
        exam_information: validateExamInformation,
        entitlements: validateEntitlements
    });

    function lowerFields(payload, fields) {
        fields.forEach((field) => {
            if (Object.hasOwn(payload, field)) {
                payload[field] = payload[field].toLowerCase();
            }
        });
    }

    function upperFields(payload, fields) {
        fields.forEach((field) => {
            if (Object.hasOwn(payload, field)) {
                payload[field] = payload[field].toUpperCase();
            }
        });
    }

    function normalizedPayload(entity, values) {
        const payload = { ...values };
        const booleanFields = [
            'is_active',
            'is_demo_available',
            'negative_marking',
            'is_exam_relevant',
            'is_premium'
        ];
        lowerFields(payload, booleanFields);

        if (entity === 'users') {
            lowerFields(payload, ['email', 'status']);
        } else if (entity === 'subjects') {
            upperFields(payload, ['code', 'currency_code']);
        } else if (entity === 'questions') {
            upperFields(
                payload,
                ['subject_code', 'correct_option']
            );
            lowerFields(payload, ['difficulty_level']);
        } else if (entity === 'exam_information') {
            upperFields(payload, ['subject_code']);
            lowerFields(
                payload,
                [
                    'authority_code',
                    'programme_code',
                    'section_code',
                    'document_type',
                    'geographic_scope',
                    'content_usage',
                    'verification_status'
                ]
            );
        } else if (entity === 'entitlements') {
            lowerFields(
                payload,
                ['email', 'access_type', 'status']
            );
            upperFields(payload, ['subject_code']);
        } else if (entity === 'learning_resources') {
            upperFields(
                payload,
                ['subject_code', 'resource_type_code', 'code']
            );
            lowerFields(
                payload,
                ['module_code', 'chapter_code', 'topic_code']
            );
        } else if (entity === 'flashcards') {
            upperFields(payload, ['subject_code', 'code']);
            lowerFields(
                payload,
                [
                    'module_code',
                    'chapter_code',
                    'topic_code',
                    'difficulty_level'
                ]
            );
        } else if (entity === 'learning_resource_types') {
            upperFields(payload, ['code']);
        } else if (['modules', 'chapters', 'topics'].includes(entity)) {
            upperFields(payload, ['subject_code']);
            lowerFields(
                payload,
                [
                    'module_code',
                    'chapter_code',
                    'code',
                    'difficulty_level'
                ]
            );
        } else {
            lowerFields(
                payload,
                [
                    'authority_code',
                    'programme_code',
                    'code'
                ]
            );
        }

        return payload;
    }

    function validateCsv(entity, csvText) {
        const formatDefinition = FORMATS[entity];
        if (!formatDefinition) {
            throw new Error('Select a supported upload type.');
        }

        const records = parseCsv(csvText);
        if (records.length < 2) {
            throw new Error(
                'The CSV must contain its header and at least one data row.'
            );
        }

        const headers = normalizedHeaders(records[0]);
        const errors = [];
        const duplicateHeaders = headers.filter(
            (header, index) => headers.indexOf(header) !== index
        );
        const missingHeaders = formatDefinition.columns.filter(
            (column) => !headers.includes(column)
        );
        const extraHeaders = headers.filter(
            (header) => !formatDefinition.columns.includes(header)
        );

        if (duplicateHeaders.length > 0) {
            errors.push({
                row: 1,
                message:
                    `Duplicate columns: ${[...new Set(duplicateHeaders)].join(', ')}.`
            });
        }
        if (missingHeaders.length > 0) {
            errors.push({
                row: 1,
                message: `Missing columns: ${missingHeaders.join(', ')}.`
            });
        }
        if (extraHeaders.length > 0) {
            errors.push({
                row: 1,
                message: `Unexpected columns: ${extraHeaders.join(', ')}.`
            });
        }

        if (errors.length > 0) {
            return { headers, rows: [], errors };
        }

        const objectRows = csvObjectRows(records, headers);
        if (objectRows.length > MAX_ROWS) {
            errors.push({
                row: 1,
                message:
                    `A single upload may contain no more than ${MAX_ROWS} rows.`
            });
        }
        objectRows.forEach((row) => {
            if (row.columnCount !== headers.length) {
                errors.push({
                    row: row.csvRow,
                    message:
                        `Expected ${headers.length} values but found ${row.columnCount}.`
                });
            }
        });

        VALIDATORS[entity](objectRows, errors);

        return {
            headers,
            rows: objectRows.map(
                (row) => normalizedPayload(entity, row.values)
            ),
            errors
        };
    }

    global.InsureGPTEAdminBulkUpload = Object.freeze({
        MAX_ROWS,
        FORMATS,
        parseCsv,
        validateCsv
    });
}(window));
