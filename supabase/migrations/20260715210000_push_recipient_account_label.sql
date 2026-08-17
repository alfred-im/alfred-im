-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- PROM-PUSH-NOTIFY: etichetta account destinatario nel payload push (multi-account stesso device)

create or replace function alfred_delivery.queue_push_after_delivery(
  p_recipient_user_id uuid,
  p_peer_profile_id uuid,
  p_logical_message_id uuid,
  p_content_type public.message_content_type,
  p_body text,
  p_original_author_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
declare
  v_recipient_message_id uuid;
  v_peer_name text;
  v_recipient_name text;
  v_recipient_username text;
  v_preview text;
  v_author_name text;
  v_payload jsonb;
  v_outbox_id uuid;
begin
  if p_recipient_user_id is null or p_peer_profile_id is null or p_logical_message_id is null then
    return;
  end if;

  if not exists (
    select 1 from public.push_subscriptions ps where ps.user_id = p_recipient_user_id
  ) then
    return;
  end if;

  select m.id
  into v_recipient_message_id
  from public.messages m
  where m.owner_id = p_recipient_user_id
    and m.logical_message_id = p_logical_message_id
  limit 1;

  if v_recipient_message_id is null then
    return;
  end if;

  select p.display_name into v_peer_name
  from public.profiles p
  where p.id = p_peer_profile_id;

  select p.display_name, p.username
  into v_recipient_name, v_recipient_username
  from public.profiles p
  where p.id = p_recipient_user_id;

  v_preview := public.message_preview_text(p_content_type, p_body);

  if p_original_author_id is not null
     and p_original_author_id <> p_peer_profile_id then
    select p.display_name into v_author_name
    from public.profiles p
    where p.id = p_original_author_id;

    if v_author_name is not null and length(trim(v_author_name)) > 0 then
      v_preview := v_author_name || ': ' || v_preview;
    end if;
  end if;

  v_payload := jsonb_build_object(
    'event_kind', 'push_notify',
    'recipient_user_id', p_recipient_user_id,
    'recipient_display_name', coalesce(v_recipient_name, 'Alfred'),
    'recipient_username', v_recipient_username,
    'peer_profile_id', p_peer_profile_id,
    'peer_display_name', coalesce(v_peer_name, 'Alfred'),
    'preview_text', v_preview,
    'logical_message_id', p_logical_message_id,
    'content_type', p_content_type::text
  );

  insert into public.outbox (message_id, protocol, payload, status)
  values (v_recipient_message_id, 'internal', v_payload, 'queued')
  returning id into v_outbox_id;

  perform alfred_delivery.process_push_notify(v_outbox_id);
end;
$$;
