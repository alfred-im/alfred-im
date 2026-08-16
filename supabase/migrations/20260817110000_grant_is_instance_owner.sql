-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Client can verify owner capability server-side (gate UI panels).
grant execute on function public.is_instance_owner() to authenticated;
