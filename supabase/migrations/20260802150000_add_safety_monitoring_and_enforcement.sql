-- Add privacy-safe safety monitoring, controlled learner enforcement, and a
-- notification outbox after the live duplicate-object audit was reviewed.
--
-- This migration deliberately reuses profiles, active_client_leases, and
-- admin_audit_events. It does not replace Supabase Auth, alter existing RPC
-- signatures, store request tokens, store full IP addresses, or copy quiz
-- questions and answers into safety records.
--
-- Rollback:
-- supabase/rollbacks/20260802150000_add_safety_monitoring_and_enforcement.sql

DO $guard$
BEGIN
    IF to_regclass('public.profiles') IS NULL
       OR to_regclass('public.active_client_leases') IS NULL
       OR to_regclass('public.admin_audit_events') IS NULL
       OR to_regprocedure('public.fn_is_admin()') IS NULL
       OR to_regprocedure('public.admin_set_user_status(uuid,text)') IS NULL
       OR to_regprocedure('public.fn_enforce_active_auth_session()') IS NULL THEN
        RAISE EXCEPTION
            'Deploy the existing profile, active-client, and admin migrations before the safety system';
    END IF;

    IF to_regclass('public.security_events') IS NOT NULL
       OR to_regclass('public.account_enforcement_cases') IS NOT NULL
       OR to_regclass('public.notification_outbox') IS NOT NULL THEN
        RAISE EXCEPTION
            'A safety-system relation already exists; review the live object audit before continuing';
    END IF;
END;
$guard$;

CREATE TABLE public.security_events (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_type text NOT NULL,
    severity text NOT NULL DEFAULT 'medium',
    status text NOT NULL DEFAULT 'open',
    user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    source text NOT NULL,
    dedupe_key text UNIQUE,
    evidence_summary jsonb NOT NULL DEFAULT '{}'::jsonb,
    recommended_action text,
    occurred_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    last_seen_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    occurrence_count integer NOT NULL DEFAULT 1,
    reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    reviewed_at timestamptz,
    review_note text,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT chk_security_events_type CHECK (
        event_type IN (
            'registration_confirmed',
            'long_running_session',
            'service_pressure',
            'auth_anomaly',
            'content_manipulation',
            'quiz_manipulation',
            'critical_attack'
        )
    ),
    CONSTRAINT chk_security_events_severity CHECK (
        severity IN ('info', 'low', 'medium', 'high', 'critical')
    ),
    CONSTRAINT chk_security_events_status CHECK (
        status IN (
            'open',
            'under_review',
            'dismissed',
            'actioned',
            'resolved'
        )
    ),
    CONSTRAINT chk_security_events_evidence_object CHECK (
        jsonb_typeof(evidence_summary) = 'object'
    ),
    CONSTRAINT chk_security_events_occurrence_count CHECK (
        occurrence_count >= 1
    ),
    CONSTRAINT chk_security_events_review_state CHECK (
        (reviewed_at IS NULL AND reviewed_by IS NULL)
        OR (reviewed_at IS NOT NULL AND reviewed_by IS NOT NULL)
    )
);

CREATE TABLE public.account_enforcement_cases (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    opened_from_event_id bigint REFERENCES public.security_events(id)
        ON DELETE SET NULL,
    status text NOT NULL DEFAULT 'monitoring',
    warning_count smallint NOT NULL DEFAULT 0,
    reason_code text NOT NULL,
    reason_summary text NOT NULL,
    opened_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    last_action_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    suspended_until timestamptz,
    resolved_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT chk_account_enforcement_cases_status CHECK (
        status IN ('monitoring', 'warned', 'suspended', 'restored', 'closed')
    ),
    CONSTRAINT chk_account_enforcement_cases_warning_count CHECK (
        warning_count BETWEEN 0 AND 3
    ),
    CONSTRAINT chk_account_enforcement_cases_reason CHECK (
        NULLIF(btrim(reason_code), '') IS NOT NULL
        AND NULLIF(btrim(reason_summary), '') IS NOT NULL
    )
);

CREATE UNIQUE INDEX uq_account_enforcement_cases_open_user
ON public.account_enforcement_cases (user_id)
WHERE status IN ('monitoring', 'warned', 'suspended');

CREATE TABLE public.notification_outbox (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    notification_type text NOT NULL,
    channel text NOT NULL,
    recipient_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    recipient_role text,
    related_security_event_id bigint REFERENCES public.security_events(id)
        ON DELETE SET NULL,
    related_enforcement_case_id bigint
        REFERENCES public.account_enforcement_cases(id) ON DELETE SET NULL,
    subject text NOT NULL,
    message_body text NOT NULL,
    safe_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    dedupe_key text NOT NULL UNIQUE,
    status text NOT NULL DEFAULT 'pending',
    attempt_count smallint NOT NULL DEFAULT 0,
    available_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    locked_at timestamptz,
    completed_at timestamptz,
    last_error text,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT chk_notification_outbox_type CHECK (
        notification_type IN (
            'admin_alert',
            'user_warning',
            'user_suspension',
            'user_restoration'
        )
    ),
    CONSTRAINT chk_notification_outbox_channel CHECK (
        channel IN ('dashboard', 'email')
    ),
    CONSTRAINT chk_notification_outbox_recipient CHECK (
        (recipient_user_id IS NOT NULL AND recipient_role IS NULL)
        OR (recipient_user_id IS NULL AND recipient_role = 'admin')
    ),
    CONSTRAINT chk_notification_outbox_payload_object CHECK (
        jsonb_typeof(safe_payload) = 'object'
    ),
    CONSTRAINT chk_notification_outbox_status CHECK (
        status IN ('pending', 'processing', 'sent', 'failed', 'cancelled')
    ),
    CONSTRAINT chk_notification_outbox_attempt_count CHECK (
        attempt_count BETWEEN 0 AND 5
    )
);

CREATE INDEX idx_security_events_review_queue
ON public.security_events (status, severity, occurred_at DESC);

CREATE INDEX idx_security_events_user_time
ON public.security_events (user_id, occurred_at DESC)
WHERE user_id IS NOT NULL;

CREATE INDEX idx_account_enforcement_cases_status_time
ON public.account_enforcement_cases (status, updated_at DESC);

CREATE INDEX idx_notification_outbox_delivery_queue
ON public.notification_outbox (channel, status, available_at, id)
WHERE status IN ('pending', 'failed');

ALTER TABLE public.security_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_enforcement_cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_outbox ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.security_events
FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE public.account_enforcement_cases
FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE public.notification_outbox
FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON SEQUENCE public.security_events_id_seq
FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON SEQUENCE public.account_enforcement_cases_id_seq
FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON SEQUENCE public.notification_outbox_id_seq
FROM PUBLIC, anon, authenticated, service_role;

ALTER TABLE public.admin_audit_events
DROP CONSTRAINT admin_audit_events_entity_type_check;

ALTER TABLE public.admin_audit_events
ADD CONSTRAINT admin_audit_events_entity_type_check CHECK (
    entity_type = ANY (ARRAY[
        'subject'::text,
        'question'::text,
        'user'::text,
        'exam_information'::text,
        'qualification_levels'::text,
        'exam_authorities'::text,
        'training_programmes'::text,
        'programme_sections'::text,
        'modules'::text,
        'chapters'::text,
        'topics'::text,
        'learning_resource_types'::text,
        'learning_resources'::text,
        'flashcards'::text,
        'entitlement'::text,
        'security_event'::text,
        'enforcement_case'::text,
        'notification_outbox'::text
    ])
);

CREATE FUNCTION public.fn_insert_security_event(
    p_event_type text,
    p_severity text,
    p_user_id uuid,
    p_source text,
    p_dedupe_key text,
    p_evidence_summary jsonb,
    p_recommended_action text,
    p_occurred_at timestamptz DEFAULT clock_timestamp()
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_event_id bigint;
BEGIN
    INSERT INTO public.security_events (
        event_type,
        severity,
        user_id,
        source,
        dedupe_key,
        evidence_summary,
        recommended_action,
        occurred_at,
        last_seen_at,
        updated_at
    )
    VALUES (
        lower(btrim(p_event_type)),
        lower(btrim(p_severity)),
        p_user_id,
        left(btrim(p_source), 100),
        nullif(left(btrim(coalesce(p_dedupe_key, '')), 240), ''),
        coalesce(p_evidence_summary, '{}'::jsonb),
        nullif(left(btrim(coalesce(p_recommended_action, '')), 1000), ''),
        coalesce(p_occurred_at, clock_timestamp()),
        clock_timestamp()
    )
    ON CONFLICT (dedupe_key) DO UPDATE
    SET last_seen_at = clock_timestamp(),
        occurrence_count = public.security_events.occurrence_count + 1,
        evidence_summary = EXCLUDED.evidence_summary,
        updated_at = clock_timestamp()
    RETURNING id INTO v_event_id;

    RETURN v_event_id;
END;
$function$;

CREATE FUNCTION public.fn_queue_safety_notification(
    p_notification_type text,
    p_channel text,
    p_recipient_user_id uuid,
    p_recipient_role text,
    p_security_event_id bigint,
    p_enforcement_case_id bigint,
    p_subject text,
    p_message_body text,
    p_safe_payload jsonb,
    p_dedupe_key text
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_notification_id bigint;
BEGIN
    INSERT INTO public.notification_outbox (
        notification_type,
        channel,
        recipient_user_id,
        recipient_role,
        related_security_event_id,
        related_enforcement_case_id,
        subject,
        message_body,
        safe_payload,
        dedupe_key
    )
    VALUES (
        lower(btrim(p_notification_type)),
        lower(btrim(p_channel)),
        p_recipient_user_id,
        nullif(lower(btrim(coalesce(p_recipient_role, ''))), ''),
        p_security_event_id,
        p_enforcement_case_id,
        left(btrim(p_subject), 200),
        left(btrim(p_message_body), 2000),
        coalesce(p_safe_payload, '{}'::jsonb),
        left(btrim(p_dedupe_key), 240)
    )
    ON CONFLICT (dedupe_key) DO NOTHING
    RETURNING id INTO v_notification_id;

    IF v_notification_id IS NULL THEN
        SELECT notification.id
        INTO v_notification_id
        FROM public.notification_outbox AS notification
        WHERE notification.dedupe_key = left(btrim(p_dedupe_key), 240);
    END IF;

    RETURN v_notification_id;
END;
$function$;

CREATE FUNCTION public.fn_queue_account_activation_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_event_id bigint;
BEGIN
    IF NEW.status = 'active'
       AND OLD.status = 'verification_pending' THEN
        v_event_id := public.fn_insert_security_event(
            'registration_confirmed',
            'info',
            NEW.id,
            'profile_activation',
            'registration_confirmed:' || NEW.id::text,
            jsonb_build_object(
                'registration_security_version',
                NEW.registration_security_version
            ),
            'No enforcement action is recommended. Review only if the registration is unexpected.',
            clock_timestamp()
        );

        PERFORM public.fn_queue_safety_notification(
            'admin_alert',
            'email',
            NULL,
            'admin',
            v_event_id,
            NULL,
            'InsureGPTE registration confirmed',
            'A learner completed email verification and the account became active. Review the Security & Alerts panel for the audited record.',
            jsonb_build_object('event_type', 'registration_confirmed'),
            'admin:registration_confirmed:' || NEW.id::text
        );
    END IF;

    RETURN NEW;
END;
$function$;

CREATE TRIGGER trg_profiles_queue_activation_notification
AFTER UPDATE OF status ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.fn_queue_account_activation_notification();

CREATE FUNCTION public.fn_scan_long_running_sessions()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_actor uuid := auth.uid();
    v_lease record;
    v_event_id bigint;
    v_count integer := 0;
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;

    FOR v_lease IN
        SELECT
            lease.user_id,
            lease.claimed_at,
            lease.last_seen_at
        FROM public.active_client_leases AS lease
        WHERE lease.expires_at > clock_timestamp()
          AND lease.claimed_at <= clock_timestamp() - interval '48 hours'
    LOOP
        v_event_id := public.fn_insert_security_event(
            'long_running_session',
            'medium',
            v_lease.user_id,
            'active_client_lease_scan',
            'long_running_session:' || v_lease.user_id::text || ':'
                || extract(epoch from v_lease.claimed_at)::bigint::text,
            jsonb_build_object(
                'claimed_at', v_lease.claimed_at,
                'last_seen_at', v_lease.last_seen_at,
                'threshold_hours', 48
            ),
            'Confirm whether the sustained login is expected before issuing a warning.',
            v_lease.claimed_at
        );

        PERFORM public.fn_queue_safety_notification(
            'admin_alert',
            'email',
            NULL,
            'admin',
            v_event_id,
            NULL,
            'InsureGPTE session active for more than 48 hours',
            'A continuously active learner session crossed the 48-hour review threshold. Review the Security & Alerts panel before taking action.',
            jsonb_build_object('event_type', 'long_running_session'),
            'admin:long_running_session:' || v_event_id::text
        );

        v_count := v_count + 1;
    END LOOP;

    INSERT INTO public.admin_audit_events (
        actor_user_id,
        action,
        entity_type,
        entity_key,
        change_summary
    )
    VALUES (
        v_actor,
        'update',
        'security_event',
        'long_session_scan',
        jsonb_build_object('qualifying_sessions', v_count)
    );

    RETURN v_count;
END;
$function$;

CREATE FUNCTION public.record_security_event(
    p_event_type text,
    p_severity text,
    p_user_id uuid,
    p_source text,
    p_dedupe_key text,
    p_evidence_summary jsonb DEFAULT '{}'::jsonb,
    p_recommended_action text DEFAULT NULL,
    p_occurred_at timestamptz DEFAULT clock_timestamp()
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_event_type text := lower(btrim(coalesce(p_event_type, '')));
    v_event_id bigint;
BEGIN
    IF v_event_type NOT IN (
        'service_pressure',
        'auth_anomaly',
        'content_manipulation',
        'quiz_manipulation',
        'critical_attack'
    ) THEN
        RAISE EXCEPTION
            'The service-side event type is not supported.';
    END IF;

    v_event_id := public.fn_insert_security_event(
        v_event_type,
        p_severity,
        p_user_id,
        p_source,
        p_dedupe_key,
        p_evidence_summary,
        p_recommended_action,
        p_occurred_at
    );

    PERFORM public.fn_queue_safety_notification(
        'admin_alert',
        'email',
        NULL,
        'admin',
        v_event_id,
        NULL,
        'InsureGPTE safety alert: '
            || replace(initcap(v_event_type), '_', ' '),
        'A trusted server-side monitor recorded a safety event. Review the Security & Alerts panel before taking action.',
        jsonb_build_object(
            'event_type', v_event_type,
            'severity', lower(btrim(p_severity))
        ),
        'admin:service_event:' || v_event_id::text
    );

    RETURN v_event_id;
END;
$function$;

CREATE FUNCTION public.get_admin_security_summary()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;

    RETURN jsonb_build_object(
        'open_events', (
            SELECT count(*)
            FROM public.security_events AS event
            WHERE event.status IN ('open', 'under_review')
        ),
        'critical_events', (
            SELECT count(*)
            FROM public.security_events AS event
            WHERE event.status IN ('open', 'under_review')
              AND event.severity = 'critical'
        ),
        'active_cases', (
            SELECT count(*)
            FROM public.account_enforcement_cases AS enforcement
            WHERE enforcement.status IN ('monitoring', 'warned', 'suspended')
        ),
        'suspended_users', (
            SELECT count(*)
            FROM public.account_enforcement_cases AS enforcement
            WHERE enforcement.status = 'suspended'
        ),
        'sessions_over_48_hours', (
            SELECT count(*)
            FROM public.active_client_leases AS lease
            WHERE lease.expires_at > clock_timestamp()
              AND lease.claimed_at <= clock_timestamp() - interval '48 hours'
        ),
        'pending_email_notifications', (
            SELECT count(*)
            FROM public.notification_outbox AS notification
            WHERE notification.channel = 'email'
              AND notification.status IN ('pending', 'failed')
        )
    );
END;
$function$;

CREATE FUNCTION public.admin_list_security_events(
    p_limit integer DEFAULT 100
)
RETURNS TABLE (
    event_id bigint,
    event_type text,
    severity text,
    status text,
    user_id uuid,
    user_email text,
    user_name text,
    source text,
    evidence_summary jsonb,
    recommended_action text,
    occurred_at timestamptz,
    last_seen_at timestamptz,
    occurrence_count integer,
    review_note text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;

    RETURN QUERY
    SELECT
        event.id,
        event.event_type,
        event.severity,
        event.status,
        event.user_id,
        auth_user.email::text,
        nullif(btrim(concat_ws(
            ' ',
            profile.first_name,
            profile.last_name
        )), ''),
        event.source,
        event.evidence_summary,
        event.recommended_action,
        event.occurred_at,
        event.last_seen_at,
        event.occurrence_count,
        event.review_note
    FROM public.security_events AS event
    LEFT JOIN auth.users AS auth_user
      ON auth_user.id = event.user_id
    LEFT JOIN public.profiles AS profile
      ON profile.id = event.user_id
    ORDER BY
        CASE event.severity
            WHEN 'critical' THEN 1
            WHEN 'high' THEN 2
            WHEN 'medium' THEN 3
            WHEN 'low' THEN 4
            ELSE 5
        END,
        event.occurred_at DESC
    LIMIT least(greatest(coalesce(p_limit, 100), 1), 200);
END;
$function$;

CREATE FUNCTION public.admin_review_security_event(
    p_event_id bigint,
    p_decision text,
    p_note text DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_actor uuid := auth.uid();
    v_decision text := lower(btrim(coalesce(p_decision, '')));
    v_event public.security_events%ROWTYPE;
    v_case_id bigint;
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;

    IF v_decision NOT IN ('dismiss', 'open_case', 'resolve') THEN
        RAISE EXCEPTION 'Decision must be dismiss, open_case, or resolve.';
    END IF;

    SELECT * INTO v_event
    FROM public.security_events AS event
    WHERE event.id = p_event_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'The selected security event was not found.';
    END IF;

    IF v_decision = 'open_case' AND v_event.user_id IS NULL THEN
        RAISE EXCEPTION
            'This event is not linked to a learner account and cannot open an enforcement case.';
    END IF;

    IF v_decision = 'open_case'
       AND (
           v_event.severity = 'info'
           OR v_event.event_type = 'registration_confirmed'
       ) THEN
        RAISE EXCEPTION
            'Informational registration events cannot open learner enforcement cases.';
    END IF;

    IF v_decision = 'open_case' THEN
        SELECT enforcement.id INTO v_case_id
        FROM public.account_enforcement_cases AS enforcement
        WHERE enforcement.user_id = v_event.user_id
          AND enforcement.status IN ('monitoring', 'warned', 'suspended')
        FOR UPDATE;

        IF v_case_id IS NULL THEN
            INSERT INTO public.account_enforcement_cases (
                user_id,
                opened_from_event_id,
                reason_code,
                reason_summary,
                opened_by,
                last_action_by
            )
            VALUES (
                v_event.user_id,
                v_event.id,
                v_event.event_type,
                coalesce(
                    nullif(btrim(p_note), ''),
                    v_event.recommended_action,
                    'Administrator review required.'
                ),
                v_actor,
                v_actor
            )
            RETURNING id INTO v_case_id;
        END IF;

        UPDATE public.security_events
        SET status = 'actioned',
            reviewed_by = v_actor,
            reviewed_at = clock_timestamp(),
            review_note = nullif(left(btrim(coalesce(p_note, '')), 1000), ''),
            updated_at = clock_timestamp()
        WHERE id = v_event.id;
    ELSE
        UPDATE public.security_events
        SET status = CASE
                WHEN v_decision = 'dismiss' THEN 'dismissed'
                ELSE 'resolved'
            END,
            reviewed_by = v_actor,
            reviewed_at = clock_timestamp(),
            review_note = nullif(left(btrim(coalesce(p_note, '')), 1000), ''),
            updated_at = clock_timestamp()
        WHERE id = v_event.id;
    END IF;

    INSERT INTO public.admin_audit_events (
        actor_user_id,
        action,
        entity_type,
        entity_key,
        change_summary
    )
    VALUES (
        v_actor,
        CASE WHEN v_decision = 'open_case' THEN 'create' ELSE 'update' END,
        'security_event',
        v_event.id::text,
        jsonb_build_object(
            'decision', v_decision,
            'case_id', v_case_id
        )
    );

    RETURN v_case_id;
END;
$function$;

CREATE FUNCTION public.admin_list_enforcement_cases(
    p_limit integer DEFAULT 100
)
RETURNS TABLE (
    case_id bigint,
    user_id uuid,
    user_email text,
    user_name text,
    status text,
    warning_count smallint,
    reason_code text,
    reason_summary text,
    source_severity text,
    suspended_until timestamptz,
    created_at timestamptz,
    updated_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;

    RETURN QUERY
    SELECT
        enforcement.id,
        enforcement.user_id,
        auth_user.email::text,
        nullif(btrim(concat_ws(
            ' ',
            profile.first_name,
            profile.last_name
        )), ''),
        enforcement.status,
        enforcement.warning_count,
        enforcement.reason_code,
        enforcement.reason_summary,
        source_event.severity,
        enforcement.suspended_until,
        enforcement.created_at,
        enforcement.updated_at
    FROM public.account_enforcement_cases AS enforcement
    JOIN auth.users AS auth_user
      ON auth_user.id = enforcement.user_id
    JOIN public.profiles AS profile
      ON profile.id = enforcement.user_id
    LEFT JOIN public.security_events AS source_event
      ON source_event.id = enforcement.opened_from_event_id
    ORDER BY
        CASE enforcement.status
            WHEN 'suspended' THEN 1
            WHEN 'warned' THEN 2
            WHEN 'monitoring' THEN 3
            ELSE 4
        END,
        enforcement.updated_at DESC
    LIMIT least(greatest(coalesce(p_limit, 100), 1), 200);
END;
$function$;

CREATE FUNCTION public.admin_issue_security_warning(
    p_case_id bigint,
    p_message text
)
RETURNS smallint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_actor uuid := auth.uid();
    v_case public.account_enforcement_cases%ROWTYPE;
    v_user_role text;
    v_warning_count smallint;
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;

    IF nullif(btrim(coalesce(p_message, '')), '') IS NULL THEN
        RAISE EXCEPTION 'A clear learner-facing warning message is required.';
    END IF;

    SELECT enforcement.*
    INTO v_case
    FROM public.account_enforcement_cases AS enforcement
    WHERE enforcement.id = p_case_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'The selected enforcement case was not found.';
    END IF;

    SELECT profile.role
    INTO v_user_role
    FROM public.profiles AS profile
    WHERE profile.id = v_case.user_id
    FOR UPDATE;

    IF v_user_role = 'admin' THEN
        RAISE EXCEPTION 'Administrator accounts cannot receive learner enforcement actions.';
    END IF;

    IF v_case.status NOT IN ('monitoring', 'warned') THEN
        RAISE EXCEPTION 'Warnings cannot be added in the current case status.';
    END IF;

    IF v_case.warning_count >= 3 THEN
        RAISE EXCEPTION 'The maximum of three confirmed warnings has already been reached.';
    END IF;

    UPDATE public.account_enforcement_cases
    SET warning_count = warning_count + 1,
        status = 'warned',
        reason_summary = left(btrim(p_message), 1000),
        last_action_by = v_actor,
        updated_at = clock_timestamp()
    WHERE id = v_case.id
    RETURNING warning_count INTO v_warning_count;

    PERFORM public.fn_queue_safety_notification(
        'user_warning',
        'dashboard',
        v_case.user_id,
        NULL,
        v_case.opened_from_event_id,
        v_case.id,
        'InsureGPTE account warning',
        left(btrim(p_message), 1000),
        jsonb_build_object('warning_number', v_warning_count),
        'user:warning:dashboard:' || v_case.id::text || ':'
            || v_warning_count::text
    );

    PERFORM public.fn_queue_safety_notification(
        'user_warning',
        'email',
        v_case.user_id,
        NULL,
        v_case.opened_from_event_id,
        v_case.id,
        'InsureGPTE account warning',
        left(btrim(p_message), 1000),
        jsonb_build_object('warning_number', v_warning_count),
        'user:warning:email:' || v_case.id::text || ':'
            || v_warning_count::text
    );

    INSERT INTO public.admin_audit_events (
        actor_user_id,
        action,
        entity_type,
        entity_key,
        change_summary
    )
    VALUES (
        v_actor,
        'status_change',
        'enforcement_case',
        v_case.id::text,
        jsonb_build_object(
            'new_status', 'warned',
            'warning_count', v_warning_count
        )
    );

    RETURN v_warning_count;
END;
$function$;

CREATE FUNCTION public.admin_suspend_user_access(
    p_case_id bigint,
    p_reason text,
    p_suspended_until timestamptz DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_actor uuid := auth.uid();
    v_case public.account_enforcement_cases%ROWTYPE;
    v_user_role text;
    v_source_severity text;
    v_source_type text;
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;

    IF nullif(btrim(coalesce(p_reason, '')), '') IS NULL THEN
        RAISE EXCEPTION 'A suspension reason is required.';
    END IF;

    SELECT enforcement.*
    INTO v_case
    FROM public.account_enforcement_cases AS enforcement
    WHERE enforcement.id = p_case_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'The selected enforcement case was not found.';
    END IF;

    SELECT profile.role
    INTO v_user_role
    FROM public.profiles AS profile
    WHERE profile.id = v_case.user_id
    FOR UPDATE;

    SELECT source_event.severity, source_event.event_type
    INTO v_source_severity, v_source_type
    FROM public.security_events AS source_event
    WHERE source_event.id = v_case.opened_from_event_id;

    IF v_user_role = 'admin' THEN
        RAISE EXCEPTION 'Administrator accounts cannot be suspended through learner enforcement.';
    END IF;

    IF v_case.status NOT IN ('monitoring', 'warned') THEN
        RAISE EXCEPTION 'The case cannot be suspended in its current status.';
    END IF;

    IF v_case.warning_count < 3
       AND coalesce(v_source_severity, '') <> 'critical'
       AND coalesce(v_source_type, '') <> 'critical_attack' THEN
        RAISE EXCEPTION
            'Three confirmed warnings are required unless the linked event is critical.';
    END IF;

    UPDATE public.profiles
    SET status = 'suspended'
    WHERE id = v_case.user_id;

    DELETE FROM public.active_client_leases
    WHERE user_id = v_case.user_id;

    UPDATE public.account_enforcement_cases
    SET status = 'suspended',
        reason_summary = left(btrim(p_reason), 1000),
        suspended_until = p_suspended_until,
        last_action_by = v_actor,
        updated_at = clock_timestamp()
    WHERE id = v_case.id;

    PERFORM public.fn_queue_safety_notification(
        'user_suspension',
        'email',
        v_case.user_id,
        NULL,
        v_case.opened_from_event_id,
        v_case.id,
        'InsureGPTE account access suspended',
        left(btrim(p_reason), 1000)
            || ' Contact the InsureGPTE administrator by email if you wish to request a review.',
        jsonb_build_object('suspended_until', p_suspended_until),
        'user:suspension:email:' || v_case.id::text
    );

    INSERT INTO public.admin_audit_events (
        actor_user_id,
        action,
        entity_type,
        entity_key,
        change_summary
    )
    VALUES (
        v_actor,
        'status_change',
        'enforcement_case',
        v_case.id::text,
        jsonb_build_object(
            'new_status', 'suspended',
            'warning_count', v_case.warning_count,
            'critical_override', (
                coalesce(v_source_severity, '') = 'critical'
                OR coalesce(v_source_type, '') = 'critical_attack'
            ),
            'suspended_until', p_suspended_until
        )
    );
END;
$function$;

CREATE FUNCTION public.admin_restore_user_access(
    p_case_id bigint,
    p_note text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_actor uuid := auth.uid();
    v_case public.account_enforcement_cases%ROWTYPE;
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;

    IF nullif(btrim(coalesce(p_note, '')), '') IS NULL THEN
        RAISE EXCEPTION 'A restoration note is required.';
    END IF;

    SELECT * INTO v_case
    FROM public.account_enforcement_cases AS enforcement
    WHERE enforcement.id = p_case_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'The selected enforcement case was not found.';
    END IF;

    IF v_case.status <> 'suspended' THEN
        RAISE EXCEPTION 'Only a suspended case can restore access.';
    END IF;

    UPDATE public.profiles
    SET status = 'active'
    WHERE id = v_case.user_id;

    UPDATE public.account_enforcement_cases
    SET status = 'restored',
        reason_summary = left(btrim(p_note), 1000),
        suspended_until = NULL,
        resolved_at = clock_timestamp(),
        last_action_by = v_actor,
        updated_at = clock_timestamp()
    WHERE id = v_case.id;

    PERFORM public.fn_queue_safety_notification(
        'user_restoration',
        'email',
        v_case.user_id,
        NULL,
        v_case.opened_from_event_id,
        v_case.id,
        'InsureGPTE account access restored',
        left(btrim(p_note), 1000),
        '{}'::jsonb,
        'user:restoration:email:' || v_case.id::text
    );

    INSERT INTO public.admin_audit_events (
        actor_user_id,
        action,
        entity_type,
        entity_key,
        change_summary
    )
    VALUES (
        v_actor,
        'status_change',
        'enforcement_case',
        v_case.id::text,
        jsonb_build_object('new_status', 'restored')
    );
END;
$function$;

CREATE FUNCTION public.admin_list_notification_outbox(
    p_limit integer DEFAULT 100
)
RETURNS TABLE (
    notification_id bigint,
    notification_type text,
    channel text,
    recipient_kind text,
    subject text,
    status text,
    attempt_count smallint,
    available_at timestamptz,
    completed_at timestamptz,
    last_error text,
    created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
    IF NOT public.fn_is_admin() THEN
        RAISE SQLSTATE 'PT403'
            USING MESSAGE = 'Administrator access is required.';
    END IF;

    RETURN QUERY
    SELECT
        notification.id,
        notification.notification_type,
        notification.channel,
        CASE
            WHEN notification.recipient_role = 'admin' THEN 'Administrators'
            ELSE 'Learner'
        END,
        notification.subject,
        notification.status,
        notification.attempt_count,
        notification.available_at,
        notification.completed_at,
        notification.last_error,
        notification.created_at
    FROM public.notification_outbox AS notification
    ORDER BY notification.created_at DESC
    LIMIT least(greatest(coalesce(p_limit, 100), 1), 200);
END;
$function$;

CREATE FUNCTION public.get_my_security_notices(
    p_limit integer DEFAULT 10
)
RETURNS TABLE (
    notification_id bigint,
    notification_type text,
    subject text,
    message_body text,
    created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id uuid := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE SQLSTATE 'PT401'
            USING MESSAGE = 'Authentication required.';
    END IF;

    RETURN QUERY
    SELECT
        notification.id,
        notification.notification_type,
        notification.subject,
        notification.message_body,
        notification.created_at
    FROM public.notification_outbox AS notification
    WHERE notification.recipient_user_id = v_user_id
      AND notification.channel = 'dashboard'
      AND notification.status IN ('pending', 'failed')
    ORDER BY notification.created_at DESC
    LIMIT least(greatest(coalesce(p_limit, 10), 1), 20);
END;
$function$;

CREATE FUNCTION public.acknowledge_my_security_notice(
    p_notification_id bigint
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id uuid := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE SQLSTATE 'PT401'
            USING MESSAGE = 'Authentication required.';
    END IF;

    UPDATE public.notification_outbox AS notification
    SET status = 'sent',
        completed_at = clock_timestamp(),
        updated_at = clock_timestamp()
    WHERE notification.id = p_notification_id
      AND notification.recipient_user_id = v_user_id
      AND notification.channel = 'dashboard'
      AND notification.status IN ('pending', 'failed');

    RETURN FOUND;
END;
$function$;

CREATE FUNCTION public.claim_notification_outbox(
    p_limit integer DEFAULT 20
)
RETURNS TABLE (
    notification_id bigint,
    recipient_emails text[],
    subject text,
    message_body text,
    safe_payload jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
    RETURN QUERY
    WITH candidates AS (
        SELECT notification.id
        FROM public.notification_outbox AS notification
        WHERE notification.channel = 'email'
          AND notification.status IN ('pending', 'failed')
          AND notification.available_at <= clock_timestamp()
          AND notification.attempt_count < 5
        ORDER BY notification.available_at, notification.id
        FOR UPDATE SKIP LOCKED
        LIMIT least(greatest(coalesce(p_limit, 20), 1), 50)
    ),
    claimed AS (
        UPDATE public.notification_outbox AS notification
        SET status = 'processing',
            locked_at = clock_timestamp(),
            attempt_count = notification.attempt_count + 1,
            updated_at = clock_timestamp()
        FROM candidates
        WHERE notification.id = candidates.id
        RETURNING notification.*
    )
    SELECT
        claimed.id,
        CASE
            WHEN claimed.recipient_role = 'admin' THEN ARRAY(
                SELECT auth_user.email::text
                FROM public.profiles AS profile
                JOIN auth.users AS auth_user
                  ON auth_user.id = profile.id
                WHERE profile.role = 'admin'
                  AND profile.status = 'active'
                  AND auth_user.email IS NOT NULL
                ORDER BY auth_user.email
            )
            ELSE ARRAY(
                SELECT auth_user.email::text
                FROM auth.users AS auth_user
                WHERE auth_user.id = claimed.recipient_user_id
                  AND auth_user.email IS NOT NULL
            )
        END,
        claimed.subject,
        claimed.message_body,
        claimed.safe_payload
    FROM claimed;
END;
$function$;

CREATE FUNCTION public.complete_notification_outbox(
    p_notification_id bigint,
    p_success boolean,
    p_error text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
    UPDATE public.notification_outbox AS notification
    SET status = CASE WHEN p_success THEN 'sent' ELSE 'failed' END,
        completed_at = CASE
            WHEN p_success THEN clock_timestamp()
            ELSE NULL
        END,
        available_at = CASE
            WHEN p_success THEN notification.available_at
            ELSE clock_timestamp()
                + make_interval(mins => least(notification.attempt_count * 5, 60))
        END,
        locked_at = NULL,
        last_error = CASE
            WHEN p_success THEN NULL
            ELSE nullif(left(btrim(coalesce(p_error, 'Delivery failed')), 500), '')
        END,
        updated_at = clock_timestamp()
    WHERE notification.id = p_notification_id
      AND notification.status = 'processing';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'The notification is not currently claimed.';
    END IF;
END;
$function$;

COMMENT ON TABLE public.security_events IS
    'Privacy-safe safety signals for administrator review; excludes secrets, raw Auth payloads, full IP addresses, and quiz answers.';
COMMENT ON TABLE public.account_enforcement_cases IS
    'Controlled learner warning, suspension, and restoration workflow with a three-warning maximum.';
COMMENT ON TABLE public.notification_outbox IS
    'Durable dashboard and email notification queue. Recipient email addresses are resolved only by the service-role claim RPC.';
COMMENT ON FUNCTION public.fn_scan_long_running_sessions() IS
    'Creates reviewable alerts for unexpired active-client leases continuously claimed for more than 48 hours.';
COMMENT ON FUNCTION public.admin_suspend_user_access(bigint,text,timestamptz) IS
    'Suspends a non-admin learner only after three confirmed warnings or a linked critical event.';
COMMENT ON FUNCTION public.claim_notification_outbox(integer) IS
    'Service-role-only claim operation for a separately configured email delivery worker.';
COMMENT ON FUNCTION public.record_security_event(
    text,text,uuid,text,text,jsonb,text,timestamptz
) IS
    'Service-role-only ingestion endpoint for approved provider monitors; evidence must remain privacy-safe.';

REVOKE ALL ON FUNCTION public.fn_insert_security_event(
    text,text,uuid,text,text,jsonb,text,timestamptz
) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.fn_queue_safety_notification(
    text,text,uuid,text,bigint,bigint,text,text,jsonb,text
) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.fn_queue_account_activation_notification()
FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.fn_scan_long_running_sessions()
FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.record_security_event(
    text,text,uuid,text,text,jsonb,text,timestamptz
) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_admin_security_summary()
FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.admin_list_security_events(integer)
FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.admin_review_security_event(bigint,text,text)
FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.admin_list_enforcement_cases(integer)
FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.admin_issue_security_warning(bigint,text)
FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.admin_suspend_user_access(
    bigint,text,timestamptz
) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.admin_restore_user_access(bigint,text)
FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.admin_list_notification_outbox(integer)
FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_my_security_notices(integer)
FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.acknowledge_my_security_notice(bigint)
FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.claim_notification_outbox(integer)
FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.complete_notification_outbox(
    bigint,boolean,text
) FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.fn_scan_long_running_sessions()
TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_security_event(
    text,text,uuid,text,text,jsonb,text,timestamptz
) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_admin_security_summary()
TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_security_events(integer)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_security_event(bigint,text,text)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_enforcement_cases(integer)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_issue_security_warning(bigint,text)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_suspend_user_access(
    bigint,text,timestamptz
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_restore_user_access(bigint,text)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_notification_outbox(integer)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_security_notices(integer)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.acknowledge_my_security_notice(bigint)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_notification_outbox(integer)
TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_notification_outbox(
    bigint,boolean,text
) TO service_role;

NOTIFY pgrst, 'reload schema';
