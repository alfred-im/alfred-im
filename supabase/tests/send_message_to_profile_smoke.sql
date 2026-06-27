-- Verifica invio messaggio a profilo non in rubrica (nessuna tabella inbox_threads).

DO $$
DECLARE
  v_sender uuid := '8a8d7265-f7ab-4473-87aa-978094383215'; -- test2
  v_recipient uuid := '5b9fadb5-884a-41f2-89c9-4ced56be07a2'; -- test1
  v_msg public.messages;
BEGIN
  IF to_regclass('public.inbox_threads') IS NOT NULL THEN
    RAISE EXCEPTION 'inbox_threads must not exist';
  END IF;

  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', v_sender::text, 'role', 'authenticated')::text,
    true
  );

  SELECT * INTO v_msg FROM public.send_message_to_profile(
    v_recipient,
    'smoke peer-only inbox',
    'smoke-client-id-' || floor(random() * 1000000)::text,
    'text'::public.message_content_type,
    null,
    null,
    null,
    null
  );

  IF v_msg.sender_id <> v_sender OR v_msg.recipient_profile_id <> v_recipient THEN
    RAISE EXCEPTION 'Unexpected message parties';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.list_inbox() i
    WHERE i.peer_profile_id = v_recipient
  ) THEN
    RAISE EXCEPTION 'list_inbox must include peer after send';
  END IF;

  RAISE NOTICE 'send_message_peer_inbox_smoke_ok message_id=%', v_msg.id;
END $$;
