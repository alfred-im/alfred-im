-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- SYS-MAILBOX-036 / SYS-MAILBOX-057: recent window + inbox preview alignment + pagination cursor.

DO $$
DECLARE
  v_owner uuid := '5b9fadb5-884a-41f2-89c9-4ced56be07a2';
  v_peer uuid := '8a8d7265-f7ab-4473-87aa-978094383215';
  v_inbox_preview text;
  v_inbox_at timestamptz;
  v_window_count integer;
  v_window_latest_body text;
  v_oldest_in_window timestamptz;
  v_page_count integer;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.messages m
    WHERE m.owner_id = v_owner
      AND m.peer_profile_id = v_peer
    HAVING count(*) > 100
  ) THEN
    RAISE NOTICE 'mailbox_peer_messages_window_smoke_skip need >100 messages between test peers';
    RETURN;
  END IF;

  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', v_owner::text, 'role', 'authenticated')::text,
    true
  );

  SELECT i.last_message_preview, i.last_message_at
  INTO v_inbox_preview, v_inbox_at
  FROM public.list_inbox() i
  WHERE i.peer_profile_id = v_peer;

  IF v_inbox_at IS NULL THEN
    RAISE EXCEPTION 'list_inbox missing peer row for window smoke';
  END IF;

  SELECT count(*)::integer,
         (array_agg(trim(m.body) ORDER BY m.created_at DESC))[1],
         min(m.created_at)
  INTO v_window_count, v_window_latest_body, v_oldest_in_window
  FROM public.list_peer_messages(v_peer, 100) m;

  IF v_window_count < 1 THEN
    RAISE EXCEPTION 'list_peer_messages returned empty window';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.list_peer_messages(v_peer, 100) m
    WHERE m.created_at = v_inbox_at
  ) THEN
    RAISE EXCEPTION 'inbox latest not in initial peer window preview=% at=% latest_in_window=%',
      v_inbox_preview, v_inbox_at, v_window_latest_body;
  END IF;

  SELECT count(*)::integer
  INTO v_page_count
  FROM public.list_peer_messages(v_peer, 100, v_oldest_in_window) m;

  IF v_page_count < 1 THEN
    RAISE EXCEPTION 'pagination cursor returned no older messages';
  END IF;

  RAISE NOTICE 'mailbox_peer_messages_window_smoke_ok window=% older_page=% inbox=%',
    v_window_count, v_page_count, v_inbox_preview;
END $$;
