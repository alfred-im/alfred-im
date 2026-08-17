-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- SYS-PUSH-020: push 1:1 solo su INSERT destinatario nuovo

DO $$
DECLARE
  v_agent1 uuid := 'efd885fe-b36e-48fc-a796-0e3f153e40d6';
  v_agent2 uuid := '0a81f785-173c-4f1c-b5df-3937086a2482';
  v_lambda uuid := gen_random_uuid();
  v_before integer;
  v_after integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_agent1) THEN
    RAISE NOTICE 'push_deliver_idempotent_smoke_skip missing agent1';
    RETURN;
  END IF;

  SELECT count(*) INTO v_before
  FROM public.outbox o
  WHERE o.payload ->> 'event_kind' = 'push_notify'
    AND o.payload ->> 'logical_message_id' = v_lambda::text;

  INSERT INTO public.messages (
    owner_id, author_id, peer_profile_id, logical_message_id, body, content_type
  )
  VALUES (
    v_agent1, v_agent1, v_agent2, v_lambda, 'smoke idempotent push', 'text'
  )
  ON CONFLICT (owner_id, logical_message_id) DO NOTHING;

  INSERT INTO public.outbox (message_id, protocol, payload, status)
  SELECT m.id, 'internal', jsonb_build_object(
    'event_kind', 'deliver',
    'recipient_profile_id', v_agent2,
    'logical_message_id', v_lambda,
    'body', 'smoke idempotent push',
    'content_type', 'text'
  ), 'queued'
  FROM public.messages m
  WHERE m.owner_id = v_agent1 AND m.logical_message_id = v_lambda
  LIMIT 1;

  PERFORM alfred_delivery.process_outbox(
    (SELECT id FROM public.outbox WHERE status = 'queued' ORDER BY created_at DESC LIMIT 1)
  );

  INSERT INTO public.outbox (message_id, protocol, payload, status)
  SELECT m.id, 'internal', jsonb_build_object(
    'event_kind', 'deliver',
    'recipient_profile_id', v_agent2,
    'logical_message_id', v_lambda,
    'body', 'smoke idempotent push',
    'content_type', 'text'
  ), 'queued'
  FROM public.messages m
  WHERE m.owner_id = v_agent1 AND m.logical_message_id = v_lambda
  LIMIT 1;

  PERFORM alfred_delivery.process_outbox(
    (SELECT id FROM public.outbox WHERE status = 'queued' ORDER BY created_at DESC LIMIT 1)
  );

  SELECT count(*) INTO v_after
  FROM public.outbox o
  WHERE o.payload ->> 'event_kind' = 'push_notify'
    AND o.payload ->> 'logical_message_id' = v_lambda::text;

  IF v_after - v_before > 1 THEN
    RAISE EXCEPTION 'expected at most one push_notify outbox for duplicate deliver';
  END IF;

  RAISE NOTICE 'push_deliver_idempotent_smoke_ok';
END $$;
