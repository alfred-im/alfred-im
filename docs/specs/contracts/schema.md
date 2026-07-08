# Contratto schema — dominio Alpha (mailbox)

**Ultima revisione**: 2026-07-06  
**Status**: `implemented` su `main` (migrazioni fino a `20260706140000`, incl. SYS-GROUP)  
**Fonte di verità**: `supabase/migrations/`

Contratto **tabelle ed enum** usati dalle promesse SYSTEM. Per RPC: [rpc.md](./rpc.md). Per indice promesse: [index.md](../index.md).

---

## Diagramma relazioni (su `main`)

```
auth.users 1──1 profiles
profiles 1──* contacts (owner_id)
profiles 1──* reception_allowlist (owner_id → allowed_profile_id)
profiles 1──* messages (owner_id = archivio; author_id = autore contenuto)
messages *── peer profiles (peer_profile_id denormalizzato)
messages 0..1 outbox (sempre, anche internal)
profiles 1──* sync_cursors (peer_profile_id)
bridge_jobs (coda bridge)
storage: chat-media, avatars
```

**Inbox**: nessuna tabella dedicata — derivata dal mio archivio `messages` via `list_inbox()`.

---

## Enum

| Tipo | Valori | Uso |
|------|--------|-----|
| `contact_protocol` | `internal`, `xmpp`, `matrix` | Routing backend; invisibile in UI inbox |
| `message_content_type` | `text`, `gif`, `voice`, `location` | Tipo contenuto messaggio |
| `message_delivery_status` | `pending`, `sent`, `delivered`, `read`, `failed` | Stati `outbox` / `bridge_jobs` (non più su `messages`) |
| `queue_status` | `queued`, … `failed` | `outbox`, `bridge_jobs` |
| `profile_kind` | `user`, `group` | Tipo account — [SYS-GROUP](../promises/system/SYS-GROUP.md) |

---

## `profiles`

| Colonna | Tipo | Note |
|---------|------|------|
| `id` | uuid PK | = `auth.users.id` |
| `profile_kind` | profile_kind | default `user` |
| `username` | text | `^[a-z0-9_]{3,32}$`, unique lower (namespace condiviso user+group) |
| `display_name` | text | Obbligatorio |
| `bio` | text | Opzionale |
| `avatar_url` | text | URL bucket `avatars` |
| `pronouns` | text | Opzionale (#134) |
| `created_at`, `updated_at` | timestamptz | |

**RLS**: SELECT authenticated; UPDATE solo `id = auth.uid()`.

**Spec**: [SYS-PROFILE](../promises/system/SYS-PROFILE.md).

---

## `contacts`

| Colonna | Tipo | Note |
|---------|------|------|
| `id` | uuid PK | |
| `owner_id` | uuid FK → profiles | |
| `protocol` | contact_protocol | |
| `linked_profile_id` | uuid FK nullable | Obbligatorio se `internal` |
| `external_address` | text nullable | Obbligatorio se xmpp/matrix |
| `display_name` | text | |
| `avatar_url` | text nullable | Snapshot opzionale |

**CHECK**: internal ↔ profile; federato ↔ external_address.

**RLS**: CRUD `owner_id = auth.uid()`.

**Spec**: [SYS-CONTACTS](../promises/system/SYS-CONTACTS.md).

---

## `reception_allowlist`

| Colonna | Tipo | Note |
|---------|------|------|
| `id` | uuid PK | |
| `owner_id` | uuid FK → profiles | Destinatario che filtra |
| `allowed_profile_id` | uuid FK → profiles | Mittente consentito |
| `created_at` | timestamptz | default `now()` |

**UNIQUE**: `(owner_id, allowed_profile_id)`.

**CHECK**: `allowed_profile_id IS NOT NULL` AND `allowed_profile_id <> owner_id`.

**RLS**: CRUD `owner_id = auth.uid()`.

**Spec**: [SYS-RECEPTION](../promises/system/SYS-RECEPTION.md).

---

## `messages`

| Colonna | Tipo | Note |
|---------|------|------|
| `id` | uuid PK | Per owner |
| `owner_id` | uuid FK → profiles | Archivio (`auth.uid()` in RLS) |
| `author_id` | uuid FK → profiles | Mittente tecnico di recapito (gruppo se erogazione) |
| `original_author_id` | uuid FK nullable → profiles | Autore contenuto se `author_id` è gruppo — [SYS-GROUP](../promises/system/SYS-GROUP.md) |
| `peer_profile_id` | uuid FK nullable | Controparte internal |
| `peer_external_address` | text nullable | Federato futuro |
| `logical_message_id` | uuid NOT NULL | λ — correlazione copie |
| `client_message_id` | text nullable | Solo copia mittente |
| `protocol` | contact_protocol | Routing recapito |
| `body` | text | |
| `content_type` | message_content_type | |
| `media_url` | text nullable | Condiviso tra copie |
| `duration_seconds`, `media_mime`, `media_size_bytes` | | voice |
| `latitude`, `longitude` | double nullable | location |
| `delivered_at` | timestamptz nullable | Solo righe uscita (author = owner) |
| `read_at` | timestamptz nullable | Uscita: spunta lettura; entrata: lettura locale |
| `failed_at` | timestamptz nullable | Invio/outbox fallito (mittente) |
| `external_id` | text nullable | Bridge fase B |
| `created_at` | timestamptz | |

**UNIQUE**: `(owner_id, client_message_id)` WHERE `client_message_id IS NOT NULL`; `(owner_id, logical_message_id)`.

**RLS**: `owner_id = auth.uid()` per SELECT/INSERT/UPDATE.

**Spec**: [SYS-MAILBOX](../promises/system/SYS-MAILBOX.md), [SYS-GROUP](../promises/system/SYS-GROUP.md).

---

## Partecipazione gruppo (SYS-GROUP)

Nessuna tabella aggiuntiva. Partecipazione = allow list bidirezionale:

- `reception_allowlist(owner_id = gruppo, allowed_profile_id = persona)`
- `reception_allowlist(owner_id = persona, allowed_profile_id = gruppo)`

---

## `outbox`

Coda invio — popolata per **ogni** invio (internal + federato). FK `message_id` → copia **mittente**.

Consumer internal: transazione RPC; federato: fase B bridge (stub).

**RLS**: DENY per `authenticated`.

**Spec**: [SYS-MAILBOX](../promises/system/SYS-MAILBOX.md).

---

## `sync_cursors`, `bridge_jobs`

Stato piattaforma bridge ([bridge-stateless.md](../../decisions/bridge-stateless.md)). `sync_cursors.peer_profile_id` sostituisce `inbox_thread_id` storico.

**RLS**: DENY per `authenticated`.

---

## Storage buckets

| Bucket | Uso | Limite | Path pattern |
|--------|-----|--------|--------------|
| `chat-media` | GIF, voice | 10 MB gif / 15 MB webm | `{auth.uid()}/{uuid}.*` |
| `avatars` | Foto profilo | 2 MB | `{auth.uid()}/avatar.{ext}` |

Pubblici in Alpha (URL diretti in Realtime).

---

## Oggetti rimossi (non devono esistere)

| Oggetto | Rimosso in |
|---------|------------|
| `inbox_threads` | `20260627230000_messages_only_inbox.sql` |
| `conversations`, `conversation_participants` | message-centric refactor |
| `message_read_receipts` | `20260704120000_mailbox_per_owner_archive.sql` |
| `messages.delivery_status`, `sender_id`, `recipient_profile_id`, `marker_type`, `marker_for` | `20260704120000` (tabella ricreata) |
| Trigger `on_message_inserted` | `20260704120000` |

Verifica: `supabase/tests/schema_smoke.sql`, `mailbox_schema_smoke.sql`.

---

## Migrazioni

Elenco completo: [alpha-pr-registry.md](../../architecture/alpha-pr-registry.md) § migrazioni.
