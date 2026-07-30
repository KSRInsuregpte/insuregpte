-- Expected result: Success. No rows returned.
-- Run after
-- 20260727120000_map_regulatory_metadata_and_exam_information.sql.

DO $verification$
DECLARE
    v_definition text;
    v_subject_count integer;
    v_source_count integer;
    v_current_information_count integer;
BEGIN
    IF pg_catalog.to_regclass(
        'public.regulatory_academic_publications'
    ) IS NULL THEN
        RAISE EXCEPTION 'regulatory_academic_publications is missing';
    END IF;

    IF pg_catalog.to_regprocedure(
        'public.get_exam_information(text,text,text)'
    ) IS NULL THEN
        RAISE EXCEPTION 'get_exam_information RPC is missing';
    END IF;

    SELECT COUNT(*)
    INTO v_subject_count
    FROM public.subjects AS subject_record
    JOIN public.qualification_levels AS qualification
      ON qualification.id = subject_record.qualification_level_id
    JOIN public.training_programmes AS programme
      ON programme.id = subject_record.training_programme_id
    JOIN public.exam_authorities AS authority
      ON authority.id = programme.exam_authority_id
    WHERE pg_catalog.regexp_replace(
        pg_catalog.upper(subject_record.code),
        '[^A-Z0-9]',
        '',
        'g'
    ) IN ('IC01', 'IC02', 'IC11', 'IC14')
      AND pg_catalog.lower(qualification.code) = 'licentiate'
      AND pg_catalog.lower(programme.code) = 'iii_licentiate'
      AND pg_catalog.lower(authority.code) = 'iii';

    IF v_subject_count <> 4 THEN
        RAISE EXCEPTION
            'Expected four mapped pilot subjects; found %',
            v_subject_count;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.subjects AS subject_record
        WHERE pg_catalog.regexp_replace(
            pg_catalog.upper(subject_record.code),
            '[^A-Z0-9]',
            '',
            'g'
        ) = 'IC02'
          AND (
              subject_record.is_active = true
              OR subject_record.is_demo_available = true
              OR subject_record.price <> 0
          )
    ) THEN
        RAISE EXCEPTION
            'IC02 must remain commercially inactive pending content review';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.subjects AS subject_record
        WHERE pg_catalog.regexp_replace(
            pg_catalog.upper(subject_record.code),
            '[^A-Z0-9]',
            '',
            'g'
        ) IN ('IC23', 'IC82')
          AND subject_record.is_active = true
    ) THEN
        RAISE EXCEPTION 'A withdrawn subject is active';
    END IF;

    SELECT COUNT(*)
    INTO v_source_count
    FROM public.regulatory_academic_publications;

    IF v_source_count <> 18 THEN
        RAISE EXCEPTION
            'Expected 18 governed source mappings; found %',
            v_source_count;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.regulatory_academic_publications AS source
        WHERE source.source_document_id =
            'iii-withdrawal-ic23-ic82-2021-11-29'
          AND source.document_type = 'withdrawal_notice'
          AND source.effective_from = date '2022-09-01'
    ) THEN
        RAISE EXCEPTION 'Withdrawal governance source is missing';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns AS columns
        WHERE columns.table_schema = 'public'
          AND columns.table_name = 'regulatory_academic_publications'
          AND columns.column_name IN (
              'archive_path',
              'content',
              'attachment_path'
          )
    ) THEN
        RAISE EXCEPTION
            'The metadata table must not store archive paths or source content';
    END IF;

    IF NOT (
        SELECT classes.relrowsecurity
        FROM pg_catalog.pg_class AS classes
        WHERE classes.oid =
            'public.regulatory_academic_publications'::regclass
    ) THEN
        RAISE EXCEPTION
            'RLS is not enabled on regulatory_academic_publications';
    END IF;

    IF pg_catalog.has_table_privilege(
        'anon',
        'public.regulatory_academic_publications',
        'SELECT'
    ) OR pg_catalog.has_table_privilege(
        'authenticated',
        'public.regulatory_academic_publications',
        'SELECT'
    ) THEN
        RAISE EXCEPTION
            'Browser roles must not read regulatory_academic_publications directly';
    END IF;

    IF pg_catalog.has_function_privilege(
        'anon',
        'public.get_exam_information(text,text,text)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'anon must not execute get_exam_information';
    END IF;

    IF NOT pg_catalog.has_function_privilege(
        'authenticated',
        'public.get_exam_information(text,text,text)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'authenticated cannot execute get_exam_information';
    END IF;

    SELECT pg_catalog.pg_get_functiondef(
        pg_catalog.to_regprocedure(
            'public.get_exam_information(text,text,text)'
        )
    )
    INTO v_definition;

    IF v_definition NOT LIKE '%source.valid_until >= CURRENT_DATE%'
       OR v_definition NOT LIKE
          '%regulatory_academic_publications%' THEN
        RAISE EXCEPTION
            'The RPC is not enforcing current session information';
    END IF;

    SELECT COUNT(*)
    INTO v_current_information_count
    FROM public.get_exam_information('iii', null, 'IC01');

    IF v_current_information_count < 5 THEN
        RAISE EXCEPTION
            'Expected current schedule/centre/language information; found % rows',
            v_current_information_count;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.get_exam_information('iii', 'UNKNOWN', null)
    ) THEN
        RAISE EXCEPTION
            'An unknown session must return no information';
    END IF;
END;
$verification$;
