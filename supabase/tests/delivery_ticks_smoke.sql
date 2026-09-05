-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- SYS-DELIVERY: contratto spunte (✓ / ✓✓ grigie / ✓✓ blu) + gate allow list.
-- ✓ singola = copia mittente, delivered_at null (rifiuto allow list o pre-recapito)
-- ✓✓ grigie = worker deliver → delivered_at su mittente, read_at null
-- ✓✓ blu = lettore mark_peer_read → outbox read_receipt → worker propaga read_at al mittente

DO $$
DECLARE
  v_agent1 uuid := 'efd885fe-b36e-48fc-a796-0e3f153e40d6';
  v_agent2 uuid := '0a81f785-173c-4f1c-b5df-3937086a2482';
  v_reject_client text := 'smoke-ticks-reject-' || floor(random() * 1000000)::text;
  v_deliver_client text := 'smoke-ticks-deliver-' || floor(random() * 1000000)::text;
  v_read_client text := 'smoke-ticks-read-' || floor(random() * 1000000)::text;
  v_sender public.messages;
  v_outbox public.outbox;
  v_recipient_count integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_agent1) THEN
    RAISE NOTICE 'delivery_ticks_smoke_skip missing agent profiles';
    RETURN;
  END IF;

  -- -------------------------------------------------------------------------
  -- Fase 1: rifiuto allow list → solo ✓ (delivered_at null permanente)
  -- -------------------------------------------------------------------------
  DELETE FROM public.reception_allowlist
  WHERE archive_user_id = v_agent2 AND allowed_profile_id = v_agent1;

  INSERT INTO public.reception_allowlist (archive_user_id, allowed_profile_id)
  VALUES (v_agent1, v_agent2)
  ON CONFLICT ON CONSTRAINT reception_allowlist_archive_user_allowed_unique DO NOTHING;

  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', v_agent1::text, 'role', 'authenticated')::text,
    true
  );

  SELECT * INTO v_sender FROM public.send_message_to_profile(
    v_agent2,
    'ticks reject',
    v_reject_client,
    'text'::public.message_content_type
  );

  IF v_sender.delivered_at IS NOT NULL OR v_sender.read_at IS NOT NULL THEN
    RAISE EXCEPTION 'reject phase: sender must stay single-tick (delivered_at/read_at null)';
  END IF;

  SELECT count(*) INTO v_recipient_count
  FROM public.messages m
  WHERE m.archive_user_id = v_agent2
    AND m.logical_message_id = v_sender.logical_message_id;

  IF v_recipient_count <> 0 THEN
    RAISE EXCEPTION 'reject phase: no recipient copy expected';
  END IF;

  SELECT * INTO v_outbox
  FROM public.outbox o
  WHERE o.message_id = v_sender.id
  ORDER BY o.created_at DESC
  LIMIT 1;

  IF v_outbox.payload ->> 'event_kind' IS DISTINCT FROM 'deliver' THEN
    RAISE EXCEPTION 'reject phase: outbox event_kind must be deliver';
  END IF;

  IF v_outbox.status IS DISTINCT FROM 'completed' THEN
    RAISE EXCEPTION 'reject phase: outbox must be completed';
  END IF;

  IF coalesce((v_outbox.payload ->> 'reception_rejected')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'reject phase: outbox payload must include reception_rejected';
  END IF;

  -- -------------------------------------------------------------------------
  -- Fase 2: allow list → worker deliver → ✓✓ grigie (delivered_at, read_at null)
  -- -------------------------------------------------------------------------
  INSERT INTO public.reception_allowlist (archive_user_id, allowed_profile_id)
  VALUES (v_agent2, v_agent1);

  SELECT * INTO v_sender FROM public.send_message_to_profile(
    v_agent2,
    'ticks deliver',
    v_deliver_client,
    'text'::public.message_content_type
  );

  IF v_sender.delivered_at IS NULL THEN
    RAISE EXCEPTION 'deliver phase: sender copy missing delivered_at (double grey)';
  END IF;

  IF v_sender.read_at IS NOT NULL THEN
    RAISE EXCEPTION 'deliver phase: read_at must stay null before mark_peer_read';
  END IF;

  SELECT count(*) INTO v_recipient_count
  FROM public.messages m
  WHERE m.archive_user_id = v_agent2
    AND m.logical_message_id = v_sender.logical_message_id
    AND m.author_id = v_agent1;

  IF v_recipient_count <> 1 THEN
    RAISE EXCEPTION 'deliver phase: expected one recipient copy, got %', v_recipient_count;
  END IF;

  SELECT * INTO v_outbox
  FROM public.outbox o
  WHERE o.message_id = v_sender.id
    AND o.payload ->> 'event_kind' = 'deliver'
  ORDER BY o.created_at DESC
  LIMIT 1;

  IF v_outbox.status IS DISTINCT FROM 'completed' THEN
    RAISE EXCEPTION 'deliver phase: deliver outbox not completed';
  END IF;

  IF coalesce((v_outbox.payload ->> 'reception_rejected')::boolean, false) IS TRUE THEN
    RAISE EXCEPTION 'deliver phase: must not be reception_rejected';
  END IF;

  -- -------------------------------------------------------------------------
  -- Fase 3: lettore segna letto → outbox read_receipt → ✓✓ blu sul mittente
  -- -------------------------------------------------------------------------
  SELECT * INTO v_sender FROM public.send_message_to_profile(
    v_agent2,
    'ticks read',
    v_read_client,
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
    WHERE m.archive_user_id = v_agent2
      AND m.logical_message_id = v_sender.logical_message_id
      AND m.author_id = v_agent1
      AND m.read_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'read phase: recipient incoming read_at not set locally';
  END IF;

  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', v_agent1::text, 'role', 'authenticated')::text,
    true
  );

  SELECT m.read_at INTO v_sender.read_at
  FROM public.messages m
  WHERE m.id = v_sender.id;

  IF v_sender.read_at IS NULL THEN
    RAISE EXCEPTION 'read phase: sender read_at not propagated by delivery worker';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.outbox o
    JOIN public.messages inc ON inc.id = o.message_id
    WHERE inc.logical_message_id = v_sender.logical_message_id
      AND inc.archive_user_id = v_agent2
      AND o.payload ->> 'event_kind' = 'read_receipt'
      AND (o.payload ->> 'read_receipt_id')::uuid IS NOT NULL
      AND o.status = 'completed'
  ) THEN
    RAISE EXCEPTION 'read phase: missing completed read_receipt outbox event with read_receipt_id';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.messages reader
    INNER JOIN public.messages sender ON sender.logical_message_id = reader.logical_message_id
    WHERE reader.archive_user_id = v_agent2
      AND sender.id = v_sender.id
      AND reader.read_receipt_id IS NOT NULL
      AND sender.read_receipt_id = reader.read_receipt_id
  ) THEN
    RAISE EXCEPTION 'read phase: read_receipt_id not replicated to sender copy';
  END IF;

  RAISE NOTICE 'delivery_ticks_smoke_ok lambda=%', v_sender.logical_message_id;
END $$;
