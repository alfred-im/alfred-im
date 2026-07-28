-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- SYS-PUSH RLS smoke (cross-user denied)

DO $$
DECLARE
  v_agent1 uuid := 'efd885fe-b36e-48fc-a796-0e3f153e40d6';
  v_agent2 uuid := '0a81f785-173c-4f1c-b5df-3937086a2482';
  v_rows integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_agent1) THEN
    RAISE NOTICE 'push_subscriptions_rls_smoke_skip missing agent1';
    RETURN;
  END IF;

  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', v_agent2::text, 'role', 'authenticated')::text,
    true
  );
  SET LOCAL ROLE authenticated;

  SELECT count(*) INTO v_rows
  FROM public.push_subscriptions
  WHERE user_id = v_agent1;

  RESET ROLE;

  IF v_rows <> 0 THEN
    RAISE EXCEPTION 'agent2 must not read agent1 push subscriptions';
  END IF;

  RAISE NOTICE 'push_subscriptions_rls_smoke_ok';
END $$;
