-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- SYS-PUSH: push_notify only after successful delivery

DO $$
DECLARE
  v_agent1 uuid := 'efd885fe-b36e-48fc-a796-0e3f153e40d6';
  v_agent2 uuid := '0a81f785-173c-4f1c-b5df-3937086a2482';
  v_device uuid := '11111111-1111-4111-8111-111111111111';
  v_client_id text := 'smoke-push-' || floor(random() * 1000000)::text;
  v_sender public.messages;
  v_push_count integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_agent1) THEN
    RAISE NOTICE 'push_delivery_trigger_smoke_skip missing agent1';
    RETURN;
  END IF;

  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', v_agent1::text, 'role', 'authenticated')::text,
    true
  );

  INSERT INTO public.push_subscriptions (
    user_id, device_id, endpoint, p256dh_key, auth_key
  )
  VALUES (
    v_agent2,
    v_device,
    'https://push.test/smoke/' || v_client_id,
    'p256dh-test',
    'auth-test'
  )
  ON CONFLICT (user_id, device_id) DO UPDATE
    SET endpoint = excluded.endpoint,
        last_seen_at = now();

  INSERT INTO public.reception_allowlist (archive_user_id, allowed_profile_id)
  VALUES
    (v_agent1, v_agent2),
    (v_agent2, v_agent1)
  ON CONFLICT ON CONSTRAINT reception_allowlist_archive_user_allowed_unique DO NOTHING;

  SELECT * INTO v_sender FROM public.send_message_to_profile(
    v_agent2,
    'push smoke',
    v_client_id,
    'text'::public.message_content_type
  );

  SELECT count(*) INTO v_push_count
  FROM public.outbox o
  WHERE o.payload ->> 'event_kind' = 'push_notify'
    AND (o.payload ->> 'logical_message_id')::uuid = v_sender.logical_message_id
    AND o.status = 'completed';

  IF v_push_count < 1 THEN
    RAISE EXCEPTION 'expected push_notify outbox after delivery, got %', v_push_count;
  END IF;

  DELETE FROM public.reception_allowlist
  WHERE archive_user_id = v_agent2 AND allowed_profile_id = v_agent1;

  v_client_id := v_client_id || '-reject';

  PERFORM public.send_message_to_profile(
    v_agent2,
    'push rejected',
    v_client_id,
    'text'::public.message_content_type
  );

  SELECT count(*) INTO v_push_count
  FROM public.outbox o
  WHERE o.payload ->> 'event_kind' = 'push_notify'
    AND o.payload ->> 'preview_text' = 'push rejected';

  IF v_push_count <> 0 THEN
    RAISE EXCEPTION 'push_notify must not fire on reception reject';
  END IF;

  RAISE NOTICE 'push_delivery_trigger_smoke_ok';
END $$;
