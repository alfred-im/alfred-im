-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- get_profiles: local batch + federated fallback row.

DO $$
DECLARE
  v_agent1 uuid := 'efd885fe-b36e-48fc-a796-0e3f153e40d6';
  v_local_count integer;
  v_federated_address text := 'remote@blackgate-im.fly.dev';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_agent1) THEN
    RAISE NOTICE 'get_profiles_smoke_skip missing agent1';
    RETURN;
  END IF;

  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', v_agent1::text, 'role', 'authenticated')::text,
    true
  );

  SELECT count(*) INTO v_local_count
  FROM public.get_profiles(array['ciagent2']) gp
  WHERE gp.address = 'ciagent2'
    AND gp.display_name IS NOT NULL;

  IF v_local_count <> 1 THEN
    RAISE EXCEPTION 'get_profiles local row expected, got %', v_local_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.get_profiles(array[v_federated_address]) gp
    WHERE gp.address = v_federated_address
      AND gp.display_name IS NULL
  ) THEN
    RAISE EXCEPTION 'get_profiles federated fallback row missing';
  END IF;

  RAISE NOTICE 'get_profiles_smoke_ok';
END $$;
