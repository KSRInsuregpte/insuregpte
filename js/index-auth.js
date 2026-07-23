(function initializeIndexAuthentication(global) {
    'use strict';

    const SUPABASE_URL = 'https://tvjsivuibvzybdbjtesq.supabase.co';
    const SUPABASE_ANON_KEY =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        + 'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2anNpdnVpYnZ6eWJkYmp0ZXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0MTI1MjksImV4cCI6MjA5ODk4ODUyOX0.'
        + 'meGmoVDJE25neU_na5xl8u3CYxA24M7tqcG5ez-emaU';
    const REGISTRATION_SECURITY_VERSION = 2;
    const OTP_PATTERN = /^[0-9]{6}$/;
    const sessionControl = global.InsureGPTESessionControl;
    const validation = global.InsureGPTERegistrationValidation;
    const client = global.supabase.createClient(
        SUPABASE_URL,
        SUPABASE_ANON_KEY,
        sessionControl.clientOptions()
    );

    const state = {
        pageControl: null,
        signedIn: false,
        pendingEmail: '',
        pendingMobile: '',
        captcha: {
            configured: false,
            loginToken: '',
            registrationToken: '',
            loginWidgetId: null,
            registrationWidgetId: null,
            attempts: 0
        },
        mobileResendTimer: null
    };

    const views = [
        'login-view',
        'reg-view',
        'email-otp-view',
        'mobile-otp-view'
    ];

    function byId(id) {
        return document.getElementById(id);
    }

    function showView(viewId) {
        for (const id of views) {
            const view = byId(id);

            if (view) {
                view.classList.toggle('hidden', id !== viewId);
            }
        }
    }

    function setMessage(elementId, message, tone = 'error') {
        const element = byId(elementId);

        if (!element) {
            return;
        }

        if (!message) {
            element.textContent = '';
            element.classList.add('hidden');
            return;
        }

        const tones = {
            error: ['bg-red-50', 'text-red-800', 'border-red-200'],
            success: [
                'bg-emerald-50',
                'text-emerald-800',
                'border-emerald-200'
            ],
            warning: ['bg-amber-50', 'text-amber-900', 'border-amber-200']
        };

        element.className =
            `mb-5 rounded-xl border p-4 text-sm ${tones[tone].join(' ')}`;
        element.textContent = message;
    }

    function setButtonBusy(button, busy, busyLabel) {
        if (!button) {
            return;
        }

        if (!button.dataset.defaultLabel) {
            button.dataset.defaultLabel = button.textContent.trim();
        }

        button.disabled = busy;
        button.textContent = busy
            ? busyLabel
            : button.dataset.defaultLabel;
    }

    function configuredTurnstileSiteKey() {
        const meta = document.querySelector(
            'meta[name="insuregpte-turnstile-site-key"]'
        );
        const siteKey = meta?.content?.trim() || '';

        if (!siteKey || siteKey.startsWith('REPLACE_')) {
            return '';
        }

        return siteKey;
    }

    function setRegistrationEnabled(enabled) {
        const button = byId('btn-register');

        if (!button) {
            return;
        }

        button.disabled = !enabled;
        button.setAttribute('aria-disabled', String(!enabled));
    }

    function renderCaptchaWidgets() {
        const siteKey = configuredTurnstileSiteKey();

        setRegistrationEnabled(false);

        if (!siteKey) {
            setMessage(
                'registration-availability',
                'Protected registration is temporarily unavailable while security configuration is completed.',
                'warning'
            );
            return;
        }

        state.captcha.configured = true;

        if (!global.turnstile) {
            state.captcha.attempts += 1;

            if (state.captcha.attempts <= 50) {
                global.setTimeout(renderCaptchaWidgets, 200);
            } else {
                setMessage(
                    'registration-availability',
                    'The security check could not be loaded. Refresh the page and try again.',
                    'error'
                );
            }

            return;
        }

        if (state.captcha.loginWidgetId === null && byId('login-captcha')) {
            state.captcha.loginWidgetId = global.turnstile.render(
                '#login-captcha',
                {
                    sitekey: siteKey,
                    callback(token) {
                        state.captcha.loginToken = token;
                        setMessage('login-error', '');
                    },
                    'expired-callback'() {
                        state.captcha.loginToken = '';
                    },
                    'error-callback'() {
                        state.captcha.loginToken = '';
                    }
                }
            );
        }

        if (
            state.captcha.registrationWidgetId === null
            && byId('registration-captcha')
        ) {
            state.captcha.registrationWidgetId = global.turnstile.render(
                '#registration-captcha',
                {
                    sitekey: siteKey,
                    callback(token) {
                        state.captcha.registrationToken = token;
                        setMessage('registration-error', '');
                    },
                    'expired-callback'() {
                        state.captcha.registrationToken = '';
                    },
                    'error-callback'() {
                        state.captcha.registrationToken = '';
                    }
                }
            );
        }

        if (state.captcha.registrationWidgetId !== null) {
            setMessage('registration-availability', '');
            setRegistrationEnabled(true);
        }
    }

    function resetCaptcha(kind) {
        if (!state.captcha.configured || !global.turnstile) {
            return;
        }

        const widgetKey = kind === 'login'
            ? 'loginWidgetId'
            : 'registrationWidgetId';
        const tokenKey = kind === 'login'
            ? 'loginToken'
            : 'registrationToken';
        const widgetId = state.captcha[widgetKey];

        state.captcha[tokenKey] = '';

        if (widgetId !== null) {
            global.turnstile.reset(widgetId);
        }
    }

    function showSessionMessage() {
        const parameters = new URLSearchParams(global.location.search);
        const sessionReason = parameters.get('session');

        if (!['replaced', 'conflict'].includes(sessionReason)) {
            return;
        }

        setMessage(
            'session-message',
            sessionReason === 'conflict'
                ? 'The second login was cancelled. Your first active page remains in control.'
                : 'This page was closed because another browser or page is now the active login. Sign in again only if you want to transfer control.',
            'warning'
        );

        parameters.delete('session');
        const remainingQuery = parameters.toString();
        const cleanUrl = global.location.pathname
            + (remainingQuery ? `?${remainingQuery}` : '')
            + global.location.hash;
        global.history.replaceState({}, '', cleanUrl);
    }

    function addSubjectCheckbox(subject, container) {
        const label = document.createElement('label');
        const checkbox = document.createElement('input');
        const title = document.createElement('span');

        label.className =
            'flex cursor-pointer items-start gap-2 rounded-lg border p-3 hover:bg-slate-50';
        checkbox.type = 'checkbox';
        checkbox.value = subject.code;
        checkbox.className = 'mt-1';
        title.textContent = `${subject.code} — ${subject.title}`;
        label.append(checkbox, title);
        container.append(label);
    }

    async function loadSubjects() {
        const container = byId('subject-list');

        if (!container) {
            return;
        }

        try {
            const { data, error } = await client
                .from('subjects')
                .select('code, title')
                .eq('is_active', true)
                .order('display_order');

            if (error) {
                throw error;
            }

            container.replaceChildren();

            for (const subject of data || []) {
                addSubjectCheckbox(subject, container);
            }

            if (!data?.length) {
                throw new Error('No active subjects are available.');
            }
        } catch (error) {
            console.error('Unable to load registration subjects:', error);
            container.textContent =
                'Subjects are temporarily unavailable. Please try again later.';
            setMessage(
                'registration-error',
                'Registration cannot continue until the subject list is available.'
            );
        }
    }

    function selectedCallingCode() {
        const selection = byId('mobile-country-code')?.value || '';

        return selection === 'other'
            ? byId('mobile-country-code-other')?.value
            : selection;
    }

    function selectedCountry() {
        const selection = byId('country')?.value || '';

        return selection === 'other'
            ? byId('country-other')?.value
            : selection;
    }

    function updateMobileCallingCode() {
        const selection = byId('mobile-country-code')?.value;
        const otherContainer = byId(
            'mobile-country-code-other-container'
        );
        const otherInput = byId('mobile-country-code-other');
        const guidance = byId('mobile-guidance');
        const usesOtherCode = selection === 'other';

        otherContainer?.classList.toggle('hidden', !usesOtherCode);

        if (otherInput) {
            otherInput.required = usesOtherCode;

            if (!usesOtherCode) {
                otherInput.value = '';
            }
        }

        if (guidance) {
            guidance.textContent = usesOtherCode
                ? 'Enter the calling code with +, then enter only the mobile number digits.'
                : 'India: enter the 10-digit mobile number without +91.';
        }
    }

    function updateCountrySelection() {
        const selection = byId('country')?.value;
        const otherContainer = byId('country-other-container');
        const otherInput = byId('country-other');
        const pinInput = byId('pin');
        const guidance = byId('postal-code-guidance');
        const usesOtherCountry = selection === 'other';

        otherContainer?.classList.toggle('hidden', !usesOtherCountry);

        if (otherInput) {
            otherInput.required = usesOtherCountry;

            if (!usesOtherCountry) {
                otherInput.value = '';
            }
        }

        if (pinInput) {
            pinInput.minLength = usesOtherCountry ? 3 : 6;
            pinInput.maxLength = usesOtherCountry ? 12 : 6;
            pinInput.inputMode = usesOtherCountry ? 'text' : 'numeric';
            pinInput.placeholder = usesOtherCountry ? 'Postal code' : '600001';
            pinInput.setAttribute(
                'pattern',
                usesOtherCountry
                    ? '[A-Za-z0-9][A-Za-z0-9 -]{1,10}[A-Za-z0-9]'
                    : '[1-9][0-9]{5}'
            );
        }

        if (guidance) {
            guidance.textContent = usesOtherCountry
                ? 'Enter the postal code manually using letters, numbers, spaces, or hyphens.'
                : 'Enter the six-digit Indian PIN code.';
        }
    }

    function setPasswordVisibility(button, visible) {
        const input = byId(button?.dataset?.passwordTarget);

        if (!button || !input) {
            return;
        }

        input.type = visible ? 'text' : 'password';
        button.textContent = visible ? 'Hide' : 'Show';
        button.setAttribute('aria-pressed', String(visible));
    }

    function resetPasswordVisibility() {
        document.querySelectorAll('[data-password-toggle]')
            .forEach((button) => setPasswordVisibility(button, false));
    }

    function togglePasswordVisibility(button) {
        const input = byId(button?.dataset?.passwordTarget);

        if (!input) {
            return;
        }

        setPasswordVisibility(button, input.type === 'password');
        input.focus();
    }

    function registrationValues() {
        return {
            firstName: byId('fname')?.value,
            lastName: byId('lname')?.value,
            email: byId('email')?.value,
            password: byId('pass')?.value,
            confirmPassword: byId('pass-confirm')?.value,
            profession: byId('prof')?.value,
            mobile: validation.composeMobileNumber(
                selectedCallingCode(),
                byId('mobile')?.value
            ),
            companyName: byId('cname')?.value,
            buildingName: byId('bname')?.value,
            streetName: byId('street')?.value,
            area: byId('area')?.value,
            city: byId('city')?.value,
            pinCode: byId('pin')?.value,
            country: selectedCountry(),
            registrationSource: byId('registration-source')?.value,
            registrationSourceDetail:
                byId('registration-source-detail')?.value,
            subjects: Array.from(
                document.querySelectorAll('#subject-list input:checked')
            ).map((checkbox) => checkbox.value)
        };
    }

    function firstValidationError(errors) {
        return Object.values(errors)[0] || 'Check the registration form.';
    }

    function focusFirstInvalidField(errors) {
        const idByKey = {
            firstName: 'fname',
            lastName: 'lname',
            email: 'email',
            password: 'pass',
            confirmPassword: 'pass-confirm',
            profession: 'prof',
            mobile: byId('mobile-country-code')?.value === 'other'
                && !byId('mobile-country-code-other')?.value
                ? 'mobile-country-code-other'
                : 'mobile',
            companyName: 'cname',
            buildingName: 'bname',
            streetName: 'street',
            area: 'area',
            city: 'city',
            pinCode: 'pin',
            country: byId('country')?.value === 'other'
                ? 'country-other'
                : 'country',
            registrationSource: 'registration-source',
            registrationSourceDetail: 'registration-source-detail',
            subjects: 'subject-list'
        };
        const firstKey = Object.keys(errors)[0];
        byId(idByKey[firstKey])?.focus();
    }

    function safeRegistrationError(error) {
        const message = error?.message || '';

        if (/signup.*disabled|signups not allowed/i.test(message)) {
            return 'New registration is temporarily paused. Please try again after the security update is enabled.';
        }

        const approvedMessages = [
            'Anonymous registration is not permitted.',
            'Registration must use a verified email address.',
            'Enter a valid email address.',
            'Please use the current InsureGPTE registration form.',
            'Enter a valid first name.',
            'Enter a valid last name.',
            'Enter the mobile number with country code.',
            'Enter the company or institution name.',
            'Select a valid profession.',
            'Enter a valid building or house name.',
            'Enter a valid street name.',
            'Enter a valid area or locality.',
            'Enter a valid city.',
            'Enter a valid postal or PIN code.',
            'Enter a valid country.',
            'Select how you learned about InsureGPTE.',
            'Describe how you learned about InsureGPTE.',
            'Select at least one subject.',
            'Select between 1 and 20 subjects.',
            'The selected subjects are invalid.',
            'One or more selected subjects are unavailable.'
        ];

        return approvedMessages.find((item) => message.includes(item))
            || 'Registration could not be completed. Check the form and try again.';
    }

    function registrationMetadata(data) {
        return {
            registration_security_version: REGISTRATION_SECURITY_VERSION,
            first_name: data.firstName,
            last_name: data.lastName,
            mobile: data.mobile,
            profession: data.profession,
            company_name: data.companyName,
            building_name: data.buildingName,
            street_name: data.streetName,
            area: data.area,
            city: data.city,
            pin_code: data.pinCode,
            country: data.country,
            registration_source: data.registrationSource,
            registration_source_detail:
                data.registrationSourceDetail,
            subjects: data.subjects
        };
    }

    async function handleRegister() {
        const button = byId('btn-register');

        setMessage('registration-error', '');

        if (!state.captcha.configured) {
            setMessage(
                'registration-error',
                'Protected registration is temporarily unavailable.'
            );
            return;
        }

        const result = validation.validate(registrationValues());

        if (!result.valid) {
            setMessage(
                'registration-error',
                firstValidationError(result.errors)
            );
            focusFirstInvalidField(result.errors);
            return;
        }

        if (!state.captcha.registrationToken) {
            setMessage(
                'registration-error',
                'Complete the security check before registering.'
            );
            return;
        }

        setButtonBusy(button, true, 'Creating secure account...');

        try {
            const { data: auth, error } = await client.auth.signUp({
                email: result.data.email,
                password: result.data.password,
                options: {
                    data: registrationMetadata(result.data),
                    captchaToken: state.captcha.registrationToken,
                    emailRedirectTo:
                        `${global.location.origin}${global.location.pathname}`
                }
            });

            if (error) {
                throw error;
            }

            if (!auth.user) {
                throw new Error('The account was not created.');
            }

            state.pendingEmail = result.data.email;
            state.pendingMobile = result.data.mobile;
            byId('email-otp-address').textContent = result.data.email;
            byId('email-otp').value = '';
            byId('reg-form').reset();
            updateRegistrationSourceDetail();
            updateMobileCallingCode();
            updateCountrySelection();
            resetPasswordVisibility();
            resetCaptcha('registration');
            setMessage(
                'email-otp-message',
                'Enter the six-digit code sent to your email address.',
                'success'
            );
            showView('email-otp-view');
        } catch (error) {
            console.error('Registration failed:', error);
            setMessage('registration-error', safeRegistrationError(error));
            resetCaptcha('registration');
        } finally {
            setButtonBusy(button, false, '');
        }
    }

    function registrationVersion(user) {
        return Number(
            user?.user_metadata?.registration_security_version || 1
        );
    }

    function registeredMobile(user) {
        return String(user?.user_metadata?.mobile || '').trim();
    }

    function hasCompletedMobileVerification(user) {
        const mobile = registeredMobile(user);
        return Boolean(
            user?.phone_confirmed_at
            && user?.phone
            && user.phone === mobile
        );
    }

    function showMobileVerification(user) {
        state.pendingEmail = user?.email || state.pendingEmail;
        state.pendingMobile = registeredMobile(user);
        byId('mobile-otp-number').textContent = state.pendingMobile;
        byId('mobile-otp').value = '';
        setMessage(
            'mobile-otp-message',
            'Your email is verified. Send and enter the SMS code to activate the account.',
            'success'
        );
        showView('mobile-otp-view');
    }

    async function verifyEmailOtp() {
        const button = byId('btn-verify-email-otp');
        const token = byId('email-otp').value.trim();

        setMessage('email-otp-message', '');

        if (!state.pendingEmail || !OTP_PATTERN.test(token)) {
            setMessage(
                'email-otp-message',
                'Enter the six-digit email verification code.'
            );
            return;
        }

        setButtonBusy(button, true, 'Verifying email...');

        try {
            const { data, error } = await client.auth.verifyOtp({
                email: state.pendingEmail,
                token,
                type: 'email'
            });

            if (error) {
                throw error;
            }

            if (!data.user?.email_confirmed_at) {
                throw new Error('Email verification was not completed.');
            }

            state.signedIn = Boolean(data.session);
            showMobileVerification(data.user);
        } catch (error) {
            console.error('Email OTP verification failed:', error);
            setMessage(
                'email-otp-message',
                'The email code is invalid or expired. Request a new registration email and try again.'
            );
        } finally {
            setButtonBusy(button, false, '');
        }
    }

    function beginMobileResendCooldown() {
        const button = byId('btn-send-mobile-otp');
        let seconds = 60;

        global.clearInterval(state.mobileResendTimer);
        button.disabled = true;
        button.textContent = `Send again in ${seconds}s`;

        state.mobileResendTimer = global.setInterval(() => {
            seconds -= 1;

            if (seconds <= 0) {
                global.clearInterval(state.mobileResendTimer);
                button.disabled = false;
                button.textContent = 'Send mobile OTP';
                return;
            }

            button.textContent = `Send again in ${seconds}s`;
        }, 1000);
    }

    async function sendMobileOtp() {
        const button = byId('btn-send-mobile-otp');

        setMessage('mobile-otp-message', '');

        if (!/^\+[1-9][0-9]{7,14}$/.test(state.pendingMobile)) {
            setMessage(
                'mobile-otp-message',
                'The registered mobile number is invalid. Contact support.'
            );
            return;
        }

        setButtonBusy(button, true, 'Sending SMS...');

        try {
            const { data: current, error: currentError } =
                await client.auth.getUser();

            if (currentError || !current.user?.email_confirmed_at) {
                throw currentError || new Error('Email verification required.');
            }

            if (registeredMobile(current.user) !== state.pendingMobile) {
                throw new Error('Registered mobile number mismatch.');
            }

            const { error } = await client.auth.updateUser({
                phone: state.pendingMobile
            });

            if (error) {
                throw error;
            }

            setMessage(
                'mobile-otp-message',
                'A six-digit OTP was sent to your registered mobile number.',
                'success'
            );
            beginMobileResendCooldown();
        } catch (error) {
            console.error('Mobile OTP request failed:', error);
            setMessage(
                'mobile-otp-message',
                'The mobile OTP could not be sent. Check the number or try again later.'
            );
            setButtonBusy(button, false, '');
        }
    }

    async function acquirePageControlIfNeeded() {
        if (state.pageControl?.acquired) {
            return true;
        }

        state.pageControl = sessionControl.acquirePageControl({
            blockOnCancel: false
        });

        return state.pageControl.acquired;
    }

    async function enterDashboard() {
        if (!await acquirePageControlIfNeeded()) {
            return;
        }

        const activated = await sessionControl.activateAfterSignIn(
            client,
            state.pageControl.tookOver
        );

        if (activated) {
            global.location.replace('dashboard.html');
        }
    }

    async function verifyMobileOtp() {
        const button = byId('btn-verify-mobile-otp');
        const token = byId('mobile-otp').value.trim();

        setMessage('mobile-otp-message', '');

        if (!OTP_PATTERN.test(token)) {
            setMessage(
                'mobile-otp-message',
                'Enter the six-digit mobile OTP.'
            );
            return;
        }

        setButtonBusy(button, true, 'Verifying mobile...');

        try {
            const { error } = await client.auth.verifyOtp({
                phone: state.pendingMobile,
                token,
                type: 'phone_change'
            });

            if (error) {
                throw error;
            }

            const { data, error: userError } = await client.auth.getUser();

            if (userError || !hasCompletedMobileVerification(data.user)) {
                throw userError || new Error(
                    'Mobile verification was not completed.'
                );
            }

            state.signedIn = true;
            setMessage(
                'mobile-otp-message',
                'Email and mobile number verified. Opening your dashboard…',
                'success'
            );
            await enterDashboard();
        } catch (error) {
            console.error('Mobile OTP verification failed:', error);
            setMessage(
                'mobile-otp-message',
                'The mobile OTP is invalid or expired. Request a new code and try again.'
            );
        } finally {
            setButtonBusy(button, false, '');
        }
    }

    async function cancelVerification() {
        global.clearInterval(state.mobileResendTimer);
        await client.auth.signOut({ scope: 'local' });
        sessionControl.releasePageControl();
        state.pageControl = null;
        state.signedIn = false;
        state.pendingEmail = '';
        state.pendingMobile = '';
        showView('login-view');
    }

    function safeLoginError(error) {
        const message = error?.message || '';

        if (/email not confirmed/i.test(message)) {
            return 'Verify your email before signing in.';
        }

        if (/captcha/i.test(message)) {
            return 'Complete the security check and try again.';
        }

        return 'Sign in failed. Check your email and password.';
    }

    async function handleLogin() {
        const button = byId('btn-login');
        const email = byId('login-email').value.trim().toLowerCase();
        const password = byId('login-pass').value;

        setMessage('login-error', '');

        if (!email || !password) {
            setMessage('login-error', 'Enter your email and password.');
            return;
        }

        if (state.captcha.configured && !state.captcha.loginToken) {
            setMessage(
                'login-error',
                'Complete the security check before signing in.'
            );
            return;
        }

        setButtonBusy(button, true, 'Signing in...');

        try {
            state.pageControl = sessionControl.acquirePageControl({
                blockOnCancel: false
            });

            if (!state.pageControl.acquired) {
                return;
            }

            const credentials = { email, password };

            if (state.captcha.configured) {
                credentials.options = {
                    captchaToken: state.captcha.loginToken
                };
            }

            const { data, error } =
                await client.auth.signInWithPassword(credentials);

            if (error) {
                throw error;
            }

            state.signedIn = true;

            if (
                registrationVersion(data.user)
                    >= REGISTRATION_SECURITY_VERSION
                && !hasCompletedMobileVerification(data.user)
            ) {
                showMobileVerification(data.user);
                return;
            }

            await enterDashboard();
        } catch (error) {
            if (state.signedIn) {
                await client.auth.signOut({ scope: 'local' });
            }

            sessionControl.releasePageControl();
            state.pageControl = null;
            state.signedIn = false;
            console.error('Login failed:', error);
            setMessage('login-error', safeLoginError(error));
            resetCaptcha('login');
        } finally {
            setButtonBusy(button, false, '');
        }
    }

    function updateRegistrationSourceDetail() {
        const source = byId('registration-source');
        const detailContainer = byId('registration-source-detail-container');
        const detail = byId('registration-source-detail');
        const showDetail = source?.value === 'other';

        detailContainer?.classList.toggle('hidden', !showDetail);

        if (detail) {
            detail.required = showDetail;

            if (!showDetail) {
                detail.value = '';
            }
        }
    }

    function updatePasswordGuidance() {
        const password = byId('pass')?.value || '';
        const guide = byId('password-guidance');

        if (!guide) {
            return;
        }

        if (!password) {
            guide.textContent =
                'Use 12–64 characters with uppercase, lowercase, a number, and a symbol.';
            guide.className = 'mt-1 text-xs text-slate-500';
            return;
        }

        const valid = validation.isValidPassword(password);
        guide.textContent = valid
            ? 'Password meets the security requirements.'
            : 'Password does not yet meet all security requirements.';
        guide.className = valid
            ? 'mt-1 text-xs text-emerald-700'
            : 'mt-1 text-xs text-red-700';
    }

    async function resumePendingVerification() {
        try {
            const { data, error } = await client.auth.getUser();

            if (error || !data.user) {
                return;
            }

            if (
                registrationVersion(data.user)
                    >= REGISTRATION_SECURITY_VERSION
                && data.user.email_confirmed_at
                && !hasCompletedMobileVerification(data.user)
            ) {
                state.signedIn = true;
                showMobileVerification(data.user);
            }
        } catch (error) {
            console.error('Unable to resume verification:', error);
        }
    }

    function bindEvents() {
        byId('btn-show-register')?.addEventListener('click', () => {
            showView('reg-view');
        });
        byId('btn-back-login')?.addEventListener('click', () => {
            showView('login-view');
        });
        byId('btn-login')?.addEventListener('click', handleLogin);
        byId('login-form')?.addEventListener('submit', (event) => {
            event.preventDefault();
            handleLogin();
        });
        byId('btn-register')?.addEventListener('click', handleRegister);
        byId('reg-form')?.addEventListener('submit', (event) => {
            event.preventDefault();
            handleRegister();
        });
        byId('btn-verify-email-otp')?.addEventListener(
            'click',
            verifyEmailOtp
        );
        byId('email-otp-form')?.addEventListener('submit', (event) => {
            event.preventDefault();
            verifyEmailOtp();
        });
        byId('btn-send-mobile-otp')?.addEventListener(
            'click',
            sendMobileOtp
        );
        byId('btn-verify-mobile-otp')?.addEventListener(
            'click',
            verifyMobileOtp
        );
        byId('mobile-otp-form')?.addEventListener('submit', (event) => {
            event.preventDefault();
            verifyMobileOtp();
        });
        document.querySelectorAll('[data-cancel-verification]')
            .forEach((button) => {
                button.addEventListener('click', cancelVerification);
            });
        byId('registration-source')?.addEventListener(
            'change',
            updateRegistrationSourceDetail
        );
        byId('mobile-country-code')?.addEventListener(
            'change',
            updateMobileCallingCode
        );
        byId('country')?.addEventListener(
            'change',
            updateCountrySelection
        );
        document.querySelectorAll('[data-password-toggle]')
            .forEach((button) => {
                button.addEventListener('click', () => {
                    togglePasswordVisibility(button);
                });
            });
        byId('pass')?.addEventListener('input', updatePasswordGuidance);
    }

    document.addEventListener('DOMContentLoaded', () => {
        bindEvents();
        showSessionMessage();
        updateRegistrationSourceDetail();
        updateMobileCallingCode();
        updateCountrySelection();
        resetPasswordVisibility();
        updatePasswordGuidance();
        loadSubjects();
        renderCaptchaWidgets();
        resumePendingVerification();
    });
}(window));
