-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- RECEPTION-ALLOWLIST schema smoke (address-based).

DO $$
BEGIN
  IF to_regclass('public.reception_allowlist') IS NULL THEN
    RAISE EXCEPTION 'Missing table reception_allowlist';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'reception_allowlist'
      AND column_name = 'allowed_address'
  ) THEN
    RAISE EXCEPTION 'reception_allowlist.allowed_address missing';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'reception_allowlist'
      AND column_name = 'allowed_profile_id'
  ) THEN
    RAISE EXCEPTION 'reception_allowlist.allowed_profile_id must be removed';
  END IF;

  IF to_regprocedure('public.is_address_allowed_for_reception(uuid,text)') IS NULL THEN
    RAISE EXCEPTION 'Missing function is_address_allowed_for_reception';
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
