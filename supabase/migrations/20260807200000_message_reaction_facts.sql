-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Message reactions — append-only facts anchored on logical_message_id (λ).

-- ---------------------------------------------------------------------------
-- Enum
-- ---------------------------------------------------------------------------

create type public.message_reaction_kind as enum ('applied', 'withdrawn');

-- ---------------------------------------------------------------------------
-- Table
-- ---------------------------------------------------------------------------

create table public.message_reaction_facts (
  id uuid primary key default gen_random_uuid(),
  logical_message_id uuid not null,
  reactor_id uuid not null references public.profiles (id) on delete cascade,
  kind public.message_reaction_kind not null,
  emoji text,
  occurred_at timestamptz not null default now(),
  constraint message_reaction_facts_emoji_applied check (
    (
      kind = 'applied'
      and emoji is not null
      and length(trim(emoji)) > 0
    )
    or (
      kind = 'withdrawn'
      and emoji is null
    )
  ),
  constraint message_reaction_facts_emoji_length check (
    emoji is null
    or char_length(emoji) <= 32
  )
);

create index message_reaction_facts_logical_occurred_idx
  on public.message_reaction_facts (logical_message_id, occurred_at);

create index message_reaction_facts_logical_reactor_occurred_idx
  on public.message_reaction_facts (
    logical_message_id,
    reactor_id,
    occurred_at desc,
    id desc
  );

-- ---------------------------------------------------------------------------
-- RLS — SELECT partecipanti; INSERT solo via RPC SECURITY DEFINER
-- ---------------------------------------------------------------------------

alter table public.message_reaction_facts enable row level security;

create policy message_reaction_facts_select_participant
  on public.message_reaction_facts
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.messages m
      where m.logical_message_id = message_reaction_facts.logical_message_id
        and m.owner_id = auth.uid()
    )
  );

do $do$
begin
  alter publication supabase_realtime add table public.message_reaction_facts;
exception
  when duplicate_object then null;
  when others then null;
end $do$;

-- ---------------------------------------------------------------------------
-- Helpers (internal)
-- ---------------------------------------------------------------------------

create or replace function public.mailbox_is_message_participant(
  p_logical_message_id uuid,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.messages m
    where m.logical_message_id = p_logical_message_id
      and m.owner_id = p_user_id
  );
$$;

create or replace function public.message_reaction_latest_fact(
  p_logical_message_id uuid,
  p_reactor_id uuid
)
returns public.message_reaction_facts
language sql
stable
security definer
set search_path = public
as $$
  select f.*
  from public.message_reaction_facts f
  where f.logical_message_id = p_logical_message_id
    and f.reactor_id = p_reactor_id
  order by f.occurred_at desc, f.id desc
  limit 1;
$$;

revoke all on function public.mailbox_is_message_participant(uuid, uuid)
  from public, anon, authenticated;

revoke all on function public.message_reaction_latest_fact(uuid, uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- RPC: apply / withdraw
-- ---------------------------------------------------------------------------

create or replace function public.apply_message_reaction(
  p_logical_message_id uuid,
  p_emoji text
)
returns public.message_reaction_facts
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_emoji text := nullif(trim(coalesce(p_emoji, '')), '');
  v_latest public.message_reaction_facts;
  v_row public.message_reaction_facts;
begin
  if v_me is null then
    raise exception 'not authenticated';
  end if;

  if p_logical_message_id is null then
    raise exception 'logical_message_id required';
  end if;

  if v_emoji is null then
    raise exception 'emoji required';
  end if;

  if char_length(v_emoji) > 32 then
    raise exception 'emoji too long';
  end if;

  if not public.mailbox_is_message_participant(p_logical_message_id, v_me) then
    raise exception 'not a message participant';
  end if;

  v_latest := public.message_reaction_latest_fact(p_logical_message_id, v_me);

  if v_latest.id is not null
    and v_latest.kind = 'applied'
    and v_latest.emoji = v_emoji then
    return v_latest;
  end if;

  insert into public.message_reaction_facts (
    logical_message_id,
    reactor_id,
    kind,
    emoji
  )
  values (
    p_logical_message_id,
    v_me,
    'applied',
    v_emoji
  )
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.withdraw_message_reaction(
  p_logical_message_id uuid
)
returns public.message_reaction_facts
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_latest public.message_reaction_facts;
  v_row public.message_reaction_facts;
begin
  if v_me is null then
    raise exception 'not authenticated';
  end if;

  if p_logical_message_id is null then
    raise exception 'logical_message_id required';
  end if;

  if not public.mailbox_is_message_participant(p_logical_message_id, v_me) then
    raise exception 'not a message participant';
  end if;

  v_latest := public.message_reaction_latest_fact(p_logical_message_id, v_me);

  if v_latest.id is null or v_latest.kind = 'withdrawn' then
    return null;
  end if;

  insert into public.message_reaction_facts (
    logical_message_id,
    reactor_id,
    kind,
    emoji
  )
  values (
    p_logical_message_id,
    v_me,
    'withdrawn',
    null
  )
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.apply_message_reaction(uuid, text) to authenticated;
revoke all on function public.apply_message_reaction(uuid, text) from anon;

grant execute on function public.withdraw_message_reaction(uuid) to authenticated;
revoke all on function public.withdraw_message_reaction(uuid) from anon;

-- ---------------------------------------------------------------------------
-- RPC: list summaries (stato corrente derivato)
-- ---------------------------------------------------------------------------

create or replace function public.list_message_reactions(
  p_logical_message_ids uuid[]
)
returns table (
  logical_message_id uuid,
  emoji text,
  reaction_count bigint,
  reactor_ids uuid[],
  includes_me boolean
)
language sql
stable
security definer
set search_path = public
as $$
  with scoped as (
    select distinct m.logical_message_id
    from public.messages m
    where m.owner_id = auth.uid()
      and m.logical_message_id = any (p_logical_message_ids)
  ),
  latest as (
    select distinct on (f.logical_message_id, f.reactor_id)
      f.logical_message_id,
      f.reactor_id,
      f.kind,
      f.emoji
    from public.message_reaction_facts f
    inner join scoped s on s.logical_message_id = f.logical_message_id
    order by f.logical_message_id, f.reactor_id, f.occurred_at desc, f.id desc
  ),
  active as (
    select
      l.logical_message_id,
      l.reactor_id,
      l.emoji
    from latest l
    where l.kind = 'applied'
  )
  select
    a.logical_message_id,
    a.emoji,
    count(*)::bigint as reaction_count,
    array_agg(a.reactor_id order by a.reactor_id) as reactor_ids,
    bool_or(a.reactor_id = auth.uid()) as includes_me
  from active a
  group by a.logical_message_id, a.emoji
  order by a.logical_message_id, a.emoji;
$$;

grant execute on function public.list_message_reactions(uuid[]) to authenticated;
revoke all on function public.list_message_reactions(uuid[]) from anon;
