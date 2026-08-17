-- Owner accounts smoke (run after 20260816100000_owner_accounts.sql)

select 1
where exists (
  select 1
  from pg_enum e
  join pg_type t on t.oid = e.enumtypid
  where t.typname = 'profile_kind'
    and e.enumlabel = 'owner'
);

select 1
where exists (
  select 1
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'profiles'
    and column_name = 'disabled_at'
);

select 1
where has_function_privilege('authenticated', 'public.assert_session_active()', 'EXECUTE');

select 1
where has_function_privilege('authenticated', 'public.ban_profile(uuid)', 'EXECUTE');

select 1
where has_function_privilege('authenticated', 'public.get_instance_stats()', 'EXECUTE');
