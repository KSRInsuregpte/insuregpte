(function initializeRegistrationValidation(global) {
    'use strict';

    const PROFESSIONS = Object.freeze([
        'Student',
        'Working Professional',
        'Insurance Agent',
        'Insurance Broker',
        'Surveyor / Loss Assessor',
        'Other'
    ]);

    const REGISTRATION_SOURCES = Object.freeze([
        'search_engine',
        'colleague',
        'employer',
        'training_institute',
        'social_media',
        'professional_association',
        'direct_invitation',
        'other'
    ]);

    const NAME_PATTERN = /^[\p{L}][\p{L}\p{M} .'-]{0,49}$/u;
    const EMAIL_PATTERN =
        /^[A-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Z0-9-]+(?:\.[A-Z0-9-]+)+$/i;
    const MOBILE_PATTERN = /^\+[1-9][0-9]{7,14}$/;
    const POSTAL_PATTERN = /^[A-Z0-9][A-Z0-9 -]{1,10}[A-Z0-9]$/i;

    function clean(value) {
        return typeof value === 'string' ? value.trim() : '';
    }

    function isValidPassword(password) {
        return typeof password === 'string'
            && password.length >= 12
            && password.length <= 64
            && !/\s/.test(password)
            && /[A-Z]/.test(password)
            && /[a-z]/.test(password)
            && /[0-9]/.test(password)
            && /[^A-Za-z0-9]/.test(password);
    }

    function validate(values) {
        const data = {
            firstName: clean(values.firstName),
            lastName: clean(values.lastName),
            email: clean(values.email).toLowerCase(),
            password: typeof values.password === 'string'
                ? values.password
                : '',
            confirmPassword: typeof values.confirmPassword === 'string'
                ? values.confirmPassword
                : '',
            profession: clean(values.profession),
            mobile: clean(values.mobile),
            companyName: clean(values.companyName),
            buildingName: clean(values.buildingName),
            streetName: clean(values.streetName),
            area: clean(values.area),
            city: clean(values.city),
            pinCode: clean(values.pinCode),
            country: clean(values.country),
            registrationSource: clean(values.registrationSource),
            registrationSourceDetail: clean(
                values.registrationSourceDetail
            ),
            subjects: Array.isArray(values.subjects)
                ? [...new Set(values.subjects.map(clean).filter(Boolean))]
                : []
        };
        const errors = {};

        if (!NAME_PATTERN.test(data.firstName)) {
            errors.firstName = 'Enter a valid first name.';
        }

        if (!NAME_PATTERN.test(data.lastName)) {
            errors.lastName = 'Enter a valid last name.';
        }

        if (!EMAIL_PATTERN.test(data.email) || data.email.length > 254) {
            errors.email = 'Enter a valid email address.';
        }

        if (!isValidPassword(data.password)) {
            errors.password =
                'Use 12–64 characters with uppercase, lowercase, a number, and a symbol.';
        }

        if (data.password !== data.confirmPassword) {
            errors.confirmPassword = 'The passwords do not match.';
        }

        if (!PROFESSIONS.includes(data.profession)) {
            errors.profession = 'Select your profession.';
        }

        if (!MOBILE_PATTERN.test(data.mobile)) {
            errors.mobile =
                'Enter the mobile number with country code, for example +919876543210.';
        }

        const lengthRules = [
            ['companyName', 2, 120, 'company or institution'],
            ['buildingName', 2, 120, 'building or house'],
            ['streetName', 2, 120, 'street'],
            ['area', 2, 120, 'area or locality'],
            ['city', 2, 80, 'city'],
            ['country', 2, 56, 'country']
        ];

        for (const [key, minimum, maximum, label] of lengthRules) {
            if (data[key].length < minimum || data[key].length > maximum) {
                errors[key] = `Enter a valid ${label}.`;
            }
        }

        if (!POSTAL_PATTERN.test(data.pinCode)) {
            errors.pinCode = 'Enter a valid postal or PIN code.';
        }

        if (!REGISTRATION_SOURCES.includes(data.registrationSource)) {
            errors.registrationSource =
                'Select how you learned about InsureGPTE.';
        }

        if (
            data.registrationSource === 'other'
            && (
                data.registrationSourceDetail.length < 2
                || data.registrationSourceDetail.length > 120
            )
        ) {
            errors.registrationSourceDetail =
                'Briefly describe how you learned about InsureGPTE.';
        }

        if (data.subjects.length < 1 || data.subjects.length > 20) {
            errors.subjects = 'Select at least one subject.';
        }

        return {
            valid: Object.keys(errors).length === 0,
            data,
            errors
        };
    }

    global.InsureGPTERegistrationValidation = Object.freeze({
        PROFESSIONS,
        REGISTRATION_SOURCES,
        isValidPassword,
        validate
    });
}(window));
