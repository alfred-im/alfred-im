-- Idempotency: same client_message_id returns same sender row (MAILBOX-SEND-REQ-005).

DO $$
DECLARE
  v_agent1 uuid := 'efd885fe-b36e-48fc-a796-0e3f153e40d6';
  v_agent2 uuid := '0a81f785-173c-4f1c-b5df-3937086a2482';
  v_client_id text := 'smoke-idempotency-' || floor(random() * 1000000)::text;
  v_first public.messages;
  v_second public.messages;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_agent1) THEN
    RAISE NOTICE 'mailbox_idempotency_smoke_skip missing agent1';
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

  SELECT * INTO v_first FROM public.send_message_to_profile(
    v_agent2,
    'idempotency smoke',
    v_client_id,
    'text'::public.message_content_type
  );

  SELECT * INTO v_second FROM public.send_message_to_profile(
    v_agent2,
    'idempotency smoke retry',
    v_client_id,
    'text'::public.message_content_type
  );

  IF v_first.id IS DISTINCT FROM v_second.id THEN
    RAISE EXCEPTION 'idempotency failed: ids % vs %', v_first.id, v_second.id;
  END IF;

  IF v_first.logical_message_id IS DISTINCT FROM v_second.logical_message_id THEN
    RAISE EXCEPTION 'idempotency lambda mismatch';
  END IF;

  RAISE NOTICE 'mailbox_idempotency_smoke_ok id=%', v_first.id;
END $$;
