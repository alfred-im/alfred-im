-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Code review fixes: deny direct PostgREST UPDATE on messages, restore outbox FK,
-- drop dead objects when safe.

-- ---------------------------------------------------------------------------
-- 1. Security: no direct UPDATE on messages (mutations via SECURITY DEFINER RPC)
-- ---------------------------------------------------------------------------

drop policy if exists messages_update_own on public.messages;

-- ---------------------------------------------------------------------------
-- 2. Integrity: outbox.message_id → messages(id) ON DELETE CASCADE
--    (lost when messages was recreated in mailbox migration)
-- ---------------------------------------------------------------------------

do $do$
begin
  if not exists (
    select 1
    from pg_constraint c
    join pg_class rel on rel.oid = c.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'outbox'
      and c.contype = 'f'
      and c.conname = 'outbox_message_id_fkey'
  ) then
    alter table public.outbox
      add constraint outbox_message_id_fkey
      foreign key (message_id) references public.messages (id) on delete cascade;
  end if;
end $do$;

-- ---------------------------------------------------------------------------
-- 3. Dead objects (safe cleanup)
-- ---------------------------------------------------------------------------

drop table if exists public.platform_agent_smoke;

do $do$
begin
  if exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'message_delivery_status'
  ) and not exists (
    select 1
    from pg_attribute a
    join pg_class c on c.oid = a.attrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_type t on t.oid = a.atttypid
    where n.nspname = 'public'
      and t.typname = 'message_delivery_status'
      and not a.attisdropped
      and c.relkind = 'r'
  ) and not exists (
    select 1
    from pg_depend d
    join pg_type t on d.refobjid = t.oid
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'message_delivery_status'
      and d.classid = 'pg_proc'::regclass
  ) then
    drop type public.message_delivery_status;
  end if;
end $do$;

drop index if exists public.reception_allowlist_owner_id_idx;
