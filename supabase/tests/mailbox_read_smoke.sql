-- mark_peer_read: read_at on recipient incoming + sender outgoing copy (MAILBOX-READ-REQ-003–005).

DO $$
DECLARE
  v_agent1 uuid := 'efd885fe-b36e-48fc-a796-0e3f153e40d6';
  v_agent2 uuid := '0a81f785-173c-4f1c-b5df-3937086a2482';
  v_client_id text := 'smoke-read-' || floor(random() * 1000000)::text;
  v_sender public.messages;
  v_sender_read_at timestamptz;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_agent1) THEN
    RAISE NOTICE 'mailbox_read_smoke_skip missing agent1';
    RETURN;
  END IF;

  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', v_agent1::text, 'role', 'authenticated')::text,
    true
  );

  SELECT * INTO v_sender FROM public.send_message_to_profile(
    v_agent2,
    'read smoke',
    v_client_id,
    'text'::public.message_content_type
  );

  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', v_agent2::text, 'role', 'authenticated')::text,
    true
  );

  PERFORM public.mark_peer_read(v_agent1);

  IF NOT EXISTS (
    SELECT 1 FROM public.messages m
    WHERE m.owner_id = v_agent2
      AND m.logical_message_id = v_sender.logical_message_id
      AND m.author_id = v_agent1
      AND m.read_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'recipient incoming read_at not set';
  END IF;

  SELECT m.read_at INTO v_sender_read_at
  FROM public.messages m
  WHERE m.id = v_sender.id;

  IF v_sender_read_at IS NULL THEN
    RAISE EXCEPTION 'sender copy read_at not propagated';
  END IF;

  RAISE NOTICE 'mailbox_read_smoke_ok';
END $$;
