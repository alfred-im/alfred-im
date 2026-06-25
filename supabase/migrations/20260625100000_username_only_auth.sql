-- Alfred: identità account solo username (nessuna email utente)
-- GoTrue richiede un campo email: usiamo {username}@users.alfred.internal (mai mostrato in UI).

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_username text;
  v_display_name text;
begin
  v_username := lower(new.raw_user_meta_data ->> 'username');

  if v_username is null or v_username = '' then
    if new.email like '%@users.alfred.internal' then
      v_username := lower(split_part(new.email, '@', 1));
    end if;
  end if;

  v_username := regexp_replace(coalesce(v_username, ''), '[^a-z0-9_]', '_', 'g');

  if length(v_username) < 3 then
    v_username := 'user_' || substr(replace(new.id::text, '-', ''), 1, 8);
  end if;

  v_display_name := coalesce(
    new.raw_user_meta_data ->> 'display_name',
    initcap(replace(v_username, '_', ' '))
  );

  insert into public.profiles (id, username, display_name)
  values (new.id, v_username, v_display_name)
  on conflict (id) do nothing;

  return new;
end;
$$;
