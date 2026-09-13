-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- RLS policies run as invoker; profile_bare_address is internal-only.
-- Expose auth-scoped bare address for INSERT checks on reception_allowlist.

create or replace function public.auth_bare_address()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select public.profile_bare_address(auth.uid());
$$;

revoke all on function public.auth_bare_address() from public, anon;
grant execute on function public.auth_bare_address() to authenticated;

drop policy if exists reception_allowlist_insert_own on public.reception_allowlist;

create policy reception_allowlist_insert_own
  on public.reception_allowlist for insert to authenticated
  with check (
    archive_user_id = auth.uid()
    and allowed_address <> coalesce(public.auth_bare_address(), '')
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
