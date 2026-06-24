-- Alfred platform: bootstrap migration (Alpha)
-- Apply after linking this repo to your Supabase project (dashboard or supabase link).

create extension if not exists "pgcrypto" with schema extensions;
