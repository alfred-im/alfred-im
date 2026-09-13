-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- GROUP-DELIVERY gate smoke: bidirectional allowlist failure skips erogation silently.

DO $$
DECLARE
  v_agent1 uuid := 'efd885fe-b36e-48fc-a796-0e3f153e40d6';
  v_group uuid := '0a81f785-173c-4f1c-b5df-3937086a2482';
  v_blocked uuid := '5b9fadb5-884a-41f2-89c9-4ced56be07a2'; -- ci-observer
  v_client text := 'smoke-group-gate-' || floor(random() * 1000000)::text;
  v_sender public.messages;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_agent1) THEN
    RAISE NOTICE 'group_delivery_gate_smoke_skip missing agent profiles';
    RETURN;
  END IF;

  UPDATE public.profiles SET profile_kind = 'user' WHERE id = v_agent1;
  UPDATE public.profiles SET profile_kind = 'group' WHERE id = v_group;

  DELETE FROM public.reception_allowlist
  WHERE (archive_user_id, allowed_address) IN (
    (v_agent1, 'ciagent2'),
    (v_group, 'ciagent1'),
    (v_group, 'ciobserver'),
    (v_blocked, 'ciagent2')
  );

  INSERT INTO public.reception_allowlist (archive_user_id, allowed_address)
  VALUES
    (v_group, 'ciagent1'),
    (v_group, 'ciobserver'),
    (v_agent1, 'ciagent2');

  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', v_agent1::text, 'role', 'authenticated')::text,
    true
  );

  SELECT * INTO v_sender FROM public.send_message_to_address(
    'ciagent2',
    'group gate skip hello',
    v_client,
    'text'::public.message_content_type
  );

  IF v_sender.delivered_at IS NULL THEN
    RAISE EXCEPTION 'human sender copy must still be delivered to group';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.messages m
    WHERE m.archive_user_id = v_blocked
      AND m.logical_message_id = v_sender.logical_message_id
  ) THEN
    RAISE EXCEPTION 'blocked participant must not receive erogated copy';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.messages m
    WHERE m.archive_user_id = v_group
      AND m.logical_message_id = v_sender.logical_message_id
      AND m.peer_address = 'ciobserver'
  ) THEN
    RAISE EXCEPTION 'blocked participant must not get group outbound leg';
  END IF;

  UPDATE public.profiles SET profile_kind = 'user' WHERE id = v_group;

  DELETE FROM public.reception_allowlist
  WHERE (archive_user_id, allowed_address) IN (
    (v_agent1, 'ciagent2'),
    (v_group, 'ciagent1'),
    (v_group, 'ciobserver')
  );

  INSERT INTO public.reception_allowlist (archive_user_id, allowed_address)
  VALUES (v_agent1, 'ciagent2'), (v_group, 'ciagent1')
  ON CONFLICT ON CONSTRAINT reception_allowlist_archive_user_allowed_unique DO NOTHING;

  RAISE NOTICE 'group_delivery_gate_smoke_ok';
END $$;
