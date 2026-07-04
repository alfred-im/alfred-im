-- Mailbox send smoke: RPC round-trip agent1 → agent2 (MAILBOX-SEND-REQ-001).

DO $$
DECLARE
  v_agent1 uuid := 'efd885fe-b36e-48fc-a796-0e3f153e40d6';
  v_agent2 uuid := '0a81f785-173c-4f1c-b5df-3937086a2482';
  v_client_id text := 'smoke-send-' || floor(random() * 1000000)::text;
  v_msg public.messages;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_agent1) THEN
    RAISE NOTICE 'mailbox_send_smoke_skip missing agent profiles';
    RETURN;
  END IF;

  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', v_agent1::text, 'role', 'authenticated')::text,
    true
  );

  INSERT INTO public.reception_allowlist (owner_id, allowed_profile_id)
  VALUES (v_agent2, v_agent1)
  ON CONFLICT ON CONSTRAINT reception_allowlist_owner_allowed_unique DO NOTHING;

  SELECT * INTO v_msg FROM public.send_message_to_profile(
    v_agent2,
    'mailbox send smoke',
    v_client_id,
    'text'::public.message_content_type
  );

  IF v_msg.owner_id <> v_agent1 OR v_msg.peer_profile_id <> v_agent2 THEN
    RAISE EXCEPTION 'unexpected sender archive row';
  END IF;

  IF v_msg.delivered_at IS NULL THEN
    RAISE EXCEPTION 'sender copy missing delivered_at';
  END IF;

  RAISE NOTICE 'mailbox_send_smoke_ok message_id=% lambda=%', v_msg.id, v_msg.logical_message_id;
END $$;
