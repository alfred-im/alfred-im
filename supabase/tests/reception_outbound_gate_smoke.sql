-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Outbound reception gate: sender must have recipient in own allow list (SYS-RECEPTION-029–031).

DO $$
DECLARE
  v_agent1 uuid := 'efd885fe-b36e-48fc-a796-0e3f153e40d6';
  v_agent2 uuid := '0a81f785-173c-4f1c-b5df-3937086a2482';
  v_client_reject text := 'smoke-outbound-reject-' || floor(random() * 1000000)::text;
  v_client_allow text := 'smoke-outbound-ok-' || floor(random() * 1000000)::text;
  v_sender public.messages;
  v_count integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_agent1) THEN
    RAISE NOTICE 'reception_outbound_gate_smoke_skip missing agent profiles';
    RETURN;
  END IF;

  DELETE FROM public.reception_allowlist
  WHERE archive_user_id = v_agent1 AND allowed_profile_id = v_agent2;

  INSERT INTO public.reception_allowlist (archive_user_id, allowed_profile_id)
  VALUES (v_agent2, v_agent1)
  ON CONFLICT ON CONSTRAINT reception_allowlist_archive_user_allowed_unique DO NOTHING;

  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', v_agent1::text, 'role', 'authenticated')::text,
    true
  );

  BEGIN
    PERFORM public.send_message_to_profile(
      v_agent2,
      'outbound gate reject',
      v_client_reject,
      'text'::public.message_content_type
    );
    RAISE EXCEPTION 'outbound reject: send must fail when recipient not in sender allow list';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%recipient not in reception allowlist%' THEN
        RAISE;
      END IF;
  END;

  SELECT count(*) INTO v_count
  FROM public.messages m
  WHERE m.archive_user_id = v_agent1
    AND m.client_message_id = v_client_reject;

  IF v_count <> 0 THEN
    RAISE EXCEPTION 'outbound reject: must not persist sender copy';
  END IF;

  INSERT INTO public.reception_allowlist (archive_user_id, allowed_profile_id)
  VALUES (v_agent1, v_agent2)
  ON CONFLICT ON CONSTRAINT reception_allowlist_archive_user_allowed_unique DO NOTHING;

  SELECT * INTO v_sender FROM public.send_message_to_profile(
    v_agent2,
    'outbound gate allow',
    v_client_allow,
    'text'::public.message_content_type
  );

  IF v_sender.id IS NULL THEN
    RAISE EXCEPTION 'outbound allow: send must succeed when recipient in sender allow list';
  END IF;

  RAISE NOTICE 'reception_outbound_gate_smoke_ok';
END $$;
