-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- SYS-CONTACTS: PostgREST su contacts (RLS già definita in 20260624200000).

grant select, insert, update, delete on public.contacts to authenticated;
