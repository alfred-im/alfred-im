-- RECEPTION-ALLOWLIST gate smoke: silent reject vs deliver (REQ-005–012).

DO $$
DECLARE
  v_agent1 uuid := 'efd885fe-b36e-48fc-a796-0e3f153e40d6';
  v_agent2 uuid := '0a81f785-173c-4f1c-b5df-3937086a2482';
  v_client_reject text := 'smoke-allow-reject-' || floor(random() * 1000000)::text;
  v_client_allow text := 'smoke-allow-ok-' || floor(random() * 1000000)::text;
  v_sender public.messages;
  v_recipient_count integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_agent1) THEN
    RAISE NOTICE 'reception_allowlist_gate_smoke_skip missing agent profiles';
    RETURN;
  END IF;

  DELETE FROM public.reception_allowlist
  WHERE owner_id = v_agent2 AND allowed_profile_id = v_agent1;

  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', v_agent1::text, 'role', 'authenticated')::text,
    true
  );

  SELECT * INTO v_sender FROM public.send_message_to_profile(
    v_agent2,
    'reception gate reject',
    v_client_reject,
    'text'::public.message_content_type
  );

  IF v_sender.delivered_at IS NOT NULL THEN
    RAISE EXCEPTION 'rejected send must keep delivered_at null';
  END IF;

  SELECT count(*) INTO v_recipient_count
  FROM public.messages m
  WHERE m.owner_id = v_agent2
    AND m.logical_message_id = v_sender.logical_message_id;

  IF v_recipient_count <> 0 THEN
    RAISE EXCEPTION 'rejected send must not create recipient copy';
  END IF;

  INSERT INTO public.reception_allowlist (owner_id, allowed_profile_id)
  VALUES (v_agent2, v_agent1);

  SELECT * INTO v_sender FROM public.send_message_to_profile(
    v_agent2,
    'reception gate allow',
    v_client_allow,
    'text'::public.message_content_type
  );

  IF v_sender.delivered_at IS NULL THEN
    RAISE EXCEPTION 'allowed send must set delivered_at';
  END IF;

  SELECT count(*) INTO v_recipient_count
  FROM public.messages m
  WHERE m.owner_id = v_agent2
    AND m.logical_message_id = v_sender.logical_message_id;

  IF v_recipient_count <> 1 THEN
    RAISE EXCEPTION 'allowed send must create one recipient copy, got %', v_recipient_count;
  END IF;

  RAISE NOTICE 'reception_allowlist_gate_smoke_ok';
END $$;
