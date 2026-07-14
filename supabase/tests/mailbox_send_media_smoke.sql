-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Media content_type validation on send_message_to_profile (MAILBOX-SEND-REQ-006).

DO $$
DECLARE
  v_agent1 uuid := 'efd885fe-b36e-48fc-a796-0e3f153e40d6';
  v_agent2 uuid := '0a81f785-173c-4f1c-b5df-3937086a2482';
  v_msg public.messages;
  v_client_id text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_agent1) THEN
    RAISE NOTICE 'mailbox_send_media_smoke_skip missing agent1';
    RETURN;
  END IF;

  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', v_agent1::text, 'role', 'authenticated')::text,
    true
  );

  BEGIN
    PERFORM public.send_message_to_profile(
      v_agent2,
      '',
      'smoke-gif-missing-url',
      'gif'::public.message_content_type
    );
    RAISE EXCEPTION 'gif without media_url should fail';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT ILIKE '%media_url%' AND SQLERRM NOT ILIKE '%gif%' THEN
      RAISE;
    END IF;
  END;

  INSERT INTO public.reception_allowlist (owner_id, allowed_profile_id)
  VALUES (v_agent2, v_agent1)
  ON CONFLICT ON CONSTRAINT reception_allowlist_owner_allowed_unique DO NOTHING;

  v_client_id := 'smoke-location-' || floor(random() * 1000000)::text;
  SELECT * INTO v_msg FROM public.send_message_to_profile(
    v_agent2,
    '',
    v_client_id,
    'location'::public.message_content_type,
    null,
    null,
    null,
    null,
    45.4642,
    9.19
  );

  IF v_msg.content_type <> 'location' THEN
    RAISE EXCEPTION 'location content_type mismatch';
  END IF;

  IF v_msg.latitude IS NULL OR v_msg.longitude IS NULL THEN
    RAISE EXCEPTION 'location coordinates missing on sender copy';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.messages m
    WHERE m.owner_id = v_agent2
      AND m.logical_message_id = v_msg.logical_message_id
      AND m.content_type = 'location'
  ) THEN
    RAISE EXCEPTION 'recipient copy missing for location message';
  END IF;

  BEGIN
    PERFORM public.send_message_to_profile(
      v_agent2,
      '',
      'smoke-image-missing-url',
      'image'::public.message_content_type
    );
    RAISE EXCEPTION 'image without media_url should fail';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT ILIKE '%media_url%' AND SQLERRM NOT ILIKE '%image%' THEN
      RAISE;
    END IF;
  END;

  v_client_id := 'smoke-image-' || floor(random() * 1000000)::text;
  SELECT * INTO v_msg FROM public.send_message_to_profile(
    v_agent2,
    'Didascalia foto',
    v_client_id,
    'image'::public.message_content_type,
    'https://example.com/chat-media/smoke.jpg',
    null,
    'image/jpeg',
    1024,
    null,
    null
  );

  IF v_msg.content_type <> 'image' OR trim(v_msg.body) <> 'Didascalia foto' THEN
    RAISE EXCEPTION 'image message mismatch';
  END IF;

  BEGIN
    PERFORM public.send_message_to_profile(
      v_agent2,
      '',
      'smoke-video-missing-duration',
      'video'::public.message_content_type,
      'https://example.com/chat-media/smoke.mp4',
      null,
      'video/mp4',
      2048,
      null,
      null
    );
    RAISE EXCEPTION 'video without duration should fail';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT ILIKE '%duration%' AND SQLERRM NOT ILIKE '%video%' THEN
      RAISE;
    END IF;
  END;

  v_client_id := 'smoke-video-' || floor(random() * 1000000)::text;
  SELECT * INTO v_msg FROM public.send_message_to_profile(
    v_agent2,
    '',
    v_client_id,
    'video'::public.message_content_type,
    'https://example.com/chat-media/smoke.mp4',
    12,
    'video/mp4',
    2048,
    null,
    null
  );

  IF v_msg.content_type <> 'video' OR v_msg.duration_seconds <> 12 THEN
    RAISE EXCEPTION 'video message mismatch';
  END IF;

  RAISE NOTICE 'mailbox_send_media_smoke_ok';
END $$;
