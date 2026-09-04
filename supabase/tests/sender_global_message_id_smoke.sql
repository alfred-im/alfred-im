-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Sender server assigns global message id; recipient stores the same id (never mints a new one).

DO $$
DECLARE
  v_agent1 uuid := 'efd885fe-b36e-48fc-a796-0e3f153e40d6';
  v_agent2 uuid := '0a81f785-173c-4f1c-b5df-3937086a2482';
  v_client_id text := 'smoke-sender-global-id-' || floor(random() * 1000000)::text;
  v_sender public.messages;
  v_recipient public.messages;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_agent1) THEN
    RAISE NOTICE 'sender_global_message_id_smoke_skip missing agent1';
    RETURN;
  END IF;

  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', v_agent1::text, 'role', 'authenticated')::text,
    true
  );

  INSERT INTO public.reception_allowlist (archive_user_id, allowed_profile_id)
  VALUES
    (v_agent1, v_agent2),
    (v_agent2, v_agent1)
  ON CONFLICT ON CONSTRAINT reception_allowlist_archive_user_allowed_unique DO NOTHING;

  SELECT * INTO v_sender FROM public.send_message_to_profile(
    v_agent2,
    'sender global id smoke',
    v_client_id,
    'text'::public.message_content_type
  );

  IF v_sender.logical_message_id IS NULL THEN
    RAISE EXCEPTION 'sender copy missing global message id';
  END IF;

  SELECT * INTO v_recipient
  FROM public.messages m
  WHERE m.archive_user_id = v_agent2
    AND m.logical_message_id = v_sender.logical_message_id
  LIMIT 1;

  IF v_recipient.id IS NULL THEN
    RAISE EXCEPTION 'recipient copy missing for sender global message id';
  END IF;

  IF v_recipient.logical_message_id IS DISTINCT FROM v_sender.logical_message_id THEN
    RAISE EXCEPTION 'recipient must store sender-assigned message id unchanged';
  END IF;

  IF v_recipient.client_message_id IS NOT NULL THEN
    RAISE EXCEPTION 'client_message_id must not appear on recipient copy';
  END IF;

  RAISE NOTICE 'sender_global_message_id_smoke_ok id=%', v_sender.logical_message_id;
END $$;
