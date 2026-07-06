-- GROUP-CORE schema smoke: profile_kind, original_author_id, RPC grants.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public' AND t.typname = 'profile_kind'
  ) THEN
    RAISE EXCEPTION 'missing enum profile_kind';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'profiles'
      AND column_name = 'profile_kind'
  ) THEN
    RAISE EXCEPTION 'missing profiles.profile_kind';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'messages'
      AND column_name = 'original_author_id'
  ) THEN
    RAISE EXCEPTION 'missing messages.original_author_id';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'list_owner_messages'
  ) THEN
    RAISE EXCEPTION 'missing list_owner_messages';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'broadcast_message_to_allowlist'
  ) THEN
    RAISE EXCEPTION 'missing broadcast_message_to_allowlist';
  END IF;

  RAISE NOTICE 'group_schema_smoke_ok';
END $$;
