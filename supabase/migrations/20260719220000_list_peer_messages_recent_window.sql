-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- SYS-MAILBOX-036: list_peer_messages returns the most recent window (not oldest).
-- Optional p_before_created_at cursor loads older pages.

drop function if exists public.list_peer_messages(uuid, integer);

create or replace function public.list_peer_messages(
  p_peer_profile_id uuid,
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
      and p_peer_profile_id is not null
      and m.owner_id = auth.uid()
      and m.peer_profile_id = p_peer_profile_id
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

grant execute on function public.list_peer_messages(uuid, integer, timestamptz) to authenticated;
revoke all on function public.list_peer_messages(uuid, integer, timestamptz) from anon;
