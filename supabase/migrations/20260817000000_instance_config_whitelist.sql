-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Instance config: only the four keys defined by InstanceSettings (client SSOT).

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
    and c.key in (
      'instance.display_name',
      'instance.im_server_id',
      'instance.branding',
      'instance.legal'
    )
  order by c.key;
$$;

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

  if p_key not in (
    'instance.display_name',
    'instance.im_server_id',
    'instance.branding',
    'instance.legal'
  ) then
    raise exception 'unknown instance config key';
  end if;

  if p_value is null then
    raise exception 'value required';
  end if;

  if p_key in ('instance.display_name', 'instance.im_server_id') then
    if jsonb_typeof(p_value) <> 'string' then
      raise exception 'value must be a JSON string';
    end if;
    if length(trim(p_value #>> '{}')) = 0 then
      raise exception 'value must not be empty';
    end if;
  elsif p_key = 'instance.branding' then
    if jsonb_typeof(p_value) <> 'object' then
      raise exception 'instance.branding must be a JSON object';
    end if;
  elsif p_key = 'instance.legal' then
    if jsonb_typeof(p_value) <> 'object' then
      raise exception 'instance.legal must be a JSON object';
    end if;
  end if;

  insert into public.instance_config (key, value, updated_at)
  values (p_key, p_value, now())
  on conflict (key) do update
    set value = excluded.value,
        updated_at = now();
end;
$$;
