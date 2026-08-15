-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Append-only reaction facts: apply, withdraw, change emoji, idempotency, cross-participant read.

DO $$
DECLARE
  v_agent1 uuid := 'efd885fe-b36e-48fc-a796-0e3f153e40d6';
  v_agent2 uuid := '0a81f785-173c-4f1c-b5df-3937086a2482';
  v_client_id text := 'smoke-reaction-' || floor(random() * 1000000)::text;
  v_sender public.messages;
  v_fact public.message_reaction_facts;
  v_fact2 public.message_reaction_facts;
  v_count bigint;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_agent1) THEN
    RAISE NOTICE 'message_reaction_facts_smoke_skip missing agent1';
    RETURN;
  END IF;

  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', v_agent1::text, 'role', 'authenticated')::text,
    true
  );

  INSERT INTO public.reception_allowlist (archive_user_id, allowed_profile_id)
  VALUES
    (v_agent1, v_agent2),
    (v_agent2, v_agent1)
  ON CONFLICT ON CONSTRAINT reception_allowlist_archive_user_allowed_unique DO NOTHING;

  SELECT * INTO v_sender FROM public.send_message_to_profile(
    v_agent2,
    'reaction smoke',
    v_client_id,
    'text'::public.message_content_type
  );

  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', v_agent2::text, 'role', 'authenticated')::text,
    true
  );

  SELECT * INTO v_fact FROM public.apply_message_reaction(
    v_sender.logical_message_id,
    E'\U0001F600'
  );

  IF v_fact.kind <> 'applied' OR v_fact.emoji <> E'\U0001F600' THEN
    RAISE EXCEPTION 'apply_message_reaction failed';
  END IF;

  SELECT * INTO v_fact2 FROM public.apply_message_reaction(
    v_sender.logical_message_id,
    E'\U0001F600'
  );

  IF v_fact2.id <> v_fact.id THEN
    RAISE EXCEPTION 'apply same emoji must be idempotent';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.message_reaction_facts f
  WHERE f.logical_message_id = v_sender.logical_message_id
    AND f.reactor_id = v_agent2;

  IF v_count <> 1 THEN
    RAISE EXCEPTION 'idempotent apply must not insert duplicate fact';
  END IF;

  SELECT * INTO v_fact FROM public.apply_message_reaction(
    v_sender.logical_message_id,
    E'\u2764'
  );

  IF v_fact.emoji <> E'\u2764' THEN
    RAISE EXCEPTION 'change emoji must insert new applied fact';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.message_reaction_facts f
  WHERE f.logical_message_id = v_sender.logical_message_id
    AND f.reactor_id = v_agent2;

  IF v_count <> 2 THEN
    RAISE EXCEPTION 'change emoji must preserve history (2 facts)';
  END IF;

  SELECT * INTO v_fact FROM public.withdraw_message_reaction(v_sender.logical_message_id);

  IF v_fact.kind <> 'withdrawn' OR v_fact.emoji IS NOT NULL THEN
    RAISE EXCEPTION 'withdraw must insert withdrawn fact';
  END IF;

  IF public.withdraw_message_reaction(v_sender.logical_message_id) IS NOT NULL THEN
    RAISE EXCEPTION 'withdraw without active reaction must be no-op';
  END IF;

  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', v_agent1::text, 'role', 'authenticated')::text,
    true
  );

  SELECT count(*) INTO v_count
  FROM public.list_message_reactions(ARRAY[v_sender.logical_message_id]);

  IF v_count <> 0 THEN
    RAISE EXCEPTION 'withdrawn reaction must not appear in current summaries';
  END IF;

  RAISE NOTICE 'message_reaction_facts_smoke_ok';
END $$;
