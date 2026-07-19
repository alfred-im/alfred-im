# Contratto RPC — messaggistica

**Ultima revisione**: 2026-07-19  
**Status**: `implemented` su `main` (migrazioni fino a `20260715230000`, 38 totali in `supabase/migrations/`)  
**Spec**: [SYS-MAILBOX](../promises/system/SYS-MAILBOX.md), [SYS-GROUP](../promises/system/SYS-GROUP.md), [SYS-CONTACTS](../promises/system/SYS-CONTACTS.md), [SYS-PROFILE](../promises/system/SYS-PROFILE.md), [SYS-RECEPTION](../promises/system/SYS-RECEPTION.md), [SYS-ACCOUNT-BOUNDARY](../promises/system/SYS-ACCOUNT-BOUNDARY.md), [SYS-DELIVERY](../promises/system/SYS-DELIVERY.md), [SYS-PUSH](../promises/system/SYS-PUSH.md) (`implemented`)

Fonte di verità: `supabase/migrations/`. PostgREST espone solo overload **espliciti** — niente ambiguità di firma.

**RPC pubbliche** (client): `SECURITY DEFINER`. **`GRANT EXECUTE` a `authenticated`** per le RPC messaggistica/profilo (revoke da `anon` e `PUBLIC`), salvo eccezione sotto.

**Eccezione registrazione**: `is_username_available` — `GRANT EXECUTE` anche ad **`anon`** (disponibilità username prima del login).

**Helper interni** (`SECURITY DEFINER`): usati solo da altre funzioni SQL — **MUST NOT** `GRANT EXECUTE` a `authenticated` (vedi [Helper interni](#helper-interni-non-api-client)).

---

## `send_message_to_profile`

**Unico punto invio messaggi.**

```sql
send_message_to_profile(
  p_recipient_profile_id uuid,
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

| `content_type` | Validazione |
|----------------|-------------|
| `text` | `body` trim non vuoto |
| `gif` | `media_url` obbligatorio |
| `voice` | `media_url`, `duration_seconds` > 0, `media_mime` obbligatori |
| `location` | `latitude` ∈ [-90,90], `longitude` ∈ [-180,180] |

Errori comuni: `not authenticated`, `cannot message yourself`, `recipient not found`, `empty message`, `unsupported content_type`.

Semantica mailbox ([SYS-ACCOUNT-BOUNDARY](../promises/system/SYS-ACCOUNT-BOUNDARY.md) — RPC account solo confine mittente):

1. INSERT copia mittente (`owner_id = author_id = auth.uid()`), λ nuovo, date null
2. INSERT `outbox` (`protocol = internal`, `event_kind = deliver`, `status = queued`)
3. `alfred_delivery.process_outbox` (worker, stessa transazione):
   - **Gate allow list** [SYS-RECEPTION](../promises/system/SYS-RECEPTION.md): mittente ∈ `reception_allowlist` del destinatario?
   - Se **sì**: INSERT copia destinatario; UPDATE mittente `delivered_at = now()`
   - Se **no**: skip copia destinatario; `delivered_at` resta null; outbox `completed` (rifiuto silenzioso)
4. RETURN riga mittente (sempre successo se validazione ok)

Lista allow vuota → passo 3 sempre **no** (nessuno consentito).

Idempotenza: stesso `p_client_message_id` → stessa riga mittente (no duplicati).

**MUST NOT**: promozione `delivered` senza copia destinatario materializzata; errore RPC verso mittente su rifiuto allow list; trigger `on_message_inserted` legacy.

**Helper**: `is_sender_allowed_for_reception(owner_id, sender_profile_id) → boolean` — migrazione `20260704130000`; **helper interno** (non chiamabile da client).

**Migrazioni**: `20260627210000`, `20260627220000` (drop overload 5-arg), `20260627120100` (voice), `20260702120100` (location), `20260704120000` (mailbox), `20260704130000` (reception allowlist gate), `20260711190000` (delivery plane).

### Destinatario gruppo (SYS-GROUP)

Se `p_recipient_profile_id` ha `profile_kind = group` — recapito via worker [SYS-DELIVERY](../promises/system/SYS-DELIVERY.md):

1. Stessi passi 1–2 (solo copia mittente umano + outbox)
2. Worker: gate allow list **bidirezionale** mittente ↔ gruppo — due chiamate `is_sender_allowed_for_reception` (gruppo←mittente e mittente←gruppo); **non** usa `is_bidirectional_allowed`
3. Se **sì**: INSERT storico gruppo; `delivered_at` su copia mittente; erogazione automatica verso allow list gruppo
4. Erogazione fallita per singolo partecipante: skip silenzioso; **non** altera `delivered_at` mittente oltre passo 3

Invio con `auth.uid()` = gruppo verso persona: `author_id = gruppo`, **`original_author_id = gruppo`**; gate e recapito come chat private.

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

| `content_type` | Validazione |
|----------------|-------------|
| `text` | `body` trim non vuoto |
| `gif` | `media_url` obbligatorio |
| `voice` | `media_url`, `duration_seconds` > 0, `media_mime` obbligatori |
| `location` | `latitude` / `longitude` obbligatori (senza range [-90,90]/[-180,180] come `send_message_to_profile`) |

Errori: `not authenticated`, `only group accounts can broadcast`, `no allow list recipients`, validazione contenuto come tabella sopra.

Idempotenza: stesso `p_client_message_id` → stessa riga archivio gruppo.

**Migrazioni**: `20260706120000`, `20260706140000`, `20260711190000`.

---

## `list_owner_messages`

Storico unico account gruppo (shell senza inbox peer).

```sql
list_owner_messages(
  p_limit integer default 100
) → setof messages
```

Righe WHERE `owner_id = auth.uid()` AND contenuto renderizzabile (`mailbox_has_renderable_content`) ORDER BY `created_at` ASC.

Usato da account `profile_kind = group` al posto di `list_peer_messages` — vedi [SYS-GROUP](../promises/system/SYS-GROUP.md) REQ-006/017.

**Migrazioni**: `20260706120000`.

---

## `list_inbox`

Non usato quando `auth.uid()` è account `group` — vedi [SYS-GROUP](../promises/system/SYS-GROUP.md).

```sql
list_inbox() → table (
  protocol contact_protocol,
  display_name text,
  peer_profile_id uuid,
  peer_external_address text,
  peer_avatar_url text,
  peer_pronouns text,
  peer_profile_kind profile_kind,
  last_message_preview text,
  last_message_at timestamptz,
  unread_count integer
)
```

Aggregazione su `messages` WHERE `owner_id = auth.uid()`:

- Solo `protocol = 'internal'`, `peer_profile_id IS NOT NULL`, `mailbox_has_renderable_content(body, content_type)`
- `unread_count` = righe **in entrata** (`author_id <> owner_id`) con `read_at IS NULL`
- Ordine: `last_message_at` DESC

Preview per tipo: testo troncato, `[GIF]`, `format_voice_preview`, `format_location_preview`.

**Migrazioni**: `20260627230000`, `20260628100000`, aggiornamenti voice/location, `20260704120000`, `20260706130000`.

---

## `list_peer_messages`

```sql
list_peer_messages(
  p_peer_profile_id uuid,
  p_limit integer default 100,
  p_before_created_at timestamptz default null
) → setof messages
```

Righe WHERE `owner_id = auth.uid()` AND `peer_profile_id = p_peer_profile_id` AND `mailbox_has_renderable_content(...)`.

- Senza cursore: **ultimi** `p_limit` messaggi (finestra recente), restituiti in ordine cronologico ASC.
- Con `p_before_created_at`: fino a `p_limit` messaggi con `created_at < p_before_created_at` (pagina più vecchia), ordine ASC.

`LIMIT greatest(1, least(coalesce(p_limit, 100), 500))`.

L'anteprima `list_inbox` per un peer deve cadere nella finestra senza cursore quando esiste storico.

---

## `mark_peer_read`

```sql
mark_peer_read(p_peer_profile_id uuid) → void
```

Chiamata dal **destinatario** all’apertura chat con un peer.

Effetti (solo confine lettore — [SYS-ACCOUNT-BOUNDARY](../promises/system/SYS-ACCOUNT-BOUNDARY.md)):

1. UPDATE righe in entrata nel mio archivio (`author_id = peer`, `read_at IS NULL`, contenuto renderizzabile) SET `read_at = now()`
2. Per ogni λ: INSERT outbox `event_kind = read_receipt` con **`message_id` = id riga lettore** (copia in entrata) → worker `process_read_receipt` → `read_at` sulla copia mittente

**Spec**: [SYS-MAILBOX](../promises/system/SYS-MAILBOX.md).

---

## `find_profile_by_username`

```sql
find_profile_by_username(p_username text) → table (
  id uuid, username text, display_name text, avatar_url text, pronouns text,
  profile_kind profile_kind
)
```

Risoluzione indirizzo Alfred interno → profilo pubblico (#134: avatar e pronomi; `profile_kind` per routing shell). Richiede `auth.uid()`; **esclude** il proprio profilo (`p.id <> auth.uid()`).

**Spec**: [SYS-PROFILE](../promises/system/SYS-PROFILE.md).

---

## `is_username_available`

```sql
is_username_available(p_username text) → boolean
```

Verifica namespace username (registrazione). **`GRANT EXECUTE` a `anon` e `authenticated`**.

**Migrazioni**: `20260625120000`.

---

## `search_profiles`

```sql
search_profiles(p_query text, p_limit integer default 20) → table (
  id uuid, username text, display_name text, avatar_url text
)
```

Ricerca utenti Alfred per aggiunta contatto internal (min 2 caratteri client). Esclude `auth.uid()`. `p_limit` default 20, **cap 50** in SQL (`least(p_limit, 50)`).

**Spec**: [SYS-CONTACTS](../promises/system/SYS-CONTACTS.md).

---

## Helper interni (non API client)

Funzioni `SECURITY DEFINER` invocate **solo** da worker `alfred_delivery` o altre RPC SQL. **MUST NOT** avere `GRANT EXECUTE` per `authenticated`.

| Funzione | Uso interno | Migrazione |
|----------|-------------|------------|
| `mailbox_has_renderable_content(text, message_content_type)` | Filtro contenuto renderizzabile in inbox/liste | `20260704120000` |
| `format_voice_preview(integer)` | Preview inbox voice | `20260627120100` |
| `format_location_preview()` | Preview inbox location | `20260702120100` |
| `is_sender_allowed_for_reception(uuid, uuid)` | Gate allow list nel worker delivery | `20260704130000` |
| `is_bidirectional_allowed(uuid, uuid, uuid)` | Helper gruppo legacy — **non** invocata dal worker #179 | `20260706120000` |
| `profile_kind_of(uuid)` | Routing `profile_kind` in RPC account | `20260706120000` |
| `alfred_delivery.process_outbox(uuid)` | Dispatcher outbox | `20260711190000` |
| `alfred_delivery.deliver_internal(uuid)` | Recapito 1:1 / verso gruppo | `20260711190000` |
| `alfred_delivery.process_read_receipt(uuid)` | Propaga `read_at` mittente | `20260711190000` |
| `alfred_delivery.propagate_read_receipt(uuid, uuid)` | UPDATE `read_at` copia mittente per λ | `20260711190000` |
| `alfred_delivery.group_erogate(uuid)` | Broadcast gruppo → allow list | `20260711190000` |
| `alfred_delivery.erogate_group_message(...)` | Fan-out proxy gruppo | `20260711190000` |

Revoca `authenticated`: migrazione `20260707190000`. Smoke: `supabase/tests/rpc_helper_security_smoke.sql`.

Spec: SYS-RECEPTION-028, SYS-GROUP-028, SYS-GROUP-027.

---

## Enum `message_content_type`

Valori su `main`: `text`, `gif`, `voice`, `location`, `image`, `video`.

Aggiunta enum in migrazioni separate (commit enum prima dell’uso in RPC).

---

## Smoke test

| File | Verifica |
|------|----------|
| `supabase/tests/schema_smoke.sql` | Assenza `inbox_threads`, `message_read_receipts`; schema mailbox |
| `supabase/tests/mailbox_schema_smoke.sql` | `owner_id`, assenza `delivery_status` su `messages` |
| `supabase/tests/delivery_ticks_smoke.sql` | Contratto ✓ / ✓✓ grigie / ✓✓ blu + allow list + outbox `event_kind` |
| `supabase/tests/mailbox_send_smoke.sql` | Invio + `delivered_at` |
| `supabase/tests/mailbox_idempotency_smoke.sql` | Idempotenza `client_message_id` |
| `supabase/tests/mailbox_delivery_smoke.sql` | Copia destinatario + outbox `completed` |
| `supabase/tests/mailbox_read_smoke.sql` | `mark_peer_read` → `read_at` mittente |
| `supabase/tests/mailbox_inbox_smoke.sql` | `list_inbox` + unread |
| `supabase/tests/mailbox_send_media_smoke.sql` | Validazione `gif` / `location` / `image` / `video` |
| `supabase/tests/send_message_to_profile_smoke.sql` | Invio a profilo non in rubrica |
| `supabase/tests/reception_allowlist_schema_smoke.sql` | Tabella + helper gate |
| `supabase/tests/reception_allowlist_gate_smoke.sql` | Rifiuto silenzioso vs recapito allowed |
| `supabase/tests/rpc_helper_security_smoke.sql` | Helper interni non eseguibili da `authenticated` |
| `supabase/tests/group_schema_smoke.sql` | `list_owner_messages`, `profile_kind`, `broadcast_message_to_allowlist` |

Gate client: `verify.sh` + `bash scripts/test.sh integration` + `bash scripts/test.sh e2e-multi`

---

## Client mapping

| RPC | Service Dart |
|-----|--------------|
| `send_message_to_profile` | `MessageService.sendToProfile` |
| `broadcast_message_to_allowlist` | `MessageService.broadcastToAllowlist` / `broadcastGifToAllowlist` / … |
| `list_inbox` | `InboxService.fetchInbox` |
| `list_peer_messages` | `MessageService.fetchPeerMessages` |
| `list_owner_messages` | `MessageService.fetchOwnerMessages` |
| `mark_peer_read` | `InboxService.markPeerRead` |
| `find_profile_by_username` | `ComposeService` / profile lookup |
| `is_username_available` | Registrazione / validazione username |
| `search_profiles` | `ContactService.searchProfiles` |
| `reception_allowlist` (PostgREST) | `ReceptionAllowlistService` |
| `push_subscriptions` (PostgREST) | `PushSubscriptionService` — [SYS-PUSH](../promises/system/SYS-PUSH.md) |

---

## `push_subscriptions` (PostgREST — SYS-PUSH)

Client autenticato: UPSERT via PostgREST su `push_subscriptions` (RLS `user_id = auth.uid()`).

| Operazione | Quando |
|------------|--------|
| UPSERT `(user_id, device_id, endpoint, keys…)` | Permesso browser `granted`; login; aggiungi account; avvio app |
| DELETE `WHERE user_id AND device_id` | Chiudi account |

**MUST NOT**: client invoca Edge Function `send-push`.

**Spec**: [SYS-PUSH](../promises/system/SYS-PUSH.md), [PROM-PUSH-NOTIFY](../promises/product/PROM-PUSH-NOTIFY.md).

---

## Edge Function `send-push` (SYS-PUSH)

Invocata solo da infrastruttura server (hook delivery / `push_notify` outbox). Non esposta al client.

Input (JSON): `recipient_user_id`, `peer_profile_id`, `peer_display_name`, `preview_text`, `logical_message_id`, `content_type`.

---

## Riferimenti

- [full-stack.md](../../architecture/full-stack.md) §3
- Migrazioni in [`supabase/migrations/`](../../../supabase/migrations/)
