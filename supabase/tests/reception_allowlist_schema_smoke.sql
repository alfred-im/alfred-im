-- RECEPTION-ALLOWLIST schema smoke (REQ-001–004).

DO $$
BEGIN
  IF to_regclass('public.reception_allowlist') IS NULL THEN
    RAISE EXCEPTION 'Missing table reception_allowlist';
  END IF;

  IF to_regprocedure('public.is_sender_allowed_for_reception(uuid, uuid)') IS NULL THEN
    RAISE EXCEPTION 'Missing function is_sender_allowed_for_reception';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'reception_allowlist'
      AND policyname = 'reception_allowlist_select_own'
  ) THEN
    RAISE EXCEPTION 'Missing RLS policy reception_allowlist_select_own';
  END IF;

  RAISE NOTICE 'reception_allowlist_schema_smoke_ok';
END $$;
