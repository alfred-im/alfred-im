-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Profile cover image (SYS-PROFILE): cover_url on profiles + RPC exposure.

alter table public.profiles
  add column if not exists cover_url text;

comment on column public.profiles.cover_url is
  'Public cover/banner image URL (bucket avatars, path {userId}/cover.{ext})';

drop function if exists public.list_inbox();

create or replace function public.list_inbox()
returns table (
  protocol public.contact_protocol,
  display_name text,
  peer_profile_id uuid,
  peer_external_address text,
  peer_avatar_url text,
  peer_cover_url text,
  peer_pronouns text,
  peer_profile_kind public.profile_kind,
  last_message_preview text,
  last_message_at timestamptz,
  unread_count integer
)
language sql
stable
security definer
set search_path = public
as $$
  with me as (
    select auth.uid() as uid
  ),
  direct as (
    select
      m.protocol,
      m.peer_profile_id,
      m.peer_external_address,
      m.created_at,
      m.content_type,
      m.body,
      m.duration_seconds,
      m.author_id,
      m.archive_user_id,
      m.read_at
    from public.messages m
    cross join me
    where me.uid is not null
      and m.archive_user_id = me.uid
      and m.protocol = 'internal'
      and m.peer_profile_id is not null
      and public.mailbox_has_renderable_content(m.body, m.content_type)
  ),
  latest as (
    select distinct on (d.peer_profile_id)
      d.protocol,
      d.peer_profile_id,
      d.peer_external_address,
      d.created_at as last_message_at,
      d.content_type,
      d.body,
      d.duration_seconds
    from direct d
    order by d.peer_profile_id, d.created_at desc
  ),
  unread as (
    select
      d.peer_profile_id,
      count(*)::integer as unread_count
    from direct d
    where d.author_id <> d.archive_user_id
      and d.read_at is null
    group by d.peer_profile_id
  )
  select
    l.protocol,
    coalesce(nullif(trim(p.display_name), ''), 'Contatto') as display_name,
    l.peer_profile_id,
    l.peer_external_address,
    p.avatar_url as peer_avatar_url,
    p.cover_url as peer_cover_url,
    p.pronouns as peer_pronouns,
    coalesce(p.profile_kind, 'user'::public.profile_kind) as peer_profile_kind,
    case
      when l.content_type = 'gif' then '[GIF]'
      when l.content_type = 'image' then
        case
          when length(trim(l.body)) > 0 then '📷 ' || left(trim(l.body), 100)
          else '📷 Foto'
        end
      when l.content_type = 'video' then
        case
          when length(trim(l.body)) > 0 then '🎬 ' || left(trim(l.body), 100)
          else '🎬 Video'
        end
      when l.content_type = 'voice' then public.format_voice_preview(coalesce(l.duration_seconds, 0))
      when l.content_type = 'location' then public.format_location_preview()
      else left(trim(l.body), 120)
    end as last_message_preview,
    l.last_message_at,
    coalesce(u.unread_count, 0) as unread_count
  from latest l
  left join public.profiles p on p.id = l.peer_profile_id
  left join unread u on u.peer_profile_id = l.peer_profile_id
  order by l.last_message_at desc nulls last;
$$;

grant execute on function public.list_inbox() to authenticated;
revoke all on function public.list_inbox() from anon;

drop function if exists public.find_profile_by_username(text);

create or replace function public.find_profile_by_username(p_username text)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  cover_url text,
  pronouns text,
  profile_kind public.profile_kind
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
    p.profile_kind
  from public.profiles p
  where auth.uid() is not null
    and p.id <> auth.uid()
    and lower(p.username) = lower(trim(p_username))
  limit 1;
$$;

grant execute on function public.find_profile_by_username(text) to authenticated;
revoke all on function public.find_profile_by_username(text) from public, anon;
