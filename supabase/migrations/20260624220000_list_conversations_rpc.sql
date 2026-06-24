-- Inbox: un solo round-trip client ↔ piattaforma (niente N+1 REST).

create or replace function public.list_conversations()
returns table (
  conversation_id uuid,
  protocol public.contact_protocol,
  display_name text,
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
  )
  select
    c.id as conversation_id,
    c.protocol,
    coalesce(
      nullif(trim(c.title), ''),
      peer.display_name,
      'Conversazione'
    ) as display_name,
    coalesce(c.last_message_preview, '') as last_message_preview,
    c.last_message_at,
    cp.unread_count
  from me
  cross join public.conversation_participants cp
  inner join public.conversations c on c.id = cp.conversation_id
  left join lateral (
    select coalesce(p.display_name, ct.display_name, 'Contatto') as display_name
    from public.conversation_participants op
    left join public.profiles p on p.id = op.profile_id
    left join public.contacts ct on ct.id = op.contact_id
    where op.conversation_id = c.id
      and op.profile_id <> me.uid
    limit 1
  ) peer on true
  where cp.profile_id = me.uid
    and me.uid is not null
  order by c.last_message_at desc nulls last;
$$;

grant execute on function public.list_conversations() to authenticated;
revoke all on function public.list_conversations() from anon;
