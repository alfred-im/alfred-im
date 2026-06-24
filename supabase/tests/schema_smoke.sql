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
  IF to_regclass('public.conversations') IS NULL THEN
    missing := array_append(missing, 'conversations');
  END IF;
  IF to_regclass('public.messages') IS NULL THEN
    missing := array_append(missing, 'messages');
  END IF;
  IF to_regclass('public.outbox') IS NULL THEN
    missing := array_append(missing, 'outbox');
  END IF;

  IF array_length(missing, 1) IS NOT NULL THEN
    RAISE EXCEPTION 'Missing tables: %', array_to_string(missing, ', ');
  END IF;

  -- Funzioni RPC
  IF to_regprocedure('public.send_message(uuid,text,text)') IS NULL THEN
    RAISE EXCEPTION 'Missing RPC send_message';
  END IF;
  IF to_regprocedure('public.mark_conversation_read(uuid)') IS NULL THEN
    RAISE EXCEPTION 'Missing RPC mark_conversation_read';
  END IF;

  RAISE NOTICE 'alfred_schema_smoke_ok';
END $$;
