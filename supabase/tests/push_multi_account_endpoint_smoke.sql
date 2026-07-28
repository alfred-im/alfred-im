-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- SYS-PUSH-003: multi-account stesso browser — stesso endpoint, user_id diversi

DO $$
DECLARE
  v_test1 uuid;
  v_test2 uuid;
  v_device uuid := 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
  v_endpoint text := 'https://push.test/shared-browser-endpoint';
BEGIN
  SELECT id INTO v_test1 FROM public.profiles WHERE username = 'ciagent1' LIMIT 1;
  SELECT id INTO v_test2 FROM public.profiles WHERE username = 'ciagent2' LIMIT 1;

  IF v_test1 IS NULL OR v_test2 IS NULL THEN
    RAISE NOTICE 'push_multi_account_endpoint_smoke_skip missing ciagent1/ciagent2';
    RETURN;
  END IF;

  INSERT INTO public.push_subscriptions (
    user_id, device_id, endpoint, p256dh_key, auth_key
  )
  VALUES
    (v_test1, v_device, v_endpoint, 'k1', 'a1'),
    (v_test2, v_device, v_endpoint, 'k1', 'a1')
  ON CONFLICT (user_id, device_id) DO UPDATE
    SET endpoint = excluded.endpoint,
        p256dh_key = excluded.p256dh_key,
        auth_key = excluded.auth_key,
        last_seen_at = now();

  IF (
    SELECT count(*) FROM public.push_subscriptions
    WHERE endpoint = v_endpoint AND user_id IN (v_test1, v_test2)
  ) < 2 THEN
    RAISE EXCEPTION 'expected two subscriptions on shared endpoint';
  END IF;

  DELETE FROM public.push_subscriptions
  WHERE device_id = v_device
    AND user_id IN (v_test1, v_test2);

  RAISE NOTICE 'push_multi_account_endpoint_smoke_ok';
END $$;
