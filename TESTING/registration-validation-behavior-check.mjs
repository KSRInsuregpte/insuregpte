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
    path.join(repositoryRoot, 'js', 'registration-validation.js'),
    'utf8'
);
const context = { window: {} };

vm.createContext(context);
vm.runInContext(source, context, {
    filename: 'js/registration-validation.js'
});

const validation = context.window.InsureGPTERegistrationValidation;

assert.ok(validation, 'registration validation API should be exported');

const validRegistration = {
    firstName: 'Anita',
    lastName: 'Kumar',
    email: 'anita@example.com',
    password: 'StrongPassword#42',
    confirmPassword: 'StrongPassword#42',
    profession: 'Student',
    mobile: '+919876543210',
    companyName: 'Insurance Institute',
    buildingName: 'Learning House',
    streetName: 'Knowledge Road',
    area: 'Anna Nagar',
    city: 'Chennai',
    pinCode: '600001',
    country: 'India',
    registrationSource: 'direct_invitation',
    registrationSourceDetail: '',
    subjects: ['IC01']
};

assert.equal(
    validation.validate(validRegistration).valid,
    true,
    'complete valid registration should pass'
);

for (const password of [
    'Short#1A',
    'lowercaseonly#42',
    'UPPERCASEONLY#42',
    'NoNumberSymbol#',
    'NoSpecialNumber42',
    'Contains Space#42A'
]) {
    assert.equal(
        validation.isValidPassword(password),
        false,
        `weak password should fail: ${password}`
    );
}

assert.equal(
    validation.isValidPassword('StrongPassword#42'),
    true,
    'strong password should pass'
);

assert.equal(
    validation.composeMobileNumber('+91', '9876543210'),
    '+919876543210',
    'Indian calling code and national number should compose to E.164 format'
);
assert.equal(
    validation.composeMobileNumber('+44', '7700900123'),
    '+447700900123',
    'international calling code and number should compose to E.164 format'
);
assert.equal(
    validation.composeMobileNumber('+91', '1234567890'),
    '',
    'invalid Indian mobile numbers should be rejected'
);

const missingSubject = validation.validate({
    ...validRegistration,
    subjects: []
});
assert.equal(missingSubject.valid, false);
assert.equal(missingSubject.errors.subjects, 'Select at least one subject.');

const invalidMobile = validation.validate({
    ...validRegistration,
    mobile: '9876543210'
});
assert.equal(invalidMobile.valid, false);
assert.match(invalidMobile.errors.mobile, /calling code/);

const invalidIndiaPin = validation.validate({
    ...validRegistration,
    pinCode: '012345'
});
assert.equal(invalidIndiaPin.valid, false);
assert.match(invalidIndiaPin.errors.pinCode, /Indian PIN code/);

const validInternationalPostalCode = validation.validate({
    ...validRegistration,
    country: 'United Kingdom',
    pinCode: 'SW1A 1AA'
});
assert.equal(
    validInternationalPostalCode.valid,
    true,
    'international postal codes should remain available for manual entry'
);

const missingSourceDetail = validation.validate({
    ...validRegistration,
    registrationSource: 'other',
    registrationSourceDetail: ''
});
assert.equal(missingSourceDetail.valid, false);
assert.match(missingSourceDetail.errors.registrationSourceDetail, /describe/);

const duplicateSubjects = validation.validate({
    ...validRegistration,
    subjects: ['IC01', 'IC01']
});
assert.deepEqual(
    Array.from(duplicateSubjects.data.subjects),
    ['IC01'],
    'duplicate subject choices should be normalized'
);

console.log('Registration validation behavior checks passed.');
