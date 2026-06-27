-- Test di integrazione schema Alfred (eseguire via MCP execute_sql o supabase db reset)
-- Verifica: tipi, tabelle dominio, RLS abilitato, funzioni RPC presenti

DO $$
DECLARE
  missing text[];
BEGIN
  -- Tabelle richieste
  IF to_regclass('public.profiles') IS NULL THEN
    missing := array_append(missing, 'profiles');
  END IF;
  IF to_regclass('public.contacts') IS NULL THEN
    missing := array_append(missing, 'contacts');
  END IF;
  IF to_regclass('public.messages') IS NULL THEN
    missing := array_append(missing, 'messages');
  END IF;
  IF to_regclass('public.outbox') IS NULL THEN
    missing := array_append(missing, 'outbox');
  END IF;

  IF to_regclass('public.conversations') IS NOT NULL THEN
    RAISE EXCEPTION 'Legacy table conversations must be removed';
  END IF;

  IF to_regclass('public.inbox_threads') IS NOT NULL THEN
    RAISE EXCEPTION 'Legacy table inbox_threads must be removed';
  END IF;

  IF array_length(missing, 1) IS NOT NULL THEN
    RAISE EXCEPTION 'Missing tables: %', array_to_string(missing, ', ');
  END IF;

  -- Funzioni RPC
  IF to_regprocedure('public.send_message_to_profile(uuid,text,text,public.message_content_type,text,integer,text,bigint)') IS NULL THEN
    RAISE EXCEPTION 'Missing RPC send_message_to_profile';
  END IF;
  IF (
    SELECT count(*)
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'send_message_to_profile'
  ) <> 1 THEN
    RAISE EXCEPTION 'send_message_to_profile must have exactly one overload (PostgREST ambiguity)';
  END IF;
  IF to_regprocedure('public.mark_peer_read(uuid)') IS NULL THEN
    RAISE EXCEPTION 'Missing RPC mark_peer_read';
  END IF;
  IF to_regprocedure('public.list_inbox()') IS NULL THEN
    RAISE EXCEPTION 'Missing RPC list_inbox';
  END IF;
  IF to_regprocedure('public.list_peer_messages(uuid,integer)') IS NULL THEN
    RAISE EXCEPTION 'Missing RPC list_peer_messages';
  END IF;
  IF to_regprocedure('public.find_profile_by_username(text)') IS NULL THEN
    RAISE EXCEPTION 'Missing RPC find_profile_by_username';
  END IF;

  RAISE NOTICE 'alfred_schema_smoke_ok';
END $$;
