-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- peer_in_contacts / peer_is_allowed on list_inbox, search_profiles, get_peer_context.

DO $$
DECLARE
  v_agent1 uuid := 'efd885fe-b36e-48fc-a796-0e3f153e40d6';
  v_agent2 uuid := '0a81f785-173c-4f1c-b5df-3937086a2482';
  v_in_contacts boolean;
  v_is_allowed boolean;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_agent1) THEN
    RAISE NOTICE 'peer_relationship_smoke_skip missing agent profiles';
    RETURN;
  END IF;

  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', v_agent1::text, 'role', 'authenticated')::text,
    true
  );

  INSERT INTO public.contacts (
    owner_id,
    protocol,
    linked_profile_id,
    display_name
  )
  VALUES (v_agent1, 'internal', v_agent2, 'Agent 2')
  ON CONFLICT DO NOTHING;

  INSERT INTO public.reception_allowlist (owner_id, allowed_profile_id)
  VALUES (v_agent1, v_agent2)
  ON CONFLICT ON CONSTRAINT reception_allowlist_owner_allowed_unique DO NOTHING;

  SELECT i.peer_in_contacts, i.peer_is_allowed
  INTO v_in_contacts, v_is_allowed
  FROM public.get_peer_context(v_agent2) i;

  IF coalesce(v_in_contacts, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'get_peer_context peer_in_contacts expected true';
  END IF;

  IF coalesce(v_is_allowed, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'get_peer_context peer_is_allowed expected true';
  END IF;

  SELECT s.peer_in_contacts, s.peer_is_allowed
  INTO v_in_contacts, v_is_allowed
  FROM public.search_profiles('agent', 20) s
  WHERE s.id = v_agent2
  LIMIT 1;

  IF coalesce(v_in_contacts, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'search_profiles peer_in_contacts expected true';
  END IF;

  RAISE NOTICE 'peer_relationship_smoke_ok';
END $$;
