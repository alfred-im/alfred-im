-- Delivery: sender copy + recipient copy + outbox + delivered_at (MAILBOX-SEND-REQ-003/004).

DO $$
DECLARE
  v_agent1 uuid := 'efd885fe-b36e-48fc-a796-0e3f153e40d6';
  v_agent2 uuid := '0a81f785-173c-4f1c-b5df-3937086a2482';
  v_client_id text := 'smoke-delivery-' || floor(random() * 1000000)::text;
  v_sender public.messages;
  v_recipient_count integer;
  v_outbox_status public.queue_status;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_agent1) THEN
    RAISE NOTICE 'mailbox_delivery_smoke_skip missing agent1';
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

  SELECT * INTO v_sender FROM public.send_message_to_profile(
    v_agent2,
    'delivery smoke',
    v_client_id,
    'text'::public.message_content_type
  );

  IF v_sender.owner_id <> v_agent1 OR v_sender.author_id <> v_agent1 THEN
    RAISE EXCEPTION 'sender copy owner/author mismatch';
  END IF;

  IF v_sender.delivered_at IS NULL THEN
    RAISE EXCEPTION 'sender copy missing delivered_at';
  END IF;

  SELECT count(*) INTO v_recipient_count
  FROM public.messages m
  WHERE m.owner_id = v_agent2
    AND m.author_id = v_agent1
    AND m.logical_message_id = v_sender.logical_message_id;

  IF v_recipient_count <> 1 THEN
    RAISE EXCEPTION 'expected one recipient copy, got %', v_recipient_count;
  END IF;

  SELECT o.status INTO v_outbox_status
  FROM public.outbox o
  WHERE o.message_id = v_sender.id;

  IF v_outbox_status IS DISTINCT FROM 'completed' THEN
    RAISE EXCEPTION 'internal outbox must be completed, got %', v_outbox_status;
  END IF;

  RAISE NOTICE 'mailbox_delivery_smoke_ok lambda=%', v_sender.logical_message_id;
END $$;
