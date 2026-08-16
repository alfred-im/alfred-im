-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- SYS-OWNER: profile_kind owner, account disable (ban), owner-only instance admin RPCs.

-- ---------------------------------------------------------------------------
-- Schema
-- ---------------------------------------------------------------------------

alter type public.profile_kind add value if not exists 'owner';

alter table public.profiles
  add column if not exists disabled_at timestamptz;

comment on column public.profiles.disabled_at is
  'When set, account cannot authenticate or send/receive messages.';

create index if not exists profiles_disabled_at_idx
  on public.profiles (disabled_at)
  where disabled_at is not null;

-- Owner accounts are assigned manually (SQL); never via public signup metadata.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_username text;
  v_display_name text;
  v_kind public.profile_kind := 'user';
  v_kind_raw text;
begin
  v_username := lower(new.raw_user_meta_data ->> 'username');
  v_username := regexp_replace(coalesce(v_username, ''), '[^a-z0-9_]', '_', 'g');

  if length(v_username) < 3 then
    v_username := 'user_' || substr(replace(new.id::text, '-', ''), 1, 8);
  end if;

  v_display_name := coalesce(
    new.raw_user_meta_data ->> 'display_name',
    initcap(replace(v_username, '_', ' '))
  );

  v_kind_raw := lower(coalesce(new.raw_user_meta_data ->> 'profile_kind', ''));
  if v_kind_raw = 'group' then
    v_kind := 'group';
  end if;

  insert into public.profiles (id, username, display_name, profile_kind)
  values (new.id, v_username, v_display_name, v_kind)
  on conflict (id) do nothing;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.is_profile_disabled(p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = p_profile_id
      and p.disabled_at is not null
  );
$$;

revoke all on function public.is_profile_disabled(uuid) from public, anon, authenticated;

create or replace function public.assert_profile_active(p_profile_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if public.is_profile_disabled(p_profile_id) then
    raise exception 'account disabled';
  end if;
end;
$$;

revoke all on function public.assert_profile_active(uuid) from public, anon, authenticated;

create or replace function public.is_instance_owner()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.profile_kind::text = 'owner'
      and p.disabled_at is null
  );
$$;

revoke all on function public.is_instance_owner() from public, anon, authenticated;

create or replace function public.require_instance_owner()
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_instance_owner() then
    raise exception 'owner required';
  end if;
end;
$$;

revoke all on function public.require_instance_owner() from public, anon, authenticated;

create or replace function public.assert_session_active()
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  perform public.assert_profile_active(auth.uid());
end;
$$;

revoke all on function public.assert_session_active() from public;
grant execute on function public.assert_session_active() to authenticated;

-- ---------------------------------------------------------------------------
-- Moderation
-- ---------------------------------------------------------------------------

create or replace function public.ban_profile(p_target_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_instance_owner();

  if p_target_profile_id is null then
    raise exception 'target required';
  end if;

  if p_target_profile_id = auth.uid() then
    raise exception 'cannot ban self';
  end if;

  if not exists (select 1 from public.profiles where id = p_target_profile_id) then
    raise exception 'profile not found';
  end if;

  if public.profile_kind_of(p_target_profile_id)::text = 'owner' then
    raise exception 'cannot ban owner account';
  end if;

  update public.profiles
  set disabled_at = now(), updated_at = now()
  where id = p_target_profile_id
    and disabled_at is null;
end;
$$;

revoke all on function public.ban_profile(uuid) from public;
grant execute on function public.ban_profile(uuid) to authenticated;

create or replace function public.unban_profile(p_target_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_instance_owner();

  if p_target_profile_id is null then
    raise exception 'target required';
  end if;

  update public.profiles
  set disabled_at = null, updated_at = now()
  where id = p_target_profile_id;
end;
$$;

revoke all on function public.unban_profile(uuid) from public;
grant execute on function public.unban_profile(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Instance config (owner write)
-- ---------------------------------------------------------------------------

create or replace function public.list_instance_config()
returns table (
  key text,
  value jsonb,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select c.key, c.value, c.updated_at
  from public.instance_config c
  where public.is_instance_owner()
  order by c.key;
$$;

revoke all on function public.list_instance_config() from public;
grant execute on function public.list_instance_config() to authenticated;

create or replace function public.upsert_instance_config(
  p_key text,
  p_value jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_instance_owner();

  if p_key is null or trim(p_key) = '' then
    raise exception 'key required';
  end if;

  if p_key !~ '^instance\.' then
    raise exception 'key must start with instance.';
  end if;

  if p_value is null then
    raise exception 'value required';
  end if;

  insert into public.instance_config (key, value, updated_at)
  values (p_key, p_value, now())
  on conflict (key) do update
    set value = excluded.value,
        updated_at = now();
end;
$$;

revoke all on function public.upsert_instance_config(text, jsonb) from public;
grant execute on function public.upsert_instance_config(text, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- Instance statistics (owner read)
-- ---------------------------------------------------------------------------

create or replace function public.get_instance_stats()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'total_user_accounts',
      (select count(*)::integer from public.profiles p
       where p.profile_kind::text in ('user', 'owner')),
    'total_groups',
      (select count(*)::integer from public.profiles p
       where p.profile_kind::text = 'group'),
    'disabled_accounts',
      (select count(*)::integer from public.profiles p
       where p.disabled_at is not null),
    'total_messages',
      (select count(*)::bigint from public.messages),
    'messages_last_7_days',
      (select count(*)::bigint from public.messages m
       where m.created_at >= now() - interval '7 days'),
    'active_accounts_30d',
      (select count(distinct m.archive_user_id)::integer from public.messages m
       where m.created_at >= now() - interval '30 days')
  )
  where public.is_instance_owner();
$$;

revoke all on function public.get_instance_stats() from public;
grant execute on function public.get_instance_stats() to authenticated;

-- ---------------------------------------------------------------------------
-- Profile lookup: hide disabled peers unless viewer is owner
-- ---------------------------------------------------------------------------

drop function if exists public.find_profile_by_username(text);

create or replace function public.find_profile_by_username(p_username text)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  cover_url text,
  pronouns text,
  profile_kind public.profile_kind,
  peer_in_contacts boolean,
  peer_is_allowed boolean,
  peer_is_disabled boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.username,
    p.display_name,
    p.avatar_url,
    p.cover_url,
    p.pronouns,
    p.profile_kind,
    coalesce(rel.peer_in_contacts, false) as peer_in_contacts,
    coalesce(rel.peer_is_allowed, false) as peer_is_allowed,
    (p.disabled_at is not null) as peer_is_disabled
  from public.profiles p
  left join lateral public.peer_relationship_for_viewer(p.id) rel on true
  where auth.uid() is not null
    and p.id <> auth.uid()
    and lower(p.username) = lower(trim(p_username))
    and (p.disabled_at is null or public.is_instance_owner())
  limit 1;
$$;

grant execute on function public.find_profile_by_username(text) to authenticated;
revoke all on function public.find_profile_by_username(text) from public, anon;

drop function if exists public.search_profiles(text, integer);

create or replace function public.search_profiles(p_query text, p_limit integer default 20)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  peer_in_contacts boolean,
  peer_is_allowed boolean,
  peer_is_disabled boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.username,
    p.display_name,
    p.avatar_url,
    coalesce(rel.peer_in_contacts, false) as peer_in_contacts,
    coalesce(rel.peer_is_allowed, false) as peer_is_allowed,
    (p.disabled_at is not null) as peer_is_disabled
  from public.profiles p
  left join lateral public.peer_relationship_for_viewer(p.id) rel on true
  where auth.uid() is not null
    and p.id <> auth.uid()
    and (p.disabled_at is null or public.is_instance_owner())
    and (
      p.username ilike '%' || p_query || '%'
      or p.display_name ilike '%' || p_query || '%'
    )
  order by p.display_name
  limit greatest(1, least(p_limit, 50));
$$;

grant execute on function public.search_profiles(text, integer) to authenticated;
revoke all on function public.search_profiles(text, integer) from anon;

drop function if exists public.get_peer_context(uuid);

create or replace function public.get_peer_context(p_peer_profile_id uuid)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  cover_url text,
  pronouns text,
  profile_kind public.profile_kind,
  peer_in_contacts boolean,
  peer_is_allowed boolean,
  peer_is_disabled boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.username,
    p.display_name,
    p.avatar_url,
    p.cover_url,
    p.pronouns,
    p.profile_kind,
    coalesce(rel.peer_in_contacts, false) as peer_in_contacts,
    coalesce(rel.peer_is_allowed, false) as peer_is_allowed,
    (p.disabled_at is not null) as peer_is_disabled
  from public.profiles p
  left join lateral public.peer_relationship_for_viewer(p.id) rel on true
  where auth.uid() is not null
    and p.id = p_peer_profile_id
    and p.id <> auth.uid()
    and (p.disabled_at is null or public.is_instance_owner())
  limit 1;
$$;

grant execute on function public.get_peer_context(uuid) to authenticated;
revoke all on function public.get_peer_context(uuid) from public, anon;

-- ---------------------------------------------------------------------------
-- Messaging gate: disabled accounts cannot send or receive
-- ---------------------------------------------------------------------------

create or replace function public.send_message_to_profile(
  p_recipient_profile_id uuid,
  p_body text default '',
  p_client_message_id text default null,
  p_content_type public.message_content_type default 'text',
  p_media_url text default null,
  p_duration_seconds integer default null,
  p_media_mime text default null,
  p_media_size_bytes bigint default null,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns public.messages
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
declare
  v_me uuid := auth.uid();
  v_lambda uuid;
  v_sender_id uuid;
  v_row public.messages;
  v_body text := coalesce(p_body, '');
  v_media_url text := nullif(trim(coalesce(p_media_url, '')), '');
  v_media_mime text := nullif(trim(coalesce(p_media_mime, '')), '');
  v_recipient_kind public.profile_kind;
  v_sender_kind public.profile_kind;
  v_content_author uuid;
  v_outbox_id uuid;
  v_outbox_payload jsonb;
begin
  if v_me is null then
    raise exception 'not authenticated';
  end if;

  perform public.assert_profile_active(v_me);

  if p_recipient_profile_id is null then
    raise exception 'recipient required';
  end if;

  if p_recipient_profile_id = v_me then
    raise exception 'cannot message yourself';
  end if;

  if not exists (select 1 from public.profiles where id = p_recipient_profile_id) then
    raise exception 'recipient not found';
  end if;

  perform public.assert_profile_active(p_recipient_profile_id);

  if p_client_message_id is not null then
    select m.id into v_sender_id
    from public.messages m
    where m.archive_user_id = v_me
      and m.client_message_id = p_client_message_id
    limit 1;

    if v_sender_id is not null then
      select * into v_row from public.messages where id = v_sender_id;
      return v_row;
    end if;
  end if;

  if not public.is_sender_allowed_for_reception(v_me, p_recipient_profile_id) then
    raise exception 'recipient not in reception allowlist';
  end if;

  if p_content_type = 'text' then
    if length(trim(v_body)) = 0 then
      raise exception 'empty message';
    end if;
  elsif p_content_type = 'gif' then
    if v_media_url is null then
      raise exception 'gif requires media_url';
    end if;
  elsif p_content_type = 'image' then
    if v_media_url is null then
      raise exception 'image requires media_url';
    end if;
    if v_media_mime is null then
      raise exception 'image requires media_mime';
    end if;
    if v_media_mime not in ('image/jpeg', 'image/png', 'image/webp') then
      raise exception 'invalid image media_mime';
    end if;
    if p_media_size_bytes is not null and p_media_size_bytes <= 0 then
      raise exception 'invalid media_size_bytes';
    end if;
  elsif p_content_type = 'video' then
    if v_media_url is null then
      raise exception 'video requires media_url';
    end if;
    if v_media_mime is null then
      raise exception 'video requires media_mime';
    end if;
    if v_media_mime not in ('video/mp4', 'video/webm') then
      raise exception 'invalid video media_mime';
    end if;
    if p_duration_seconds is null or p_duration_seconds <= 0 then
      raise exception 'video requires duration_seconds';
    end if;
    if p_media_size_bytes is not null and p_media_size_bytes <= 0 then
      raise exception 'invalid media_size_bytes';
    end if;
  elsif p_content_type = 'voice' then
    if v_media_url is null then
      raise exception 'voice requires media_url';
    end if;
    if p_duration_seconds is null or p_duration_seconds <= 0 then
      raise exception 'voice requires duration_seconds';
    end if;
    if v_media_mime is null then
      raise exception 'voice requires media_mime';
    end if;
    if p_media_size_bytes is not null and p_media_size_bytes <= 0 then
      raise exception 'invalid media_size_bytes';
    end if;
  elsif p_content_type = 'location' then
    if p_latitude is null or p_longitude is null then
      raise exception 'location requires latitude and longitude';
    end if;
    if p_latitude < -90 or p_latitude > 90 then
      raise exception 'invalid latitude';
    end if;
    if p_longitude < -180 or p_longitude > 180 then
      raise exception 'invalid longitude';
    end if;
  else
    raise exception 'unsupported content_type';
  end if;

  v_recipient_kind := public.profile_kind_of(p_recipient_profile_id);
  v_sender_kind := public.profile_kind_of(v_me);
  v_content_author := case
    when v_recipient_kind = 'group' or v_sender_kind = 'group' then v_me
    else null
  end;
  v_lambda := gen_random_uuid();

  insert into public.messages (
    archive_user_id,
    author_id,
    original_author_id,
    peer_profile_id,
    logical_message_id,
    client_message_id,
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
    v_me,
    v_me,
    v_content_author,
    p_recipient_profile_id,
    v_lambda,
    p_client_message_id,
    'internal',
    trim(v_body),
    p_content_type,
    v_media_url,
    p_duration_seconds,
    v_media_mime,
    p_media_size_bytes,
    p_latitude,
    p_longitude
  )
  returning id into v_sender_id;

  v_outbox_payload := jsonb_build_object(
    'event_kind', 'deliver',
    'logical_message_id', v_lambda,
    'sender_id', v_me,
    'recipient_profile_id', p_recipient_profile_id,
    'body', trim(v_body),
    'content_type', p_content_type,
    'media_url', v_media_url,
    'media_mime', v_media_mime,
    'media_size_bytes', p_media_size_bytes,
    'duration_seconds', p_duration_seconds,
    'latitude', p_latitude,
    'longitude', p_longitude,
    'client_message_id', p_client_message_id
  );

  insert into public.outbox (message_id, protocol, payload, status)
  values (v_sender_id, 'internal', v_outbox_payload, 'queued')
  returning id into v_outbox_id;

  perform alfred_delivery.process_outbox(v_outbox_id);

  select * into v_row from public.messages where id = v_sender_id;
  return v_row;
end;
$$;

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
  v_is_group boolean;
  v_original_author_id uuid;
  v_row_count integer;
begin
  v_outbox := alfred_delivery._claim_outbox(p_outbox_id);
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

  if public.is_profile_disabled(v_sender.archive_user_id)
     or public.is_profile_disabled(v_recipient_id) then
    perform alfred_delivery._complete_outbox(p_outbox_id);
    return;
  end if;

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
  v_sender_kind := public.profile_kind_of(v_sender.archive_user_id);
  v_content_author := case
    when v_recipient_kind = 'group' or v_sender_kind = 'group' then v_sender.archive_user_id
    else null
  end;

  v_is_group := v_recipient_kind = 'group';
  v_original_author_id := case
    when v_is_group then v_sender.archive_user_id
    else v_content_author
  end;

  if v_is_group then
    v_allowed := public.is_bidirectional_allowed(
      v_recipient_id,
      v_sender.archive_user_id,
      v_sender.archive_user_id
    );
  else
    v_allowed := public.is_sender_allowed_for_reception(v_recipient_id, v_sender.archive_user_id);
  end if;

  if v_allowed then
    v_row_count := alfred_delivery._insert_recipient_copy(
      v_recipient_id,
      v_sender.archive_user_id,
      v_original_author_id,
      v_sender.archive_user_id,
      v_lambda,
      coalesce(v_sender.protocol, 'internal'::public.contact_protocol),
      v_body,
      v_content_type,
      v_payload,
      v_sender
    );

    update public.messages
    set delivered_at = now()
    where id = v_sender_id
      and delivered_at is null;

    if v_is_group then
      perform alfred_delivery.erogate_group_message(
        v_recipient_id,
        v_sender.archive_user_id,
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
        v_sender.archive_user_id,
        v_lambda,
        v_content_type,
        v_body,
        v_sender.archive_user_id
      );
    elsif v_row_count > 0 then
      perform alfred_delivery.queue_push_after_delivery(
        v_recipient_id,
        v_sender.archive_user_id,
        v_lambda,
        v_content_type,
        v_body,
        v_content_author
      );
    end if;

    perform alfred_delivery._complete_outbox(p_outbox_id);
  else
    perform alfred_delivery._complete_outbox(
      p_outbox_id,
      v_payload || jsonb_build_object('reception_rejected', true)
    );
  end if;
end;
$$;
