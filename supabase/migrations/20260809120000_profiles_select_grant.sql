-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- reception_allowlist embeds profiles via PostgREST; RLS policy alone is not enough
-- without table-level SELECT for authenticated (allowlist load → composer disabled).
GRANT SELECT ON public.profiles TO authenticated;
