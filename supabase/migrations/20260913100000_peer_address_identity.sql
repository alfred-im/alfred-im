-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- §7 peer_address identity: messages, reception_allowlist, contacts, RPCs, delivery helpers.

-- ---------------------------------------------------------------------------
-- Address helpers (internal + account RPCs)
-- ---------------------------------------------------------------------------

create or replace function public.instance_im_server_id()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select lower(trim(both '"' from coalesce(
    (
      select c.value #>> '{}'
      from public.instance_config c
      where c.key = 'instance.im_server_id'
    ),
    'localhost'
  )));
$$;

revoke all on function public.instance_im_server_id() from public, anon, authenticated;

create or replace function public.normalize_address(p_address text)
returns text
language sql
immutable
as $$
  select lower(trim(coalesce(p_address, '')));
$$;

create or replace function public.profile_bare_address(p_profile_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select lower(p.username)
  from public.profiles p
  where p.id = p_profile_id;
$$;

revoke all on function public.profile_bare_address(uuid) from public, anon, authenticated;

create or replace function public.profile_fqdn_address(p_profile_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select public.profile_bare_address(p_profile_id)
    || '@' || public.instance_im_server_id();
$$;

revoke all on function public.profile_fqdn_address(uuid) from public, anon, authenticated;

create or replace function public.is_external_address(p_address text)
returns boolean
language sql
stable
as $$
  select
    position('@' in public.normalize_address(p_address)) > 0
    and split_part(public.normalize_address(p_address), '@', 2)
      <> public.instance_im_server_id();
$$;

create or replace function public.resolve_local_profile_id(p_address text)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  with normalized as (
    select public.normalize_address(p_address) as addr
  )
  select p.id
  from normalized n
  join public.profiles p on lower(p.username) = case
    when position('@' in n.addr) > 0 then split_part(n.addr, '@', 1)
    else n.addr
  end
  where n.addr <> ''
    and (
      position('@' in n.addr) = 0
      or split_part(n.addr, '@', 2) = public.instance_im_server_id()
    )
  limit 1;
$$;

revoke all on function public.resolve_local_profile_id(text) from public, anon, authenticated;

create or replace function public.sender_author_address(
  p_sender_id uuid,
  p_peer_address text
)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when public.is_external_address(p_peer_address) then public.profile_fqdn_address(p_sender_id)
    when position('@' in public.normalize_address(p_peer_address)) > 0 then public.profile_fqdn_address(p_sender_id)
    else public.profile_bare_address(p_sender_id)
  end;
$$;

revoke all on function public.sender_author_address(uuid, text) from public, anon, authenticated;

create or replace function public.mailbox_is_incoming(
  p_archive_user_id uuid,
  p_author_id uuid,
  p_author_address text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.normalize_address(p_author_address) is distinct from public.profile_bare_address(p_archive_user_id)
    and public.normalize_address(p_author_address) is distinct from public.profile_fqdn_address(p_archive_user_id);
$$;

revoke all on function public.mailbox_is_incoming(uuid, uuid, text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- messages: peer_address + author_address
-- ---------------------------------------------------------------------------

alter table public.messages
  add column if not exists peer_address text,
  add column if not exists author_address text;

update public.messages m
set
  peer_address = case
    when m.peer_external_address is not null then public.normalize_address(m.peer_external_address)
    when m.peer_profile_id is not null then public.profile_bare_address(m.peer_profile_id)
    else null
  end,
  author_address = coalesce(
    public.profile_bare_address(m.author_id),
    'unknown'
  )
where m.peer_address is null
   or m.author_address is null;

alter table public.messages
  alter column author_address set not null;

alter table public.messages
  alter column author_id drop not null;

drop index if exists public.messages_archive_user_peer_created_idx;

create index messages_archive_user_peer_address_created_idx
  on public.messages (archive_user_id, peer_address, created_at desc);

alter table public.messages
  drop column if exists peer_profile_id,
  drop column if exists peer_external_address;

-- ---------------------------------------------------------------------------
-- reception_allowlist: allowed_address
-- ---------------------------------------------------------------------------

alter table public.reception_allowlist
  add column if not exists allowed_address text;

update public.reception_allowlist r
set allowed_address = public.profile_bare_address(r.allowed_profile_id)
where r.allowed_address is null
  and r.allowed_profile_id is not null;

alter table public.reception_allowlist
  drop constraint if exists reception_allowlist_not_self;

alter table public.reception_allowlist
  drop constraint if exists reception_allowlist_archive_user_allowed_unique;

drop policy if exists reception_allowlist_insert_own on public.reception_allowlist;

alter table public.reception_allowlist
  drop column if exists allowed_profile_id;

alter table public.reception_allowlist
  alter column allowed_address set not null;

alter table public.reception_allowlist
  add constraint reception_allowlist_archive_user_allowed_unique
    unique (archive_user_id, allowed_address);

create policy reception_allowlist_insert_own
  on public.reception_allowlist for insert to authenticated
  with check (
    archive_user_id = auth.uid()
    and allowed_address <> coalesce(public.profile_bare_address(auth.uid()), '')
  );

create or replace function public.reception_allowlist_prevent_self()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.allowed_address = public.profile_bare_address(new.archive_user_id) then
    raise exception 'cannot allow self';
  end if;
  return new;
end;
$$;

drop trigger if exists reception_allowlist_prevent_self_trg on public.reception_allowlist;

create trigger reception_allowlist_prevent_self_trg
  before insert or update on public.reception_allowlist
  for each row execute function public.reception_allowlist_prevent_self();

create or replace function public.is_address_allowed_for_reception(
  p_archive_user_id uuid,
  p_allowed_address text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.reception_allowlist r
    where r.archive_user_id = p_archive_user_id
      and r.allowed_address = public.normalize_address(p_allowed_address)
  );
$$;

revoke all on function public.is_address_allowed_for_reception(uuid, text)
  from public, anon, authenticated;

drop function if exists public.is_bidirectional_allowed(uuid, uuid, uuid);

create or replace function public.is_bidirectional_allowed(
  p_archive_user_a uuid,
  p_archive_user_b uuid,
  p_sender uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_address_allowed_for_reception(
      p_archive_user_a,
      public.profile_bare_address(p_sender)
    )
    and public.is_address_allowed_for_reception(
      p_archive_user_b,
      public.profile_bare_address(p_archive_user_a)
    );
$$;

revoke all on function public.is_bidirectional_allowed(uuid, uuid, uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- contacts: address only
-- ---------------------------------------------------------------------------

alter table public.contacts
  add column if not exists address text;

update public.contacts c
set address = case
  when c.external_address is not null then public.normalize_address(c.external_address)
  when c.linked_profile_id is not null then public.profile_bare_address(c.linked_profile_id)
  else null
end
where c.address is null;

delete from public.contacts
where address is null;

alter table public.contacts
  drop constraint if exists contacts_shape;

drop index if exists public.contacts_archive_user_linked_profile_idx;
drop index if exists public.contacts_archive_user_external_address_idx;

alter table public.contacts
  drop column if exists linked_profile_id,
  drop column if exists external_address,
  drop column if exists display_name,
  drop column if exists avatar_url;

alter table public.contacts
  alter column address set not null;

alter table public.contacts
  add constraint contacts_archive_user_address_unique unique (archive_user_id, address);

-- ---------------------------------------------------------------------------
-- Drop legacy UUID conversation RPCs / helpers
-- ---------------------------------------------------------------------------

drop function if exists public.send_message_to_profile(
  uuid, text, text, public.message_content_type, text, integer, text, bigint, double precision, double precision
);

drop function if exists public.mark_peer_read(uuid);

drop function if exists public.list_peer_messages(uuid, integer, timestamptz);

drop function if exists public.get_peer_context(uuid);

drop function if exists public.peer_relationship_for_viewer(uuid);

drop function if exists public.is_sender_allowed_for_reception(uuid, uuid);

drop function if exists public.list_inbox();

drop function if exists public.find_profile_by_username(text);

drop function if exists public.search_profiles(text, integer);

-- ---------------------------------------------------------------------------
-- Relationship flags (address-based)
-- ---------------------------------------------------------------------------

create or replace function public.peer_relationship_for_viewer(p_peer_address text)
returns table (
  peer_in_contacts boolean,
  peer_is_allowed boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    exists (
      select 1
      from public.contacts c
      where c.archive_user_id = auth.uid()
        and c.address = public.normalize_address(p_peer_address)
    ) as peer_in_contacts,
    exists (
      select 1
      from public.reception_allowlist r
      where r.archive_user_id = auth.uid()
        and r.allowed_address = public.normalize_address(p_peer_address)
    ) as peer_is_allowed
  where auth.uid() is not null
    and public.normalize_address(p_peer_address) <> ''
    and public.normalize_address(p_peer_address)
      <> coalesce(public.profile_bare_address(auth.uid()), '');
$$;

revoke all on function public.peer_relationship_for_viewer(text) from public, anon;

-- ---------------------------------------------------------------------------
-- get_profiles
-- ---------------------------------------------------------------------------

create or replace function public.get_profiles(p_addresses text[])
returns table (
  address text,
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
  with requested as (
    select distinct public.normalize_address(a.addr) as addr
    from unnest(coalesce(p_addresses, array[]::text[])) as a(addr)
    where public.normalize_address(a.addr) <> ''
  )
  select
    r.addr as address,
    p.display_name,
    p.avatar_url,
    p.cover_url,
    p.pronouns,
    coalesce(p.profile_kind, 'user'::public.profile_kind) as profile_kind
  from requested r
  left join public.profiles p on (
    position('@' in r.addr) = 0
    and lower(p.username) = r.addr
  ) or (
    position('@' in r.addr) > 0
    and lower(p.username) = split_part(r.addr, '@', 1)
    and split_part(r.addr, '@', 2) = public.instance_im_server_id()
  );
$$;

grant execute on function public.get_profiles(text[]) to authenticated;
revoke all on function public.get_profiles(text[]) from anon;

create or replace function public.get_peer_context(p_peer_address text)
returns table (
  address text,
  display_name text,
  avatar_url text,
  cover_url text,
  pronouns text,
  profile_kind public.profile_kind,
  peer_in_contacts boolean,
  peer_is_allowed boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    gp.address,
    gp.display_name,
    gp.avatar_url,
    gp.cover_url,
    gp.pronouns,
    gp.profile_kind,
    coalesce(rel.peer_in_contacts, false) as peer_in_contacts,
    coalesce(rel.peer_is_allowed, false) as peer_is_allowed
  from public.get_profiles(array[p_peer_address]) gp
  left join lateral public.peer_relationship_for_viewer(gp.address) rel on true
  where auth.uid() is not null
    and public.normalize_address(p_peer_address) <> ''
    and public.normalize_address(p_peer_address)
      <> coalesce(public.profile_bare_address(auth.uid()), '');
$$;

grant execute on function public.get_peer_context(text) to authenticated;
revoke all on function public.get_peer_context(text) from public, anon;

-- ---------------------------------------------------------------------------
-- find_profile_by_username / search_profiles (address flags)
-- ---------------------------------------------------------------------------

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
  peer_is_allowed boolean
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
    coalesce(rel.peer_is_allowed, false) as peer_is_allowed
  from public.profiles p
  left join lateral public.peer_relationship_for_viewer(p.username) rel on true
  where auth.uid() is not null
    and p.id <> auth.uid()
    and lower(p.username) = lower(trim(p_username))
  limit 1;
$$;

create or replace function public.search_profiles(p_query text, p_limit integer default 20)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  peer_in_contacts boolean,
  peer_is_allowed boolean
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
    coalesce(rel.peer_is_allowed, false) as peer_is_allowed
  from public.profiles p
  left join lateral public.peer_relationship_for_viewer(p.username) rel on true
  where auth.uid() is not null
    and p.id <> auth.uid()
    and (
      p.username ilike '%' || p_query || '%'
      or p.display_name ilike '%' || p_query || '%'
    )
  order by p.display_name
  limit greatest(1, least(p_limit, 50));
$$;

-- ---------------------------------------------------------------------------
-- list_inbox / list_peer_messages / mark_peer_read
-- ---------------------------------------------------------------------------

create or replace function public.list_inbox()
returns table (
  peer_address text,
  display_name text,
  avatar_url text,
  cover_url text,
  pronouns text,
  profile_kind public.profile_kind,
  peer_in_contacts boolean,
  peer_is_allowed boolean,
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
      m.peer_address,
      m.created_at,
      m.content_type,
      m.body,
      m.duration_seconds,
      m.author_id,
      m.author_address,
      m.archive_user_id,
      m.read_at
    from public.messages m
    cross join me
    where me.uid is not null
      and m.archive_user_id = me.uid
      and m.peer_address is not null
      and public.mailbox_has_renderable_content(m.body, m.content_type)
  ),
  latest as (
    select distinct on (d.peer_address)
      d.peer_address,
      d.created_at as last_message_at,
      d.content_type,
      d.body,
      d.duration_seconds
    from direct d
    order by d.peer_address, d.created_at desc
  ),
  unread as (
    select
      d.peer_address,
      count(*)::integer as unread_count
    from direct d
    where public.mailbox_is_incoming(d.archive_user_id, d.author_id, d.author_address)
      and d.read_at is null
    group by d.peer_address
  )
  select
    l.peer_address,
    coalesce(nullif(trim(gp.display_name), ''), l.peer_address) as display_name,
    gp.avatar_url,
    gp.cover_url,
    gp.pronouns,
    coalesce(gp.profile_kind, 'user'::public.profile_kind) as profile_kind,
    coalesce(rel.peer_in_contacts, false) as peer_in_contacts,
    coalesce(rel.peer_is_allowed, false) as peer_is_allowed,
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
  left join lateral (
    select gp.*
    from public.get_profiles(array[l.peer_address]) gp
    limit 1
  ) gp on true
  left join unread u on u.peer_address = l.peer_address
  left join lateral public.peer_relationship_for_viewer(l.peer_address) rel on true
  order by l.last_message_at desc nulls last;
$$;

grant execute on function public.list_inbox() to authenticated;
revoke all on function public.list_inbox() from anon;

create or replace function public.list_peer_messages(
  p_peer_address text,
  p_limit integer default 100,
  p_before_created_at timestamptz default null
)
returns setof public.messages
language sql
stable
security definer
set search_path = public
as $$
  with bounded as (
    select m.*
    from public.messages m
    where auth.uid() is not null
      and public.normalize_address(p_peer_address) <> ''
      and m.archive_user_id = auth.uid()
      and m.peer_address = public.normalize_address(p_peer_address)
      and public.mailbox_has_renderable_content(m.body, m.content_type)
      and (
        p_before_created_at is null
        or m.created_at < p_before_created_at
      )
    order by m.created_at desc
    limit greatest(1, least(coalesce(p_limit, 100), 500))
  )
  select b.*
  from bounded b
  order by b.created_at asc;
$$;

grant execute on function public.list_peer_messages(text, integer, timestamptz) to authenticated;
revoke all on function public.list_peer_messages(text, integer, timestamptz) from anon;

create or replace function public.mark_peer_read(p_peer_address text)
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
  v_peer text := public.normalize_address(p_peer_address);
  v_reader_address text := public.profile_bare_address(v_me);
begin
  if v_me is null then
    raise exception 'not authenticated';
  end if;

  if v_peer = '' then
    raise exception 'peer required';
  end if;

  for v_lambda, v_incoming_id, v_read_receipt_id in
    update public.messages m
    set
      read_at = now(),
      read_receipt_id = gen_random_uuid()
    where m.archive_user_id = v_me
      and m.peer_address = v_peer
      and public.mailbox_is_incoming(m.archive_user_id, m.author_id, m.author_address)
      and m.read_at is null
      and public.mailbox_has_renderable_content(m.body, m.content_type)
    returning m.logical_message_id, m.id, m.read_receipt_id
  loop
    insert into public.outbox (message_id, payload, status)
    values (
      v_incoming_id,
      jsonb_build_object(
        'event_kind', 'read_receipt',
        'logical_message_id', v_lambda,
        'read_receipt_id', v_read_receipt_id,
        'reader_id', v_me,
        'reader_address', v_reader_address,
        'sender_author_address', v_peer
      ),
      'queued'
    )
    returning id into v_outbox_id;

    perform alfred_delivery.process_outbox(v_outbox_id);
  end loop;
end;
$$;

grant execute on function public.mark_peer_read(text) to authenticated;
revoke all on function public.mark_peer_read(text) from anon;

-- ---------------------------------------------------------------------------
-- send_message_to_address + broadcast_message_to_allowlist
-- ---------------------------------------------------------------------------

create or replace function public.send_message_to_address(
  p_peer_address text,
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
  v_peer text := public.normalize_address(p_peer_address);
  v_sender_message_id uuid;
  v_sender_id uuid;
  v_row public.messages;
  v_body text := coalesce(p_body, '');
  v_media_url text := nullif(trim(coalesce(p_media_url, '')), '');
  v_media_mime text := nullif(trim(coalesce(p_media_mime, '')), '');
  v_author_address text;
  v_recipient_id uuid;
  v_recipient_kind public.profile_kind;
  v_sender_kind public.profile_kind;
  v_content_author uuid;
  v_author_id uuid;
  v_outbox_id uuid;
  v_outbox_payload jsonb;
begin
  if v_me is null then
    raise exception 'not authenticated';
  end if;

  perform public.assert_profile_active(v_me);

  if v_peer = '' then
    raise exception 'invalid peer address';
  end if;

  if v_peer in (
    public.profile_bare_address(v_me),
    public.profile_fqdn_address(v_me)
  ) then
    raise exception 'cannot message yourself';
  end if;

  v_recipient_id := public.resolve_local_profile_id(v_peer);
  if v_recipient_id is not null then
    perform public.assert_profile_active(v_recipient_id);
  elsif not public.is_external_address(v_peer) then
    raise exception 'recipient not found';
  end if;

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

  if not public.is_address_allowed_for_reception(v_me, v_peer) then
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

  v_recipient_kind := case
    when v_recipient_id is null then 'user'::public.profile_kind
    else public.profile_kind_of(v_recipient_id)
  end;
  v_sender_kind := public.profile_kind_of(v_me);
  v_author_address := public.sender_author_address(v_me, v_peer);
  v_content_author := case
    when v_recipient_kind = 'group' or v_sender_kind = 'group' then v_me
    else null
  end;
  v_author_id := case
    when v_recipient_kind = 'group' or v_sender_kind = 'group' then v_me
    else null
  end;

  v_sender_message_id := gen_random_uuid();

  insert into public.messages (
    archive_user_id,
    author_id,
    original_author_id,
    peer_address,
    author_address,
    logical_message_id,
    client_message_id,
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
    v_author_id,
    v_content_author,
    v_peer,
    v_author_address,
    v_sender_message_id,
    p_client_message_id,
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
    'logical_message_id', v_sender_message_id,
    'sender_id', v_me,
    'recipient_address', v_peer,
    'recipient_profile_id', v_recipient_id,
    'body', trim(v_body),
    'content_type', p_content_type,
    'media_url', v_media_url,
    'media_mime', v_media_mime,
    'media_size_bytes', p_media_size_bytes,
    'duration_seconds', p_duration_seconds,
    'latitude', p_latitude,
    'longitude', p_longitude
  );

  insert into public.outbox (message_id, payload, status)
  values (v_sender_id, v_outbox_payload, 'queued')
  returning id into v_outbox_id;

  perform alfred_delivery.process_outbox(v_outbox_id);

  select * into v_row from public.messages where id = v_sender_id;
  return v_row;
end;
$$;

grant execute on function public.send_message_to_address(
  text, text, text, public.message_content_type, text, integer, text, bigint, double precision, double precision
) to authenticated;
revoke all on function public.send_message_to_address(
  text, text, text, public.message_content_type, text, integer, text, bigint, double precision, double precision
) from anon;

create or replace function public.broadcast_message_to_allowlist(
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
  v_kind public.profile_kind;
  v_sender_message_id uuid;
  v_row public.messages;
  v_existing_id uuid;
  v_body text := coalesce(p_body, '');
  v_media_url text := nullif(trim(coalesce(p_media_url, '')), '');
  v_media_mime text := nullif(trim(coalesce(p_media_mime, '')), '');
  v_participant_count integer;
  v_outbox_id uuid;
  v_group_address text := public.profile_bare_address(v_me);
begin
  if v_me is null then
    raise exception 'not authenticated';
  end if;

  perform public.assert_profile_active(v_me);

  v_kind := public.profile_kind_of(v_me);
  if v_kind <> 'group' then
    raise exception 'only group accounts can broadcast';
  end if;

  if p_client_message_id is not null then
    select m.id into v_existing_id
    from public.messages m
    where m.archive_user_id = v_me
      and m.client_message_id = p_client_message_id
    limit 1;

    if v_existing_id is not null then
      select * into v_row from public.messages where id = v_existing_id;
      return v_row;
    end if;
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
  elsif p_content_type = 'voice' then
    if v_media_url is null then
      raise exception 'voice requires media_url';
    end if;
  elsif p_content_type = 'location' then
    if p_latitude is null or p_longitude is null then
      raise exception 'location requires latitude and longitude';
    end if;
  else
    raise exception 'unsupported content_type';
  end if;

  select count(*) into v_participant_count
  from public.reception_allowlist r
  where r.archive_user_id = v_me
    and r.allowed_address is not null
    and r.allowed_address <> v_group_address;

  if v_participant_count = 0 then
    raise exception 'no allow list recipients';
  end if;

  v_sender_message_id := gen_random_uuid();

  insert into public.messages (
    archive_user_id,
    author_id,
    original_author_id,
    peer_address,
    author_address,
    logical_message_id,
    client_message_id,
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
    v_me,
    null,
    v_group_address,
    v_sender_message_id,
    p_client_message_id,
    trim(v_body),
    p_content_type,
    v_media_url,
    p_duration_seconds,
    v_media_mime,
    p_media_size_bytes,
    p_latitude,
    p_longitude
  )
  returning * into v_row;

  insert into public.outbox (message_id, payload, status)
  values (
    v_row.id,
    jsonb_build_object(
      'event_kind', 'group_erogate',
      'logical_message_id', v_sender_message_id,
      'sender_id', v_me,
      'broadcast', true,
      'body', trim(v_body),
      'content_type', p_content_type
    ),
    'queued'
  )
  returning id into v_outbox_id;

  perform alfred_delivery.process_outbox(v_outbox_id);

  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- alfred_delivery helpers (address-based)
-- ---------------------------------------------------------------------------

drop function if exists alfred_delivery._insert_recipient_copy(
  uuid, uuid, uuid, uuid, uuid, text, public.message_content_type, jsonb, public.messages
);

drop function if exists alfred_delivery.materialize_inbound_sender_message(
  uuid, uuid, uuid, text, public.message_content_type,
  text, text, integer, text, bigint, double precision, double precision
);

create or replace function alfred_delivery._insert_recipient_copy(
  p_recipient_id uuid,
  p_author_id uuid,
  p_original_author_id uuid,
  p_peer_address text,
  p_author_address text,
  p_lambda uuid,
  p_body text,
  p_content_type public.message_content_type,
  p_payload jsonb,
  p_sender public.messages
)
returns integer
language plpgsql
security definer
set search_path = public, alfred_delivery
as $$
declare
  v_row_count integer;
begin
  if p_lambda is null then
    raise exception 'sender message id required for recipient copy';
  end if;

  if p_sender.logical_message_id is distinct from p_lambda then
    raise exception 'recipient copy must use sender-assigned message id';
  end if;

  insert into public.messages (
    archive_user_id,
    author_id,
    original_author_id,
    peer_address,
    author_address,
    logical_message_id,
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
    p_recipient_id,
    p_author_id,
    p_original_author_id,
    p_peer_address,
    p_author_address,
    p_lambda,
    p_body,
    p_content_type,
    coalesce(p_payload ->> 'media_url', p_sender.media_url),
    coalesce((p_payload ->> 'duration_seconds')::integer, p_sender.duration_seconds),
    coalesce(p_payload ->> 'media_mime', p_sender.media_mime),
    coalesce((p_payload ->> 'media_size_bytes')::bigint, p_sender.media_size_bytes),
    coalesce((p_payload ->> 'latitude')::double precision, p_sender.latitude),
    coalesce((p_payload ->> 'longitude')::double precision, p_sender.longitude)
  )
  on conflict (archive_user_id, logical_message_id) do nothing;

  get diagnostics v_row_count = row_count;
  return v_row_count;
end;
$$;

revoke all on function alfred_delivery._insert_recipient_copy(
  uuid, uuid, uuid, text, text, uuid, text, public.message_content_type, jsonb, public.messages
) from public, anon, authenticated;

create or replace function alfred_delivery.materialize_inbound_sender_message(
  p_recipient_profile_id uuid,
  p_sender_address text,
  p_sender_message_id uuid,
  p_body text,
  p_content_type public.message_content_type default 'text',
  p_external_id text default null,
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
  v_row public.messages;
  v_row_count integer;
  v_sender_address text := public.normalize_address(p_sender_address);
begin
  if p_recipient_profile_id is null or v_sender_address = '' then
    raise exception 'recipient and sender required';
  end if;

  if p_sender_message_id is null then
    raise exception 'sender message id required';
  end if;

  if public.is_profile_disabled(p_recipient_profile_id) then
    raise exception 'profile disabled';
  end if;

  if not public.is_address_allowed_for_reception(p_recipient_profile_id, v_sender_address) then
    raise exception 'reception denied';
  end if;

  insert into public.messages (
    archive_user_id,
    author_id,
    peer_address,
    author_address,
    logical_message_id,
    external_id,
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
    p_recipient_profile_id,
    null,
    v_sender_address,
    v_sender_address,
    p_sender_message_id,
    p_external_id,
    coalesce(p_body, ''),
    p_content_type,
    p_media_url,
    p_duration_seconds,
    p_media_mime,
    p_media_size_bytes,
    p_latitude,
    p_longitude
  )
  on conflict (archive_user_id, logical_message_id) do nothing
  returning * into v_row;

  get diagnostics v_row_count = row_count;

  if v_row_count = 0 then
    select * into v_row
    from public.messages m
    where m.archive_user_id = p_recipient_profile_id
      and m.logical_message_id = p_sender_message_id;
  end if;

  return v_row;
end;
$$;

revoke all on function alfred_delivery.materialize_inbound_sender_message(
  uuid, text, uuid, text, public.message_content_type,
  text, text, integer, text, bigint, double precision, double precision
) from public, anon, authenticated;
grant execute on function alfred_delivery.materialize_inbound_sender_message(
  uuid, text, uuid, text, public.message_content_type,
  text, text, integer, text, bigint, double precision, double precision
) to service_role;

create or replace function alfred_delivery.erogate_group_message(
  p_group_id uuid,
  p_original_author_id uuid,
  p_lambda uuid,
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
  v_participant_address text;
  v_group_address text := public.profile_bare_address(p_group_id);
  v_row_count integer;
begin
  for v_participant_address in
    select r.allowed_address
    from public.reception_allowlist r
    where r.archive_user_id = p_group_id
      and r.allowed_address is not null
      and r.allowed_address <> v_group_address
      and r.allowed_address <> public.profile_bare_address(p_original_author_id)
  loop
    v_participant := public.resolve_local_profile_id(v_participant_address);
    if v_participant is null then
      continue;
    end if;

    if not public.is_address_allowed_for_reception(v_participant, v_group_address) then
      continue;
    end if;

    insert into public.messages (
      archive_user_id,
      author_id,
      original_author_id,
      peer_address,
      author_address,
      logical_message_id,
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
      v_group_address,
      v_group_address,
      p_lambda,
      p_body,
      p_content_type,
      p_media_url,
      p_duration_seconds,
      p_media_mime,
      p_media_size_bytes,
      p_latitude,
      p_longitude
    )
    on conflict (archive_user_id, logical_message_id) do nothing;

    get diagnostics v_row_count = row_count;

    if v_row_count > 0 then
      perform alfred_delivery.queue_push_after_delivery(
        v_participant,
        v_group_address,
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
  uuid, uuid, uuid, text, public.message_content_type,
  text, integer, text, bigint, double precision, double precision
) from public, anon, authenticated;

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
  v_sender_message_id uuid;
  v_content_author uuid;
  v_body text;
  v_content_type public.message_content_type;
  v_is_group boolean;
  v_original_author_id uuid;
  v_row_count integer;
  v_recipient_address text;
  v_recipient_peer_address text;
  v_recipient_author_address text;
  v_recipient_author_id uuid;
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

  v_recipient_address := coalesce(
    v_payload ->> 'recipient_address',
    public.profile_bare_address((v_payload ->> 'recipient_profile_id')::uuid)
  );
  v_recipient_id := coalesce(
    (v_payload ->> 'recipient_profile_id')::uuid,
    public.resolve_local_profile_id(v_recipient_address)
  );

  if v_recipient_id is null and not public.is_external_address(v_recipient_address) then
    perform alfred_delivery._complete_outbox(
      p_outbox_id,
      v_payload || jsonb_build_object('reception_rejected', true, 'reason', 'recipient_not_found')
    );
    return;
  end if;

  if v_recipient_id is not null
     and (
       public.is_profile_disabled(v_sender.archive_user_id)
       or public.is_profile_disabled(v_recipient_id)
     ) then
    perform alfred_delivery._complete_outbox(p_outbox_id);
    return;
  end if;

  v_sender_message_id := v_sender.logical_message_id;
  if v_sender_message_id is null then
    raise exception 'sender message id missing on sender copy';
  end if;

  if (v_payload ? 'logical_message_id')
     and (v_payload ->> 'logical_message_id')::uuid is distinct from v_sender_message_id then
    raise exception 'outbox logical_message_id must match sender copy';
  end if;

  v_body := coalesce(v_payload ->> 'body', v_sender.body);
  v_content_type := coalesce(
    (v_payload ->> 'content_type')::public.message_content_type,
    v_sender.content_type
  );

  if v_recipient_id is null then
    perform alfred_delivery._complete_outbox(p_outbox_id);
    return;
  end if;

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
    v_allowed := public.is_address_allowed_for_reception(v_recipient_id, v_sender.author_address)
      and public.is_address_allowed_for_reception(v_sender.archive_user_id, v_recipient_address);
    v_recipient_peer_address := v_sender.author_address;
    v_recipient_author_address := v_sender.author_address;
    v_recipient_author_id := v_sender.archive_user_id;
  else
    v_allowed := public.is_address_allowed_for_reception(v_recipient_id, v_sender.author_address);
    v_recipient_peer_address := v_sender.author_address;
    v_recipient_author_address := v_sender.author_address;
    v_recipient_author_id := null;
  end if;

  if v_allowed then
    v_row_count := alfred_delivery._insert_recipient_copy(
      v_recipient_id,
      v_recipient_author_id,
      v_original_author_id,
      v_recipient_peer_address,
      v_recipient_author_address,
      v_sender_message_id,
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
        v_sender_message_id,
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
        v_sender.author_address,
        v_sender_message_id,
        v_content_type,
        v_body,
        v_sender.archive_user_id
      );
    elsif v_row_count > 0 then
      perform alfred_delivery.queue_push_after_delivery(
        v_recipient_id,
        v_sender.author_address,
        v_sender_message_id,
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

create or replace function alfred_delivery.propagate_read_receipt(
  p_logical_message_id uuid,
  p_sender_author_address text,
  p_reader_address text,
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
  where sender_copy.logical_message_id = p_logical_message_id
    and sender_copy.author_address = public.normalize_address(p_sender_author_address)
    and sender_copy.peer_address = public.normalize_address(p_reader_address)
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
    v_payload ->> 'sender_author_address',
    v_payload ->> 'reader_address',
    v_read_receipt_id
  );

  perform alfred_delivery._complete_outbox(p_outbox_id);
end;
$$;

revoke all on function alfred_delivery.propagate_read_receipt(uuid, text, text, uuid)
  from public, anon, authenticated;

drop function if exists alfred_delivery.propagate_read_receipt(uuid, uuid, uuid);

create or replace function alfred_delivery.queue_push_after_delivery(
  p_recipient_user_id uuid,
  p_peer_address text,
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
  v_icon_url text;
  v_payload jsonb;
  v_outbox_id uuid;
  v_peer_address text := public.normalize_address(p_peer_address);
begin
  if p_recipient_user_id is null or v_peer_address = '' or p_logical_message_id is null then
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
  where m.archive_user_id = p_recipient_user_id
    and m.logical_message_id = p_logical_message_id
  limit 1;

  if v_recipient_message_id is null then
    return;
  end if;

  select gp.display_name
  into v_peer_name
  from public.get_profiles(array[v_peer_address]) gp
  limit 1;

  select p.display_name, p.username
  into v_recipient_name, v_recipient_username
  from public.profiles p
  where p.id = p_recipient_user_id;

  v_preview := public.message_preview_text(p_content_type, p_body);

  if p_original_author_id is not null then
    select p.display_name into v_author_name
    from public.profiles p
    where p.id = p_original_author_id;

    if v_author_name is not null and length(trim(v_author_name)) > 0 then
      v_preview := v_author_name || ': ' || v_preview;
    end if;
  end if;

  select nullif(trim(c.value ->> 'logo_url'), '')
  into v_icon_url
  from public.instance_config c
  where c.key = 'instance.branding';

  v_payload := jsonb_build_object(
    'event_kind', 'push_notify',
    'recipient_user_id', p_recipient_user_id,
    'recipient_display_name', coalesce(v_recipient_name, 'Alfred'),
    'recipient_username', v_recipient_username,
    'peer_address', v_peer_address,
    'peer_display_name', coalesce(v_peer_name, v_peer_address),
    'preview_text', v_preview,
    'logical_message_id', p_logical_message_id,
    'content_type', p_content_type::text,
    'icon_url', v_icon_url
  );

  insert into public.outbox (message_id, payload, status)
  values (v_recipient_message_id, v_payload, 'queued')
  returning id into v_outbox_id;

  perform alfred_delivery.process_push_notify(v_outbox_id);
end;
$$;

revoke all on function alfred_delivery.queue_push_after_delivery(
  uuid, text, uuid, public.message_content_type, text, uuid
) from public, anon, authenticated;

drop function if exists alfred_delivery.queue_push_after_delivery(
  uuid, uuid, uuid, public.message_content_type, text, uuid
);

comment on column public.messages.peer_address is
  'Chiave conversazione lowercase (username o user@server); null solo broadcast archivio gruppo.';

comment on column public.messages.author_address is
  'Identità mittente come indirizzo — forma che fa fede nella comunicazione.';

comment on column public.reception_allowlist.allowed_address is
  'Mittente consentito (lowercase) — username o user@server.';

comment on column public.contacts.address is
  'Indirizzo contatto lowercase — username o user@server.';
