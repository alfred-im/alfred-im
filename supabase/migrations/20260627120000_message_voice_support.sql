-- Voice notes (part 1/2): enum value must commit before use in constraints/RPC.

alter type public.message_content_type add value if not exists 'voice';
