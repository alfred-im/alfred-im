-- Inbox e risoluzione username: espone avatar e pronomi del peer da profiles

drop function if exists public.list_inbox();

create or replace function public.list_inbox()
returns table (
  protocol public.contact_protocol,
  display_name text,
  peer_profile_id uuid,
  peer_external_address text,
  peer_avatar_url text,
  peer_pronouns text,
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
      case
        when m.sender_id = me.uid then m.recipient_profile_id
        else m.sender_id
      end as peer_profile_id,
      m.recipient_external_address as peer_external_address,
      m.created_at,
      m.sender_id,
      m.recipient_profile_id,
      m.content_type,
      m.body,
      m.duration_seconds,
      m.delivery_status
    from public.messages m
    cross join me
    where me.uid is not null
      and m.protocol = 'internal'
      and m.recipient_profile_id is not null
      and (m.sender_id = me.uid or m.recipient_profile_id = me.uid)
      and m.marker_type is null
      and (
        trim(m.body) <> ''
        or m.content_type in ('gif', 'voice')
      )
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
    cross join me
    where d.recipient_profile_id = me.uid
      and d.delivery_status not in ('read')
    group by d.peer_profile_id
  )
  select
    l.protocol,
    coalesce(nullif(trim(p.display_name), ''), 'Contatto') as display_name,
    l.peer_profile_id,
    l.peer_external_address,
    p.avatar_url as peer_avatar_url,
    p.pronouns as peer_pronouns,
    case
      when l.content_type = 'gif' then '[GIF]'
      when l.content_type = 'voice' then public.format_voice_preview(coalesce(l.duration_seconds, 0))
      else left(trim(l.body), 120)
    end as last_message_preview,
    l.last_message_at,
    coalesce(u.unread_count, 0) as unread_count
  from latest l
  left join public.profiles p on p.id = l.peer_profile_id
  left join unread u on u.peer_profile_id = l.peer_profile_id
  order by l.last_message_at desc nulls last;
$$;

drop function if exists public.find_profile_by_username(text);

create or replace function public.find_profile_by_username(p_username text)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  pronouns text
)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.username, p.display_name, p.avatar_url, p.pronouns
  from public.profiles p
  where auth.uid() is not null
    and p.id <> auth.uid()
    and lower(p.username) = lower(trim(p_username))
  limit 1;
$$;

grant execute on function public.list_inbox() to authenticated;
revoke all on function public.list_inbox() from anon;

grant execute on function public.find_profile_by_username(text) to authenticated;
revoke all on function public.find_profile_by_username(text) from public, anon;
