-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- SYS-PUSH: push_subscriptions + delivery hook push_notify

create extension if not exists pg_net with schema extensions;

-- ---------------------------------------------------------------------------
-- Preview text (allineato a client/lib/utils/message_preview.dart)
-- ---------------------------------------------------------------------------

create or replace function public.message_preview_text(
  p_content_type public.message_content_type,
  p_body text
)
returns text
language sql
immutable
as $$
  select case p_content_type
    when 'gif' then '[GIF]'
    when 'voice' then '🎤'
    when 'location' then '📍 Posizione'
    when 'image' then
      case
        when length(trim(coalesce(p_body, ''))) > 0 then '📷 ' || trim(p_body)
        else '📷 Foto'
      end
    when 'video' then
      case
        when length(trim(coalesce(p_body, ''))) > 0 then '🎬 ' || trim(p_body)
        else '🎬 Video'
      end
    else left(trim(coalesce(p_body, '')), 240)
  end;
$$;

-- ---------------------------------------------------------------------------
-- push_subscriptions
-- ---------------------------------------------------------------------------

create table public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  device_id uuid not null,
  endpoint text not null,
  p256dh_key text not null,
  auth_key text not null,
  user_agent text,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  constraint push_subscriptions_user_device_unique unique (user_id, device_id),
  constraint push_subscriptions_endpoint_unique unique (endpoint)
);

create index push_subscriptions_user_id_idx on public.push_subscriptions (user_id);

alter table public.push_subscriptions enable row level security;

create policy push_subscriptions_select_own on public.push_subscriptions
  for select to authenticated
  using (user_id = auth.uid());

create policy push_subscriptions_insert_own on public.push_subscriptions
  for insert to authenticated
  with check (user_id = auth.uid());

create policy push_subscriptions_update_own on public.push_subscriptions
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy push_subscriptions_delete_own on public.push_subscriptions
  for delete to authenticated
  using (user_id = auth.uid());

grant select, insert, update, delete on public.push_subscriptions to authenticated;

-- ---------------------------------------------------------------------------
-- Push dispatch settings (singleton)
-- ---------------------------------------------------------------------------

create table alfred_delivery.push_settings (
  singleton boolean primary key default true check (singleton),
  functions_base_url text not null default 'https://tvwpoxxcqwphryvuyqzu.supabase.co/functions/v1',
  dispatch_secret text,
  enabled boolean not null default true
);

insert into alfred_delivery.push_settings (singleton)
values (true)
on conflict (singleton) do nothing;

revoke all on table alfred_delivery.push_settings from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Queue + process push_notify
-- ---------------------------------------------------------------------------

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

revoke all on function alfred_delivery.queue_push_after_delivery(
  uuid, uuid, uuid, public.message_content_type, text, uuid
) from public, anon, authenticated;

create or replace function alfred_delivery.process_push_notify(p_outbox_id uuid)
returns void
language plpgsql
security definer
set search_path = public, alfred_delivery, extensions
as $$
declare
  v_outbox public.outbox;
  v_payload jsonb;
  v_settings alfred_delivery.push_settings;
  v_url text;
  v_headers jsonb;
begin
  select * into v_outbox from public.outbox where id = p_outbox_id for update;
  if v_outbox.id is null then
    raise exception 'outbox row not found';
  end if;

  if v_outbox.status = 'completed' then
    return;
  end if;

  v_payload := v_outbox.payload;

  select * into v_settings from alfred_delivery.push_settings where singleton is true;

  if coalesce(v_settings.enabled, false) then
    v_url := rtrim(v_settings.functions_base_url, '/') || '/send-push';
    v_headers := jsonb_build_object('Content-Type', 'application/json');
    if v_settings.dispatch_secret is not null and length(trim(v_settings.dispatch_secret)) > 0 then
      v_headers := v_headers || jsonb_build_object('X-Push-Dispatch-Secret', v_settings.dispatch_secret);
    end if;

    perform net.http_post(
      url := v_url,
      headers := v_headers,
      body := v_payload
    );
  end if;

  update public.outbox
  set status = 'completed', updated_at = now()
  where id = p_outbox_id;
end;
$$;

revoke all on function alfred_delivery.process_push_notify(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Patch erogate_group_message: push per partecipante
-- ---------------------------------------------------------------------------

create or replace function alfred_delivery.erogate_group_message(
  p_group_id uuid,
  p_original_author_id uuid,
  p_lambda uuid,
  p_protocol public.contact_protocol,
  p_body text,
  p_content_type public.message_content_type,
  p_media_url text,
  p_duration_seconds integer,
  p_media_mime text,
  p_media_size_bytes bigint,
  p_latitude double precision,
  p_longitude double precision
)
returns void
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
declare
  v_participant uuid;
  v_row_count integer;
begin
  for v_participant in
    select r.allowed_profile_id
    from public.reception_allowlist r
    where r.owner_id = p_group_id
      and r.allowed_profile_id is not null
      and r.allowed_profile_id <> p_group_id
      and r.allowed_profile_id <> p_original_author_id
  loop
    if not public.is_sender_allowed_for_reception(v_participant, p_group_id) then
      continue;
    end if;

    insert into public.messages (
      owner_id,
      author_id,
      original_author_id,
      peer_profile_id,
      logical_message_id,
      protocol,
      body,
      content_type,
      media_url,
      duration_seconds,
      media_mime,
      media_size_bytes,
      latitude,
      longitude
    )
    values (
      v_participant,
      p_group_id,
      p_original_author_id,
      p_group_id,
      p_lambda,
      p_protocol,
      p_body,
      p_content_type,
      p_media_url,
      p_duration_seconds,
      p_media_mime,
      p_media_size_bytes,
      p_latitude,
      p_longitude
    )
    on conflict (owner_id, logical_message_id) do nothing;

    get diagnostics v_row_count = row_count;

    if v_row_count > 0 then
      perform alfred_delivery.queue_push_after_delivery(
        v_participant,
        p_group_id,
        p_lambda,
        p_content_type,
        p_body,
        p_original_author_id
      );
    end if;
  end loop;
end;
$$;

revoke all on function alfred_delivery.erogate_group_message(
  uuid, uuid, uuid, public.contact_protocol, text, public.message_content_type,
  text, integer, text, bigint, double precision, double precision
) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Patch deliver_internal: push post-recapito
-- ---------------------------------------------------------------------------

create or replace function alfred_delivery.deliver_internal(p_outbox_id uuid)
returns void
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
declare
  v_outbox public.outbox;
  v_payload jsonb;
  v_sender_id uuid;
  v_sender public.messages;
  v_recipient_id uuid;
  v_recipient_kind public.profile_kind;
  v_sender_kind public.profile_kind;
  v_allowed boolean;
  v_lambda uuid;
  v_content_author uuid;
  v_body text;
  v_content_type public.message_content_type;
begin
  select * into v_outbox from public.outbox where id = p_outbox_id for update;
  if v_outbox.id is null then
    raise exception 'outbox row not found';
  end if;

  if v_outbox.status = 'completed' then
    return;
  end if;

  v_payload := v_outbox.payload;
  v_sender_id := v_outbox.message_id;

  select * into v_sender from public.messages where id = v_sender_id;
  if v_sender.id is null then
    raise exception 'sender message not found for outbox %', p_outbox_id;
  end if;

  v_recipient_id := (v_payload ->> 'recipient_profile_id')::uuid;
  v_lambda := coalesce(
    (v_payload ->> 'logical_message_id')::uuid,
    v_sender.logical_message_id
  );
  v_body := coalesce(v_payload ->> 'body', v_sender.body);
  v_content_type := coalesce(
    (v_payload ->> 'content_type')::public.message_content_type,
    v_sender.content_type
  );

  v_recipient_kind := public.profile_kind_of(v_recipient_id);
  v_sender_kind := public.profile_kind_of(v_sender.owner_id);
  v_content_author := case
    when v_recipient_kind = 'group' or v_sender_kind = 'group' then v_sender.owner_id
    else null
  end;

  if v_recipient_kind = 'group' then
    v_allowed :=
      public.is_sender_allowed_for_reception(v_recipient_id, v_sender.owner_id)
      and public.is_sender_allowed_for_reception(v_sender.owner_id, v_recipient_id);

    if v_allowed then
      insert into public.messages (
        owner_id,
        author_id,
        original_author_id,
        peer_profile_id,
        logical_message_id,
        protocol,
        body,
        content_type,
        media_url,
        duration_seconds,
        media_mime,
        media_size_bytes,
        latitude,
        longitude
      )
      values (
        v_recipient_id,
        v_sender.owner_id,
        v_sender.owner_id,
        v_sender.owner_id,
        v_lambda,
        coalesce(v_sender.protocol, 'internal'::public.contact_protocol),
        v_body,
        v_content_type,
        coalesce(v_payload ->> 'media_url', v_sender.media_url),
        coalesce((v_payload ->> 'duration_seconds')::integer, v_sender.duration_seconds),
        coalesce(v_payload ->> 'media_mime', v_sender.media_mime),
        coalesce((v_payload ->> 'media_size_bytes')::bigint, v_sender.media_size_bytes),
        coalesce((v_payload ->> 'latitude')::double precision, v_sender.latitude),
        coalesce((v_payload ->> 'longitude')::double precision, v_sender.longitude)
      )
      on conflict (owner_id, logical_message_id) do nothing;

      update public.messages
      set delivered_at = now()
      where id = v_sender_id
        and delivered_at is null;

      perform alfred_delivery.erogate_group_message(
        v_recipient_id,
        v_sender.owner_id,
        v_lambda,
        coalesce(v_sender.protocol, 'internal'::public.contact_protocol),
        v_body,
        v_content_type,
        coalesce(v_payload ->> 'media_url', v_sender.media_url),
        coalesce((v_payload ->> 'duration_seconds')::integer, v_sender.duration_seconds),
        coalesce(v_payload ->> 'media_mime', v_sender.media_mime),
        coalesce((v_payload ->> 'media_size_bytes')::bigint, v_sender.media_size_bytes),
        coalesce((v_payload ->> 'latitude')::double precision, v_sender.latitude),
        coalesce((v_payload ->> 'longitude')::double precision, v_sender.longitude)
      );

      perform alfred_delivery.queue_push_after_delivery(
        v_recipient_id,
        v_sender.owner_id,
        v_lambda,
        v_content_type,
        v_body,
        v_sender.owner_id
      );

      update public.outbox
      set status = 'completed', updated_at = now()
      where id = p_outbox_id;
    else
      update public.outbox
      set
        status = 'completed',
        payload = v_payload || jsonb_build_object('reception_rejected', true),
        updated_at = now()
      where id = p_outbox_id;
    end if;
  else
    v_allowed := public.is_sender_allowed_for_reception(v_recipient_id, v_sender.owner_id);

    if v_allowed then
      insert into public.messages (
        owner_id,
        author_id,
        original_author_id,
        peer_profile_id,
        logical_message_id,
        protocol,
        body,
        content_type,
        media_url,
        duration_seconds,
        media_mime,
        media_size_bytes,
        latitude,
        longitude
      )
      values (
        v_recipient_id,
        v_sender.owner_id,
        v_content_author,
        v_sender.owner_id,
        v_lambda,
        coalesce(v_sender.protocol, 'internal'::public.contact_protocol),
        v_body,
        v_content_type,
        coalesce(v_payload ->> 'media_url', v_sender.media_url),
        coalesce((v_payload ->> 'duration_seconds')::integer, v_sender.duration_seconds),
        coalesce(v_payload ->> 'media_mime', v_sender.media_mime),
        coalesce((v_payload ->> 'media_size_bytes')::bigint, v_sender.media_size_bytes),
        coalesce((v_payload ->> 'latitude')::double precision, v_sender.latitude),
        coalesce((v_payload ->> 'longitude')::double precision, v_sender.longitude)
      )
      on conflict (owner_id, logical_message_id) do nothing;

      update public.messages
      set delivered_at = now()
      where id = v_sender_id
        and delivered_at is null;

      perform alfred_delivery.queue_push_after_delivery(
        v_recipient_id,
        v_sender.owner_id,
        v_lambda,
        v_content_type,
        v_body,
        v_content_author
      );

      update public.outbox
      set status = 'completed', updated_at = now()
      where id = p_outbox_id;
    else
      update public.outbox
      set
        status = 'completed',
        payload = v_payload || jsonb_build_object('reception_rejected', true),
        updated_at = now()
      where id = p_outbox_id;
    end if;
  end if;
end;
$$;

revoke all on function alfred_delivery.deliver_internal(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Dispatcher: push_notify
-- ---------------------------------------------------------------------------

create or replace function alfred_delivery.process_outbox(p_outbox_id uuid)
returns void
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
declare
  v_kind text;
begin
  select coalesce(o.payload ->> 'event_kind', 'deliver')
  into v_kind
  from public.outbox o
  where o.id = p_outbox_id;

  if v_kind = 'read_receipt' then
    perform alfred_delivery.process_read_receipt(p_outbox_id);
  elsif v_kind = 'group_erogate' then
    perform alfred_delivery.group_erogate(p_outbox_id);
  elsif v_kind = 'push_notify' then
    perform alfred_delivery.process_push_notify(p_outbox_id);
  else
    perform alfred_delivery.deliver_internal(p_outbox_id);
  end if;
end;
$$;

revoke all on function alfred_delivery.process_outbox(uuid)
  from public, anon, authenticated;
