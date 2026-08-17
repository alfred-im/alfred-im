-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- GROUP-DELIVERY broadcast smoke: one archive row + member distribution.

DO $$
DECLARE
  v_group uuid := '0a81f785-173c-4f1c-b5df-3937086a2482';
  v_observer uuid := '5b9fadb5-884a-41f2-89c9-4ced56be07a2'; -- ci-observer (stack locale)
  v_client text := 'smoke-broadcast-' || floor(random() * 1000000)::text;
  v_broadcast public.messages;
  v_group_rows integer;
  v_member public.messages;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_group) THEN
    RAISE NOTICE 'group_broadcast_smoke_skip missing profiles';
    RETURN;
  END IF;

  UPDATE public.profiles SET profile_kind = 'group' WHERE id = v_group;

  DELETE FROM public.reception_allowlist
  WHERE (archive_user_id, allowed_profile_id) IN ((v_group, v_observer), (v_observer, v_group));

  INSERT INTO public.reception_allowlist (archive_user_id, allowed_profile_id)
  VALUES (v_group, v_observer), (v_observer, v_group);

  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', v_group::text, 'role', 'authenticated')::text,
    true
  );

  SELECT * INTO v_broadcast FROM public.broadcast_message_to_allowlist(
    'group broadcast single row',
    v_client,
    'text'::public.message_content_type
  );

  IF v_broadcast.original_author_id <> v_group THEN
    RAISE EXCEPTION 'broadcast original_author must be group';
  END IF;

  SELECT count(*) INTO v_group_rows
  FROM public.messages m
  WHERE m.archive_user_id = v_group
    AND m.logical_message_id = v_broadcast.logical_message_id;

  IF v_group_rows <> 1 THEN
    RAISE EXCEPTION 'group archive must have exactly one row, got %', v_group_rows;
  END IF;

  SELECT * INTO v_member
  FROM public.messages m
  WHERE m.archive_user_id = v_observer
    AND m.logical_message_id = v_broadcast.logical_message_id
  LIMIT 1;

  IF v_member.id IS NULL THEN
    RAISE EXCEPTION 'missing member copy';
  END IF;

  IF v_member.author_id <> v_group OR v_member.original_author_id <> v_group THEN
    RAISE EXCEPTION 'member copy must have group as technical and content author';
  END IF;

  UPDATE public.profiles SET profile_kind = 'user' WHERE id = v_group;

  DELETE FROM public.reception_allowlist
  WHERE (archive_user_id, allowed_profile_id) IN ((v_group, v_observer), (v_observer, v_group));

  RAISE NOTICE 'group_broadcast_smoke_ok';
END $$;
