-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Fix flaky "latest fact" when apply/change/withdraw happen in one transaction:
-- transaction-scoped now() ties occurred_at; tie-break on random UUID then picks
-- the wrong fact. clock_timestamp() gives monotonic per-statement timestamps.

alter table public.message_reaction_facts
  alter column occurred_at set default clock_timestamp();

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
    emoji,
    occurred_at
  )
  values (
    p_logical_message_id,
    v_me,
    'applied',
    v_emoji,
    clock_timestamp()
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
    emoji,
    occurred_at
  )
  values (
    p_logical_message_id,
    v_me,
    'withdrawn',
    null,
    clock_timestamp()
  )
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.apply_message_reaction(uuid, text) to authenticated;
revoke all on function public.apply_message_reaction(uuid, text) from anon;

grant execute on function public.withdraw_message_reaction(uuid) to authenticated;
revoke all on function public.withdraw_message_reaction(uuid) from anon;
