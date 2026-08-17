-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Mailbox schema smoke: owner archive, no legacy receipts.

DO $$
BEGIN
  IF to_regclass('public.message_read_receipts') IS NOT NULL THEN
    RAISE EXCEPTION 'message_read_receipts must be removed';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'messages' AND column_name = 'owner_id'
  ) THEN
    RAISE EXCEPTION 'messages.owner_id missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'messages' AND column_name = 'logical_message_id'
  ) THEN
    RAISE EXCEPTION 'messages.logical_message_id missing';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'messages' AND column_name = 'delivery_status'
  ) THEN
    RAISE EXCEPTION 'messages.delivery_status must be removed';
  END IF;

  IF to_regprocedure('public.mailbox_has_renderable_content(text,public.message_content_type)') IS NULL THEN
    RAISE EXCEPTION 'Missing mailbox_has_renderable_content';
  END IF;

  RAISE NOTICE 'mailbox_schema_smoke_ok';
END $$;
