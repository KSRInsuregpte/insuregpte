-- Run after 20260719181000_restrict_profiles_table_privileges.sql.
-- This verification does not modify application data.

DO $verification$
DECLARE
    v_privilege text;
BEGIN
    FOREACH v_privilege IN ARRAY ARRAY[
        'SELECT',
        'INSERT',
        'UPDATE',
        'DELETE',
        'TRUNCATE',
        'REFERENCES',
        'TRIGGER'
    ]
    LOOP
        IF has_table_privilege(
            'anon',
            'public.profiles',
            v_privilege
        ) THEN
            RAISE EXCEPTION
                'anon still has % on public.profiles',
                v_privilege;
        END IF;
    END LOOP;

    IF NOT has_table_privilege(
        'authenticated',
        'public.profiles',
        'SELECT'
    ) THEN
        RAISE EXCEPTION
            'authenticated requires temporary SELECT on public.profiles';
    END IF;

    FOREACH v_privilege IN ARRAY ARRAY[
        'INSERT',
        'UPDATE',
        'DELETE',
        'TRUNCATE',
        'REFERENCES',
        'TRIGGER'
    ]
    LOOP
        IF has_table_privilege(
            'authenticated',
            'public.profiles',
            v_privilege
        ) THEN
            RAISE EXCEPTION
                'authenticated still has % on public.profiles',
                v_privilege;
        END IF;
    END LOOP;
END;
$verification$;
