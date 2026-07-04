-- Verifica invio messaggio a profilo non in rubrica (modello mailbox).

DO $$
DECLARE
  v_sender uuid := 'efd885fe-b36e-48fc-a796-0e3f153e40d6'; -- alfredagent1
  v_recipient uuid := '0a81f785-173c-4f1c-b5df-3937086a2482'; -- alfredagent2
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
    'text'::public.message_content_type
  );

  IF v_msg.owner_id <> v_sender OR v_msg.peer_profile_id <> v_recipient THEN
    RAISE EXCEPTION 'Unexpected mailbox parties';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.list_inbox() i
    WHERE i.peer_profile_id = v_recipient
  ) THEN
    RAISE EXCEPTION 'list_inbox must include peer after send';
  END IF;

  RAISE NOTICE 'send_message_peer_inbox_smoke_ok message_id=%', v_msg.id;
END $$;
