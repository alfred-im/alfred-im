-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- GROUP-DELIVERY smoke: human → group → erogation to third participant.

DO $$
DECLARE
  v_agent1 uuid := 'efd885fe-b36e-48fc-a796-0e3f153e40d6';
  v_group uuid := '0a81f785-173c-4f1c-b5df-3937086a2482';
  v_observer uuid := '5b9fadb5-884a-41f2-89c9-4ced56be07a2'; -- ci-observer (stack locale)
  v_client text := 'smoke-group-' || floor(random() * 1000000)::text;
  v_sender public.messages;
  v_group_count integer;
  v_erogated public.messages;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_agent1) THEN
    RAISE NOTICE 'group_delivery_smoke_skip missing agent profiles';
    RETURN;
  END IF;

  UPDATE public.profiles SET profile_kind = 'user' WHERE id = v_agent1;
  UPDATE public.profiles SET profile_kind = 'group' WHERE id = v_group;

  DELETE FROM public.reception_allowlist
  WHERE (archive_user_id, allowed_profile_id) IN (
    (v_agent1, v_group),
    (v_group, v_agent1),
    (v_group, v_observer),
    (v_observer, v_group)
  );

  INSERT INTO public.reception_allowlist (archive_user_id, allowed_profile_id)
  VALUES
    (v_group, v_agent1),
    (v_group, v_observer),
    (v_agent1, v_group),
    (v_observer, v_group);

  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', v_agent1::text, 'role', 'authenticated')::text,
    true
  );

  SELECT * INTO v_sender FROM public.send_message_to_profile(
    v_group,
    'group delivery hello',
    v_client,
    'text'::public.message_content_type
  );

  IF v_sender.delivered_at IS NULL THEN
    RAISE EXCEPTION 'group delivery must set delivered_at on sender copy';
  END IF;

  SELECT count(*) INTO v_group_count
  FROM public.messages m
  WHERE m.archive_user_id = v_group
    AND m.logical_message_id = v_sender.logical_message_id;

  IF v_group_count <> 1 THEN
    RAISE EXCEPTION 'group archive must have one row, got %', v_group_count;
  END IF;

  SELECT * INTO v_erogated
  FROM public.messages m
  WHERE m.archive_user_id = v_observer
    AND m.logical_message_id = v_sender.logical_message_id
  LIMIT 1;

  IF v_erogated.id IS NULL THEN
    RAISE EXCEPTION 'missing erogated copy for observer participant';
  END IF;

  IF v_erogated.author_id <> v_group THEN
    RAISE EXCEPTION 'erogated author must be group';
  END IF;

  IF v_erogated.original_author_id <> v_agent1 THEN
    RAISE EXCEPTION 'erogated original_author must be human sender';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.messages m
    WHERE m.archive_user_id = v_group
      AND m.logical_message_id = v_sender.logical_message_id
      AND m.original_author_id = v_agent1
  ) THEN
    RAISE EXCEPTION 'group archive must set original_author to human sender';
  END IF;

  IF v_erogated.peer_profile_id <> v_group THEN
    RAISE EXCEPTION 'erogated peer must be group';
  END IF;

  UPDATE public.profiles SET profile_kind = 'user' WHERE id = v_group;

  DELETE FROM public.reception_allowlist
  WHERE (archive_user_id, allowed_profile_id) IN (
    (v_agent1, v_group),
    (v_group, v_agent1),
    (v_group, v_observer),
    (v_observer, v_group)
  );

  INSERT INTO public.reception_allowlist (archive_user_id, allowed_profile_id)
  VALUES (v_agent1, v_group), (v_group, v_agent1)
  ON CONFLICT ON CONSTRAINT reception_allowlist_archive_user_allowed_unique DO NOTHING;

  RAISE NOTICE 'group_delivery_smoke_ok';
END $$;
