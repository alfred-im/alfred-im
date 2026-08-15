-- Istanza demo GitHub Pages (tvwpoxxcqwphryvuyqzu).
-- Eseguire su Supabase live dopo migration instance_config.
-- Idempotente: upsert su chiave.

insert into public.instance_config (key, value) values
  ('instance.display_name', '"Alfred.im Demo"'::jsonb),
  ('instance.im_server_id', '"alfred.im"'::jsonb)
on conflict (key) do update
  set value = excluded.value,
      updated_at = now();
