# Contratto schema — dominio mailbox (mailbox)

**Ultima revisione**: 2026-09-13  
**Status**: `approved` — amend §7 peer_address (migrazione dev pendente; codice attuale ancora su `peer_profile_id`)  
**Fonte di verità target**: migrazione post-approvazione in `supabase/migrations/`

Contratto **tabelle ed enum** usati dalle promesse SYSTEM. Per RPC: [rpc.md](./rpc.md). Per indice promesse: [registry.md](../registry.md).

**Riferimento modello**: [TEMP-chat-peer-key-address-drift.md](../../tmp/TEMP-chat-peer-key-address-drift.md) §7 (da eliminare post-implementazione).

---

## Diagramma relazioni (target post-migrazione)

```
auth.users 1──1 profiles
profiles 1──* contacts (archive_user_id → address)
profiles 1──* reception_allowlist (archive_user_id → allowed_address)
profiles 1──* messages (archive_user_id = archivio; author_id nullable — casi tecnici gruppo)
messages — chiave conversazione: peer_address (text, lowercase)
logical_message_id (λ) 1──* message_reaction_facts (append-only; nessuna FK — λ non univoco su messages)
messages 1──* outbox (ogni invio/lettura può accodare eventi)
profiles 1──* push_subscriptions (user_id, device_id)
storage: chat-media, avatars, instance-branding
```

**Inbox**: nessuna tabella dedicata — derivata dal mio archivio `messages` via `list_inbox()`, raggruppata per `peer_address`.

**Identità chat**: `(archive_user_id, peer_address)` — **non** `peer_profile_id`, **non** `peer_external_address`, **non** profilo shadow per peer remoti.

---

## Enum

| Tipo | Valori | Uso |
|------|--------|-----|
| `message_content_type` | `text`, `gif`, `voice`, `location`, `image`, `video` | Tipo contenuto messaggio |
| `queue_status` | `queued`, `processing`, `completed`, `failed` | `outbox` |
| `profile_kind` | `user`, `group`, `owner` | Tipo account — [SYS-GROUP](../promises/system/SYS-GROUP.md), [SYS-OWNER](../promises/system/SYS-OWNER.md) |
| `message_reaction_kind` | `applied`, `withdrawn` | Fatto reaction su λ — [messaging](../../domain/messaging/commands-and-events.md) |

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
| `cover_url` | text | URL copertina bucket `avatars` |
| `pronouns` | text | Opzionale (#134) |
| `disabled_at` | timestamptz | Ban account — [SYS-OWNER](../promises/system/SYS-OWNER.md) |
| `created_at`, `updated_at` | timestamptz | |

**RLS**: SELECT authenticated; UPDATE solo `id = auth.uid()`.

**Spec**: [SYS-PROFILE](../promises/system/SYS-PROFILE.md).

**MUST NOT**: INSERT profili shadow per peer su altre istanze — presentazione via `get_profiles(addresses[])` ([SYS-PROFILE](../promises/system/SYS-PROFILE.md) SYS-PROFILE-009).

---

## `contacts`

| Colonna | Tipo | Note |
|---------|------|------|
| `id` | uuid PK | |
| `archive_user_id` | uuid FK → profiles | Titolare rubrica |
| `address` | text NOT NULL | Indirizzo contatto lowercase — `username` o `user@server` |

**UNIQUE**: `(archive_user_id, address)`.

**RLS**: SELECT, INSERT, UPDATE, DELETE `archive_user_id = auth.uid()`.

**Rimossi** (deriva implementativa): `linked_profile_id`, `external_address`, `display_name`, `avatar_url` — rubrica = solo indirizzo; presentazione via `get_profiles`.

**Spec**: [SYS-CONTACTS](../promises/system/SYS-CONTACTS.md).

---

## `reception_allowlist`

| Colonna | Tipo | Note |
|---------|------|------|
| `id` | uuid PK | |
| `archive_user_id` | uuid FK → profiles | Destinatario che filtra |
| `allowed_address` | text NOT NULL | Mittente consentito (lowercase) — `username` o `user@server` |
| `created_at` | timestamptz | default `now()` |

**UNIQUE**: `(archive_user_id, allowed_address)`.

**CHECK**: `allowed_address IS NOT NULL` AND `lower(allowed_address) <> lower(profiles.username)` del titolare archivio (non consentire sé stessi).

**RLS**: SELECT, INSERT, DELETE `archive_user_id = auth.uid()` (nessuna policy UPDATE).

**Regole indirizzo** (§7.2, §7.6): `mario` e `mario@<im_server_id>` sono **voci distinte** — identità, chat e allow list non si fondono.

**Spec**: [SYS-RECEPTION](../promises/system/SYS-RECEPTION.md).

---

## `messages`

| Colonna | Tipo | Note |
|---------|------|------|
| `id` | uuid PK | Per archive_user |
| `archive_user_id` | uuid FK → profiles | Archivio (`auth.uid()` in RLS) |
| `peer_address` | text NOT NULL | **Chiave conversazione** — controparte lowercase (`username` o `user@server`) |
| `author_address` | text NOT NULL | Identità mittente come indirizzo — forma che fa fede nella comunicazione (§7.4, §7.5, §7.5b) |
| `author_id` | uuid FK nullable → profiles | Solo casi tecnici (es. erogazione [SYS-GROUP](../promises/system/SYS-GROUP.md)) |
| `original_author_id` | uuid FK nullable → profiles | Autore contenuto se `author_id` è gruppo — [SYS-GROUP](../promises/system/SYS-GROUP.md) |
| `logical_message_id` | uuid NOT NULL | Identificativo globale messaggio — assegnato dal server mittente, replicato identico sul destinatario |
| `client_message_id` | text nullable | Solo copia mittente |
| `body` | text | |
| `content_type` | message_content_type | |
| `media_url` | text nullable | Condiviso tra copie |
| `duration_seconds`, `media_mime`, `media_size_bytes` | | voice |
| `latitude`, `longitude` | double nullable | location |
| `delivered_at` | timestamptz nullable | Solo righe uscita (author = archive_user) |
| `read_at` | timestamptz nullable | Uscita: spunta lettura; entrata: lettura locale |
| `read_receipt_id` | uuid nullable | Id federativo evento lettura — mint sulla copia lettore, replicato sul mittente |
| `failed_at` | timestamptz nullable | Invio/outbox fallito (mittente) |
| `external_id` | text nullable | Opzionale — correlazione esterna; il wire usa `logical_message_id` |
| `created_at` | timestamptz | |

**Rimossi come identità chat** (deriva): `peer_profile_id`, `peer_external_address`.

**UNIQUE**: `(archive_user_id, client_message_id)` WHERE `client_message_id IS NOT NULL`; `(archive_user_id, logical_message_id)`.

**Indici target**: `(archive_user_id, peer_address, created_at DESC)`, `(archive_user_id, logical_message_id)`.

**RLS**: SELECT `archive_user_id = auth.uid()` — **nessuna** policy INSERT/UPDATE/DELETE (mutazioni solo via RPC `SECURITY DEFINER`).

**Entrata/uscita**: righe in entrata quando `author_address <> peer_address` del titolare **oppure** confronto con indirizzo canonico dell'archivio (non solo `author_id` UUID).

**Spec**: [SYS-MAILBOX](../promises/system/SYS-MAILBOX.md), [SYS-GROUP](../promises/system/SYS-GROUP.md).

### Semantica `author_address` (§7.4–§7.5b)

| Caso | Regola |
|------|--------|
| Stessa istanza, compose bare | Mittente bare → destinatario vede mittente bare |
| Stessa istanza, compose FQDN | Mittente FQDN → destinatario vede mittente FQDN |
| Inbound federato | `author_address` = `from_address` envelope (sempre FQDN) |
| Copia mittente verso esterno | `author_address` = forma FQDN del mittente (§7.5b) |

---

## `message_reaction_facts`

Fatti immutabili (append-only) sulle reaction — ancorati a `logical_message_id` (λ), non a `messages.id`.

| Colonna | Tipo | Note |
|---------|------|------|
| `id` | uuid PK | Identità del fatto |
| `logical_message_id` | uuid NOT NULL | λ del messaggio target |
| `reactor_id` | uuid FK → profiles | Chi compie l'azione |
| `kind` | message_reaction_kind | `applied` \| `withdrawn` |
| `emoji` | text nullable | Obbligatorio se `applied`; assente se `withdrawn` (max 32 char) |
| `occurred_at` | timestamptz | default `now()` |

**CHECK**: `applied` ↔ `emoji` valorizzato; `withdrawn` ↔ `emoji` null.

**RLS**: SELECT se esiste `messages` con stesso λ e `archive_user_id = auth.uid()` — **nessuna** policy INSERT/UPDATE/DELETE (solo RPC `SECURITY DEFINER`).

**Realtime**: publication `supabase_realtime`.

**Dominio**: [messaging/commands-and-events.md](../../domain/messaging/commands-and-events.md).

---

## Partecipazione gruppo (SYS-GROUP)

Nessuna tabella aggiuntiva. Partecipazione = allow list bidirezionale su **indirizzo**:

- `reception_allowlist(archive_user_id = gruppo, allowed_address = indirizzo persona)`
- `reception_allowlist(archive_user_id = persona, allowed_address = indirizzo gruppo)`

Identità gruppo verso l'esterno: `@username` come qualsiasi account (§7.18).

---

## `outbox`

Coda eventi — popolata per **ogni** invio (locale + federato), ogni `read_receipt`, ogni reaction account. Payload include `event_kind`: `deliver`, `read_receipt`, `group_erogate`, `push_notify`, `reaction_fact`. Stato colonna `status`: tipo `queue_status`.

Colonna `message_id` — **ancora operativa** (polisemia per `event_kind`; vedi debito #264):

| `event_kind` | `message_id` punta a |
|--------------|----------------------|
| `deliver`, `group_erogate` | Copia **mittente** (o archivio gruppo per broadcast) |
| `read_receipt` | Copia **lettore** (riga in entrata con `read_at` aggiornato) |
| `push_notify` | Copia **destinatario** materializzata |
| `reaction_fact` | Riga `messages` del **reagente** nel proprio archivio (stesso λ) |

Payload `push_notify`: **`peer_address`** (non `peer_profile_id`) — vedi [push-payload.md](./push-payload.md).

**FK**: `message_id` → `messages(id)` ON DELETE CASCADE (`outbox_message_id_fkey`).

Consumer locale: worker `alfred_delivery.process_outbox` (sincrono in transazione RPC account); federato: gateway/worker async — vedi [gotham-protocol.md](../../architecture/gotham-protocol.md).

**RLS**: DENY per `authenticated`.

**Spec**: [SYS-MAILBOX](../promises/system/SYS-MAILBOX.md), [SYS-DELIVERY](../promises/system/SYS-DELIVERY.md).

---

## `alfred_delivery` (schema)

Worker infrastruttura **non-account** — unico attore autorizzato a attraversare confini [SYS-ACCOUNT-BOUNDARY](../promises/system/SYS-ACCOUNT-BOUNDARY.md).

| Funzione | Ruolo |
|----------|--------|
| `process_outbox(uuid)` | Dispatcher per `event_kind` |
| `deliver_internal(uuid)` | Recapito 1:1 / verso gruppo — routing `@server` interno vs Gotham |
| `process_read_receipt(uuid)` | Legge payload outbox → `propagate_read_receipt` |
| `propagate_read_receipt(uuid, uuid, uuid)` | UPDATE `read_at` + `read_receipt_id` su copia mittente per `logical_message_id` |
| `process_reaction_fact(uuid)` | INSERT append-only su `message_reaction_facts`; completa outbox con `reaction_fact_id` |
| `process_push_notify(uuid)` | Pipeline Web Push post-recapito ([SYS-PUSH](../promises/system/SYS-PUSH.md)) |
| `group_erogate(uuid)` | Broadcast gruppo → allow list |
| `erogate_group_message(...)` | Fan-out proxy partecipanti |
| `materialize_inbound_sender_message(...)` | Inbound federato: copia destinatario con id logico messaggio dal server mittente remoto (worker/service_role) |

**Tabelle infrastruttura** (non API client):

| Tabella | Ruolo |
|---------|--------|
| `push_settings` | Singleton VAPID / config dispatch push — `REVOKE` authenticated; lettura solo worker / service_role |

**GRANT**: nessuno su `authenticated`. Migrazioni: `20260711190000`, `20260714100000_push_subscriptions.sql`, `20260714223000_push_settings_vapid_config.sql`.

---

## `push_subscriptions` (SYS-PUSH)

| Colonna | Tipo | Note |
|---------|------|------|
| `id` | uuid PK | default `gen_random_uuid()` |
| `user_id` | uuid FK → `auth.users` | Account proprietario subscription |
| `device_id` | uuid NOT NULL | Id stabile client (`alfred_device_id`) |
| `endpoint` | text NOT NULL | URL push service browser |
| `p256dh_key` | text NOT NULL | Chiave client subscription |
| `auth_key` | text NOT NULL | Secret client subscription |
| `user_agent` | text nullable | Debug |
| `created_at` | timestamptz | default `now()` |
| `last_seen_at` | timestamptz | Aggiornato a ogni re-registrazione |

**UNIQUE**: `(user_id, device_id)`; `(user_id, endpoint)` — stesso endpoint FCM ammesso per account diversi sullo stesso browser.

**RLS**: SELECT, INSERT, UPDATE, DELETE `user_id = auth.uid()`.

**Spec**: [SYS-PUSH](../promises/system/SYS-PUSH.md).

---

---

## Storage buckets

| Bucket | Uso | Limite | Path pattern |
|--------|-----|--------|--------------|
| `chat-media` | GIF, voice, image, video | 50 MB max (video) | `{auth.uid()}/{uuid}.*` |
| `avatars` | Foto profilo | 2 MB | `{auth.uid()}/avatar.{ext}` |
| `instance-branding` | Logo/favicon/wordmark istanza (owner) | 2 MB | `branding/{logo\|favicon\|wordmark}/{uuid}.ext` — scrittura solo `is_instance_owner()` |

Pubblici (scope attuale) (URL diretti in Realtime).

---

## Oggetti rimossi (non devono esistere post-migrazione)

| Oggetto | Note |
|---------|------|
| `messages.peer_profile_id`, `messages.peer_external_address` | Sostituiti da `peer_address` |
| `reception_allowlist.allowed_profile_id` | Sostituito da `allowed_address` |
| `contacts.linked_profile_id`, `contacts.external_address`, snapshot nome/avatar | Sostituito da `address` only |
| `contact_protocol` enum; colonne `protocol` su `contacts`, `messages`, `outbox` | `20260908100000_gotham_native_drop_protocol.sql` |
| `bridge_jobs`, `sync_cursors` | `20260908100000_gotham_native_drop_protocol.sql` |
| `inbox_threads` | `20260627230000_messages_only_inbox.sql` |
| `conversations`, `conversation_participants` | message-centric refactor |
| `message_read_receipts` | `20260704120000_mailbox_per_archive_user.sql` |
| `messages.delivery_status`, `sender_id`, `recipient_profile_id`, `marker_type`, `marker_for` | `20260704120000` |
| Trigger `on_message_inserted` | `20260704120000` |
| Profili shadow per peer remoti | Vietato §7.9 |

Verifica post-migrazione: `supabase/tests/schema_smoke.sql`, `mailbox_schema_smoke.sql` (aggiornati).

---

## Migrazione dati (§7.15)

- **Solo DB dev** — niente produzione da preservare.
- «Migra e basta» — niente doppia scrittura obbligatoria.
- Backfill dev: `peer_address` da `profiles.username` dove esiste storico con `peer_profile_id`; federati da `peer_external_address`.
- Storico `mario` + `mario@<im_server_id>` verso stesso profilo: **restano due conversazioni** (coerente §7.2) — nessuna fusione.

Elenco migrazioni esistenti: directory [`supabase/migrations/`](../../../supabase/migrations/) — nuova migrazione peer_address post-implementazione.
