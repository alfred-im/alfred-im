-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Enum values must be committed before use in functions (separate migration).

alter type public.message_content_type add value if not exists 'image';
alter type public.message_content_type add value if not exists 'video';
