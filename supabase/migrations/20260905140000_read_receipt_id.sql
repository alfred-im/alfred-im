-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Read receipt: id federativo dell'evento lettura sul messaggio (una per messaggio letto).
-- Nasce sulla copia del lettore; replicato identico sulla copia mittente dal worker.

alter table public.messages
  add column if not exists read_receipt_id uuid;

comment on column public.messages.read_receipt_id is
  'Identificativo federativo dell''evento lettura; assegnato sulla copia del lettore e replicato sulla copia mittente.';

create index if not exists messages_read_receipt_id_idx
  on public.messages (read_receipt_id)
  where read_receipt_id is not null;

-- ---------------------------------------------------------------------------
-- RPC: mark_peer_read — mint read_receipt_id on reader copy
-- ---------------------------------------------------------------------------

create or replace function public.mark_peer_read(p_peer_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
declare
  v_me uuid := auth.uid();
  v_lambda uuid;
  v_incoming_id uuid;
  v_read_receipt_id uuid;
  v_outbox_id uuid;
begin
  if v_me is null then
    raise exception 'not authenticated';
  end if;

  if p_peer_profile_id is null then
    raise exception 'peer required';
  end if;

  for v_lambda, v_incoming_id, v_read_receipt_id in
    update public.messages m
    set
      read_at = now(),
      read_receipt_id = gen_random_uuid()
    where m.archive_user_id = v_me
      and m.peer_profile_id = p_peer_profile_id
      and m.author_id = p_peer_profile_id
      and m.read_at is null
      and public.mailbox_has_renderable_content(m.body, m.content_type)
    returning m.logical_message_id, m.id, m.read_receipt_id
  loop
    insert into public.outbox (message_id, protocol, payload, status)
    values (
      v_incoming_id,
      'internal',
      jsonb_build_object(
        'event_kind', 'read_receipt',
        'logical_message_id', v_lambda,
        'read_receipt_id', v_read_receipt_id,
        'reader_id', v_me,
        'sender_profile_id', p_peer_profile_id
      ),
      'queued'
    )
    returning id into v_outbox_id;

    perform alfred_delivery.process_outbox(v_outbox_id);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Worker: propagate read_receipt_id + read_at to sender copy
-- ---------------------------------------------------------------------------

drop function if exists alfred_delivery.propagate_read_receipt(uuid, uuid);

create or replace function alfred_delivery.propagate_read_receipt(
  p_logical_message_id uuid,
  p_sender_profile_id uuid,
  p_read_receipt_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
begin
  if p_read_receipt_id is null then
    raise exception 'read_receipt_id required';
  end if;

  update public.messages sender_copy
  set
    read_at = coalesce(sender_copy.read_at, now()),
    read_receipt_id = p_read_receipt_id
  where sender_copy.archive_user_id = p_sender_profile_id
    and sender_copy.logical_message_id = p_logical_message_id
    and sender_copy.read_at is null;
end;
$$;

create or replace function alfred_delivery.process_read_receipt(p_outbox_id uuid)
returns void
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
declare
  v_outbox public.outbox;
  v_payload jsonb;
  v_read_receipt_id uuid;
begin
  v_outbox := alfred_delivery._claim_outbox(p_outbox_id);
  if v_outbox.status = 'completed' then
    return;
  end if;

  v_payload := v_outbox.payload;
  v_read_receipt_id := (v_payload ->> 'read_receipt_id')::uuid;

  if v_read_receipt_id is null then
    raise exception 'read_receipt outbox payload missing read_receipt_id';
  end if;

  perform alfred_delivery.propagate_read_receipt(
    (v_payload ->> 'logical_message_id')::uuid,
    (v_payload ->> 'sender_profile_id')::uuid,
    v_read_receipt_id
  );

  perform alfred_delivery._complete_outbox(p_outbox_id);
end;
$$;

revoke all on function alfred_delivery.propagate_read_receipt(uuid, uuid, uuid)
  from public, anon, authenticated;

revoke all on function alfred_delivery.process_read_receipt(uuid)
  from public, anon, authenticated;
