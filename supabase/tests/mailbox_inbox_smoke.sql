-- list_inbox: peer row + unread after send (MAILBOX-INBOX-REQ-001/002).

DO $$
DECLARE
  v_agent1 uuid := 'efd885fe-b36e-48fc-a796-0e3f153e40d6';
  v_agent2 uuid := '0a81f785-173c-4f1c-b5df-3937086a2482';
  v_client_id text := 'smoke-inbox-' || floor(random() * 1000000)::text;
  v_unread integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_agent1) THEN
    RAISE NOTICE 'mailbox_inbox_smoke_skip missing agent1';
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

  PERFORM public.send_message_to_profile(
    v_agent2,
    'inbox smoke',
    v_client_id,
    'text'::public.message_content_type
  );

  IF NOT EXISTS (
    SELECT 1 FROM public.list_inbox() i
    WHERE i.peer_profile_id = v_agent2
  ) THEN
    RAISE EXCEPTION 'list_inbox missing peer after send (sender view)';
  END IF;

  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', v_agent2::text, 'role', 'authenticated')::text,
    true
  );

  SELECT i.unread_count INTO v_unread
  FROM public.list_inbox() i
  WHERE i.peer_profile_id = v_agent1;

  IF coalesce(v_unread, 0) < 1 THEN
    RAISE EXCEPTION 'recipient unread_count expected >= 1, got %', v_unread;
  END IF;

  RAISE NOTICE 'mailbox_inbox_smoke_ok unread=%', v_unread;
END $$;
