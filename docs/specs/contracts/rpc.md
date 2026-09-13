# Contratto RPC — messaggistica

**Ultima revisione**: 2026-09-13  
**Status**: `approved` — amend §7 peer_address (migrazione dev pendente; codice attuale ancora su UUID)  
**Spec**: [SYS-MAILBOX](../promises/system/SYS-MAILBOX.md), [SYS-GROUP](../promises/system/SYS-GROUP.md), [SYS-CONTACTS](../promises/system/SYS-CONTACTS.md), [SYS-PROFILE](../promises/system/SYS-PROFILE.md), [SYS-RECEPTION](../promises/system/SYS-RECEPTION.md), [SYS-ACCOUNT-BOUNDARY](../promises/system/SYS-ACCOUNT-BOUNDARY.md), [SYS-DELIVERY](../promises/system/SYS-DELIVERY.md), [SYS-PUSH](../promises/system/SYS-PUSH.md)

Fonte di verità target: migrazione post-approvazione in `supabase/migrations/`. PostgREST espone solo overload **espliciti** — niente ambiguità di firma.

**Identità conversazione**: parametro unificato **`peer_address` text** (lowercase) — **MUST NOT** usare UUID come chiave conversazione nelle RPC account.

**RPC pubbliche** (client): `SECURITY DEFINER`. **`GRANT EXECUTE` a `authenticated`** per le RPC messaggistica/profilo (revoke da `anon` e `PUBLIC`), salvo eccezione sotto.

**Eccezione registrazione**: `is_username_available` — `GRANT EXECUTE` anche ad **`anon`** (disponibilità username prima del login).

**Helper interni** (`SECURITY DEFINER`): usati solo da altre funzioni SQL — **MUST NOT** `GRANT EXECUTE` a `authenticated` (vedi [Helper interni](#helper-interni-non-api-client)).

---

## `send_message_to_address`

**Unico punto invio messaggi 1:1** (sostituisce `send_message_to_profile` con UUID destinatario).

```sql
send_message_to_address(
  p_peer_address text,
  p_body text default '',
  p_client_message_id text default null,
  p_content_type message_content_type default 'text',
  p_media_url text default null,
  p_duration_seconds integer default null,
  p_media_mime text default null,
  p_media_size_bytes bigint default null,
  p_latitude double precision default null,
  p_longitude double precision default null
) → messages
```

| Parametro | Regola |
|-----------|--------|
| `p_peer_address` | Normalizzato lowercase; `username` o `user@server`; chiave conversazione |

| `content_type` | Validazione |
|----------------|-------------|
| `text` | `body` trim non vuoto |
| `gif` | `media_url` obbligatorio |
| `voice` | `media_url`, `duration_seconds` > 0, `media_mime` obbligatori |
| `location` | `latitude` ∈ [-90,90], `longitude` ∈ [-180,180] |

Errori comuni: `not authenticated`, `cannot message yourself`, `invalid peer address`, `recipient not in reception allowlist`, `empty message`, `unsupported content_type`.

Semantica mailbox ([SYS-ACCOUNT-BOUNDARY](../promises/system/SYS-ACCOUNT-BOUNDARY.md) — RPC account solo confine mittente):

0. Normalizza `p_peer_address` → lowercase; risolve indirizzo mittente canonico per `author_address` (§7.5b)
1. Gate **outbound** [SYS-RECEPTION](../promises/system/SYS-RECEPTION.md): `p_peer_address` ∈ allow list del mittente? Se **no** → `raise exception 'recipient not in reception allowlist'`
2. INSERT copia mittente (`archive_user_id = auth.uid()`, `peer_address`, `author_address`, `author_id` nullable se non richiesto), λ mintato, date null
3. INSERT `outbox` (`event_kind = deliver`, `status = queued`)
4. `alfred_delivery.process_outbox` (worker, stessa transazione):
   - **Gate allow list inbound**: mittente ∈ allow list del destinatario (match su `author_address`)?
   - Se **sì**: INSERT copia destinatario; UPDATE mittente `delivered_at = now()`
   - Se **no**: skip copia destinatario; `delivered_at` resta null; outbox `completed` (rifiuto silenzioso)
5. RETURN riga mittente

**Delivery** è l'unico modulo che legge `@server` e sceglie driver interno vs Gotham — non tipologia chat.

Idempotenza: stesso `p_client_message_id` → stessa riga mittente (no duplicati).

**MUST NOT**: promozione `delivered` senza copia destinatario materializzata; errore RPC verso mittente su rifiuto allow list **inbound**; INSERT copia mittente su violazione gate **outbound**; invio con parametro UUID destinatario.

**Helper**: `is_address_allowed_for_reception(archive_user_id, allowed_address) → boolean` — gate su indirizzo; **helper interno** (non chiamabile da client).

### Destinatario gruppo (SYS-GROUP)

Se `p_peer_address` risolve a account `profile_kind = group` sulla stessa istanza — recapito via worker [SYS-DELIVERY](../promises/system/SYS-DELIVERY.md):

1. Stessi passi 1–3 (copia mittente umano + outbox)
2. Worker: gate allow list **bidirezionale** su indirizzo mittente ↔ indirizzo gruppo
3. Se **sì**: INSERT storico gruppo; `delivered_at` su copia mittente; erogazione automatica verso allow list gruppo
4. Erogazione fallita per singolo partecipante: skip silenzioso

Invio con sessione gruppo verso persona: `author_id = gruppo`, `author_address` = indirizzo gruppo, `original_author_id` valorizzato.

### `broadcast_message_to_allowlist` (SYS-GROUP)

Solo account `profile_kind = group`. **Una** riga archivio gruppo + outbox `event_kind = group_erogate` → worker `alfred_delivery.group_erogate`.

```sql
broadcast_message_to_allowlist(
  p_body text default '',
  p_client_message_id text default null,
  p_content_type message_content_type default 'text',
  p_media_url text default null,
  p_duration_seconds integer default null,
  p_media_mime text default null,
  p_media_size_bytes bigint default null,
  p_latitude double precision default null,
  p_longitude double precision default null
) → messages
```

Validazione contenuto invariata. Broadcast: `peer_address` NULL sullo storico gruppo.

---

## `list_archive_messages`

Storico unico account gruppo (shell senza inbox peer).

```sql
list_archive_messages(
  p_limit integer default 100
) → setof messages
```

Righe WHERE `archive_user_id = auth.uid()` AND contenuto renderizzabile ORDER BY `created_at` ASC.

Usato da account `profile_kind = group` al posto di `list_peer_messages`.

---

## `list_inbox`

Non usato quando `auth.uid()` è account `group`.

```sql
list_inbox() → table (
  peer_address text,
  display_name text,
  avatar_url text,
  cover_url text,
  pronouns text,
  profile_kind profile_kind,
  peer_in_contacts boolean,
  peer_is_allowed boolean,
  last_message_preview text,
  last_message_at timestamptz,
  unread_count integer
)
```

Aggregazione su `messages` WHERE `archive_user_id = auth.uid()`:

- GROUP BY **`peer_address`** (non UUID)
- Solo righe con `peer_address IS NOT NULL` e contenuto renderizzabile
- `unread_count` = righe **in entrata** (`author_address` ≠ indirizzo titolare archivio **oppure** `author_id <> archive_user_id` dove applicabile) con `read_at IS NULL`
- Ordine: `last_message_at` DESC

Presentazione profilo: join locale `profiles` dove `peer_address` = bare username; altrimenti fallback indirizzo grezzo — arricchimento batch via `get_profiles` lato client.

`peer_in_contacts` / `peer_is_allowed`: match su `contacts.address` e `reception_allowlist.allowed_address`.

**MUST NOT**: filtrare solo righe con UUID locale; escludere chat federate per assenza `profiles.id`.

---

## `list_peer_messages`

```sql
list_peer_messages(
  p_peer_address text,
  p_limit integer default 100,
  p_before_created_at timestamptz default null
) → setof messages
```

Righe WHERE `archive_user_id = auth.uid()` AND **`peer_address = lower(p_peer_address)`** AND contenuto renderizzabile.

- Senza cursore: **ultimi** `p_limit` messaggi, ordine cronologico ASC.
- Con `p_before_created_at`: pagina più vecchia, ordine ASC.
- `LIMIT greatest(1, least(coalesce(p_limit, 100), 500))`.

L'anteprima `list_inbox` per un peer deve cadere nella finestra senza cursore.

**MUST NOT**: overload con `p_peer_profile_id uuid`.

---

## `mark_peer_read`

```sql
mark_peer_read(p_peer_address text) → void
```

Chiamata dal **destinatario** all'apertura chat con controparte identificata da indirizzo.

Effetti (solo confine lettore):

1. UPDATE righe in entrata nel mio archivio (`peer_address = lower(p_peer_address)`, entrata, `read_at IS NULL`, contenuto renderizzabile) SET `read_at = now()`, mint `read_receipt_id`
2. Per ogni λ: INSERT outbox `event_kind = read_receipt` → worker propaga `read_at` + `read_receipt_id` sulla copia mittente (match λ + `peer_address` / indirizzo mittente)

**MUST NOT**: parametro UUID peer.

---

## `get_profiles`

**Batch presentazione profilo pubblico** — non gated da allow list (§7.12).

```sql
get_profiles(p_addresses text[]) → table (
  address text,
  display_name text,
  avatar_url text,
  cover_url text,
  pronouns text,
  profile_kind profile_kind
)
```

| Regola | Dettaglio |
|--------|-----------|
| Input | Array indirizzi lowercase; ordine output non garantito |
| Locale | Join `profiles` per bare username o FQDN stessa istanza |
| Federato | Risposta da reception API / wire profilo (passo 5 Gotham); finché assente → riga con solo `address` |
| Allow list | **Non** filtra visibilità — governa solo recapito messaggi |
| Shadow | **MUST NOT** INSERT in `profiles` per peer remoti |

Usato da inbox, rubrica, overlay, header chat — stesso batch ovunque.

**Spec**: [SYS-PROFILE](../promises/system/SYS-PROFILE.md) SYS-PROFILE-009–011.

---

## `apply_message_reaction`

```sql
apply_message_reaction(p_logical_message_id uuid, p_emoji text) → message_reaction_facts
```

Invariato — ancorato a λ, non a identità peer.

---

## `withdraw_message_reaction`

```sql
withdraw_message_reaction(p_logical_message_id uuid) → message_reaction_facts | null
```

Invariato.

---

## `list_message_reactions`

```sql
list_message_reactions(p_logical_message_ids uuid[]) → table (
  logical_message_id uuid,
  emoji text,
  reaction_count bigint,
  reactor_ids uuid[],
  includes_me boolean
)
```

Invariato.

---

## `find_profile_by_username`

```sql
find_profile_by_username(p_username text) → table (
  id uuid, username text, display_name text, avatar_url text, cover_url text, pronouns text,
  profile_kind profile_kind,
  peer_in_contacts boolean,
  peer_is_allowed boolean
)
```

Risoluzione **bare username** locale (stessa istanza). Per compose/link con `user@server` usare indirizzo diretto + `get_profiles`.

Flag relazione: match su `contacts.address` e `reception_allowlist.allowed_address`.

**Spec**: [SYS-PROFILE](../promises/system/SYS-PROFILE.md).

---

## `get_peer_context`

```sql
get_peer_context(p_peer_address text) → table (
  address text,
  display_name text,
  avatar_url text,
  cover_url text,
  pronouns text,
  profile_kind profile_kind,
  peer_in_contacts boolean,
  peer_is_allowed boolean
)
```

Profilo pubblico + flag relazione per indirizzo. Sostituisce overload UUID. Implementazione: delega a `get_profiles(array[p_peer_address])` + flag relazione.

Usato quando il peer non è ancora in `list_inbox()` (push, link, compose).

**MUST NOT**: richiedere `profiles.id` locale per peer federato.

---

## `is_username_available`

```sql
is_username_available(p_username text) → boolean
```

Invariato. **`GRANT EXECUTE` a `anon` e `authenticated`**.

---

## `search_profiles`

```sql
search_profiles(p_query text, p_limit integer default 20) → table (
  id uuid, username text, display_name text, avatar_url text,
  peer_in_contacts boolean,
  peer_is_allowed boolean
)
```

Ricerca utenti Alfred per aggiunta contatto — restituisce username da salvare come `contacts.address` (bare). Flag relazione su indirizzo.

**Spec**: [SYS-CONTACTS](../promises/system/SYS-CONTACTS.md).

---

## Helper interni (non API client)

Funzioni `SECURITY DEFINER` invocate **solo** da worker `alfred_delivery` o altre RPC SQL. **MUST NOT** avere `GRANT EXECUTE` per `authenticated`.

| Funzione | Uso interno |
|----------|-------------|
| `mailbox_has_renderable_content(text, message_content_type)` | Filtro contenuto renderizzabile |
| `format_voice_preview(integer)` | Preview inbox voice |
| `format_location_preview()` | Preview inbox location |
| `is_address_allowed_for_reception(uuid, text)` | Gate allow list su indirizzo (inbound/outbound) |
| `resolve_local_profile_id(text)` | Risoluzione bare username → uuid (solo delivery interno) |
| `profile_kind_of(uuid)` | Routing `profile_kind` in RPC account |
| `alfred_delivery.process_outbox(uuid)` | Dispatcher outbox |
| `alfred_delivery.deliver_internal(uuid)` | Recapito 1:1 / verso gruppo |
| `alfred_delivery.process_read_receipt(uuid)` | Propaga lettura |
| `alfred_delivery.propagate_read_receipt(...)` | UPDATE copia mittente |
| `alfred_delivery.process_reaction_fact(uuid)` | INSERT fatto reaction |
| `alfred_delivery.process_push_notify(uuid)` | Pipeline Web Push |
| `alfred_delivery.group_erogate(uuid)` | Broadcast gruppo |
| `alfred_delivery.erogate_group_message(...)` | Fan-out proxy gruppo |
| `alfred_delivery.materialize_inbound_sender_message(...)` | Inbound federato |

**Deprecati post-migrazione**: `is_sender_allowed_for_reception(uuid, uuid)`, `get_peer_context(uuid)`.

---

## Enum `message_content_type`

Valori: `text`, `gif`, `voice`, `location`, `image`, `video`.

---

## Smoke test (target post-migrazione)

| File | Verifica |
|------|----------|
| `supabase/tests/mailbox_schema_smoke.sql` | `peer_address`, `author_address`; assenza colonne UUID chat |
| `supabase/tests/mailbox_inbox_smoke.sql` | `list_inbox` GROUP BY `peer_address` |
| `supabase/tests/mailbox_peer_messages_window_smoke.sql` | `list_peer_messages(text)` |
| `supabase/tests/reception_allowlist_schema_smoke.sql` | `allowed_address` |
| `supabase/tests/get_profiles_smoke.sql` | Batch locale + fallback federato |
| `supabase/tests/mailbox_read_smoke.sql` | `mark_peer_read(text)` |

Gate client post-implementazione: `verify.sh` + `bash scripts/test.sh e2e`

---

## Client mapping (target)

| RPC | Service Dart |
|-----|--------------|
| `send_message_to_address` | `PeerMessageService.sendToAddress` |
| `broadcast_message_to_allowlist` | `GroupArchiveService.broadcastToAllowlist` |
| `list_inbox` | `InboxService.fetchInbox` |
| `list_peer_messages` | `PeerMessageService.fetchPeerMessages` |
| `list_archive_messages` | `GroupArchiveService.fetchArchiveMessages` |
| `mark_peer_read` | `InboxService.markPeerRead` |
| `get_profiles` | `ProfileService.fetchByAddresses` |
| `get_peer_context` | `ProfileService.fetchPeerContext` |
| `find_profile_by_username` | Compose / shareable-link lookup locale |
| `search_profiles` | `ContactService.searchProfiles` |
| `reception_allowlist` (PostgREST) | `ReceptionAllowlistService` — CRUD su `allowed_address` |
| `contacts` (PostgREST) | `ContactService` — CRUD su `address` |

---

## `push_subscriptions` (PostgREST — SYS-PUSH)

Invariato — UPSERT via PostgREST.

---

## Edge Function `send-push` (SYS-PUSH)

Invocata solo da infrastruttura server. Non esposta al client.

Input (JSON): `recipient_user_id`, **`peer_address`**, `peer_display_name`, `preview_text`, `logical_message_id`, `content_type`.

Vedi [push-payload.md](./push-payload.md) — **`peerAddress`**, nessun `peerProfileId`, nessun dual-read.

---

## Riferimenti

- [full-stack.md](../../architecture/full-stack.md) §3
- [push-payload.md](./push-payload.md)
- [schema.md](./schema.md)
- Migrazioni target in [`supabase/migrations/`](../../../supabase/migrations/)
