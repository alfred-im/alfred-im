-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- SYS-PUSH schema smoke

DO $$
BEGIN
  IF to_regclass('public.push_subscriptions') IS NULL THEN
    RAISE EXCEPTION 'Missing table push_subscriptions';
  END IF;

  IF to_regprocedure('public.message_preview_text(public.message_content_type, text)') IS NULL THEN
    RAISE EXCEPTION 'Missing function message_preview_text';
  END IF;

  IF to_regprocedure('alfred_delivery.queue_push_after_delivery(uuid, text, uuid, public.message_content_type, text, uuid)') IS NULL THEN
    RAISE EXCEPTION 'Missing function queue_push_after_delivery';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'push_subscriptions'
      AND policyname = 'push_subscriptions_select_own'
  ) THEN
    RAISE EXCEPTION 'Missing RLS policy push_subscriptions_select_own';
  END IF;

  RAISE NOTICE 'push_subscriptions_schema_smoke_ok';
END $$;
