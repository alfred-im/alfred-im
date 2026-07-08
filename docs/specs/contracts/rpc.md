# Contratto RPC — messaggistica Alpha

**Ultima revisione**: 2026-07-07  
**Status**: `implemented` su `main` (migrazioni fino a `20260707190000`, incl. revoke helper RPC)  
**Spec**: [SYS-MAILBOX](../promises/system/SYS-MAILBOX.md), [SYS-GROUP](../promises/system/SYS-GROUP.md), [SYS-CONTACTS](../promises/system/SYS-CONTACTS.md), [SYS-PROFILE](../promises/system/SYS-PROFILE.md), [SYS-RECEPTION](../promises/system/SYS-RECEPTION.md)

Fonte di verità: `supabase/migrations/`. PostgREST espone solo overload **espliciti** — niente ambiguità di firma.

**RPC pubbliche** (client): `SECURITY DEFINER`, `GRANT EXECUTE` solo a `authenticated` (revoke da `anon` e `PUBLIC`).

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

Semantica mailbox (transazione unica):

1. INSERT copia mittente (`owner_id = author_id = auth.uid()`), λ nuovo, date null
2. INSERT `outbox` (`protocol = internal`, payload con λ)
3. **Gate allow list** [SYS-RECEPTION](../promises/system/SYS-RECEPTION.md): mittente ∈ `reception_allowlist` del destinatario?
4. Se **sì**: INSERT copia destinatario (stesso λ, stesso contenuto/`media_url`); UPDATE mittente `delivered_at = now()`
5. Se **no**: skip copia destinatario; `delivered_at` resta null; outbox `completed` (rifiuto silenzioso)
6. RETURN riga mittente (sempre successo se validazione ok)

Lista allow vuota → passo 3 sempre **no** (nessuno consentito).

Idempotenza: stesso `p_client_message_id` → stessa riga mittente (no duplicati).

**MUST NOT**: promozione `delivered` senza copia destinatario materializzata; errore RPC verso mittente su rifiuto allow list; trigger `on_message_inserted` legacy.

**Helper**: `is_sender_allowed_for_reception(owner_id, sender_profile_id) → boolean` — migrazione `20260704130000`; **helper interno** (non chiamabile da client).

**Migrazioni**: `20260627210000`, `20260627220000` (drop overload 5-arg), `20260627120100` (voice), `20260702120100` (location), `20260704120000` (mailbox), `20260704130000` (reception allowlist gate).

### Destinatario gruppo (SYS-GROUP)

Se `p_recipient_profile_id` ha `profile_kind = group`:

1. Stessi passi 1–2 (copia mittente umano, outbox, λ)
2. Gate allow list bidirezionale mittente ↔ gruppo
3. Se **sì**: INSERT storico gruppo (`owner_id = gruppo`, `author_id = mittente`, **`original_author_id = mittente`**, `peer_profile_id = mittente`); `delivered_at` su copia mittente
4. **Erogazione automatica** (stessa transazione): per ogni persona in `reception_allowlist(owner_id = gruppo)` con gate gruppo ↔ persona → INSERT riga erogata (`author_id = gruppo`, `original_author_id = mittente`, `peer_profile_id = gruppo`, stesso λ)
5. Erogazione fallita per singolo partecipante: skip silenzioso; **non** altera `delivered_at` mittente oltre passo 3

Invio con `auth.uid()` = gruppo verso persona: `author_id = gruppo`, **`original_author_id = gruppo`**; gate e recapito come chat private.

### `broadcast_message_to_allowlist` (SYS-GROUP)

Solo account `profile_kind = group`. **Una** riga archivio gruppo (`original_author_id = gruppo`, `peer_profile_id = NULL`, un λ) + distribuzione proxy verso allow list (`erogate_group_message` con `original_author = gruppo`).

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
| `location` | `latitude` / `longitude` nei range |

Errori: `not authenticated`, `only group accounts can broadcast`, validazione contenuto come `send_message_to_profile`.

Idempotenza: stesso `p_client_message_id` → stessa riga archivio gruppo.

**Migrazioni**: `20260706120000`, `20260706140000`.

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
list_inbox() → setof record
```

Aggregazione su `messages` WHERE `owner_id = auth.uid()` GROUP BY `peer_profile_id`:

- `display_name`, `last_message_preview`, `last_message_at`, `unread_count`, `protocol`
- Campi profilo peer (#134): avatar, pronouns; `peer_profile_kind` per routing client (SYS-GROUP)
- `unread_count` = righe in entrata con `read_at IS NULL`
- Ordine: `last_message_at` DESC

Preview per tipo: testo troncato, `[GIF]`, `format_voice_preview`, `format_location_preview`.

**Migrazioni**: `20260627230000`, `20260628100000`, aggiornamenti voice/location, `20260704120000`, `20260706130000`.

---

## `list_peer_messages`

```sql
list_peer_messages(
  p_peer_profile_id uuid,
  p_limit integer default null
) → setof messages
```

Righe WHERE `owner_id = auth.uid()` AND `peer_profile_id = p_peer_profile_id` ORDER BY `created_at`.

---

## `mark_peer_read`

```sql
mark_peer_read(p_peer_profile_id uuid) → void
```

Chiamata dal **destinatario** all’apertura chat con un peer.

Effetti:

1. UPDATE righe in entrata nel mio archivio (`author_id = peer`, `read_at IS NULL`) SET `read_at = now()`
2. Per ogni λ toccato: UPDATE copia mittente SET `read_at = now()` (SECURITY DEFINER)

**Spec**: [SYS-MAILBOX](../promises/system/SYS-MAILBOX.md).

---

## `find_profile_by_username`

```sql
find_profile_by_username(p_username text) → table (
  id uuid, username text, display_name text, avatar_url text, pronouns text,
  profile_kind profile_kind
)
```

Risoluzione indirizzo Alfred interno → profilo pubblico (#134: avatar e pronomi; `profile_kind` per routing shell).

**Spec**: [SYS-PROFILE](../promises/system/SYS-PROFILE.md).

---

## `search_profiles`

```sql
search_profiles(p_query text, p_limit integer default 20) → table (
  id uuid, username text, display_name text, avatar_url text
)
```

Ricerca utenti Alfred per aggiunta contatto internal (min 2 caratteri client). Esclude `auth.uid()`.

**Spec**: [SYS-CONTACTS](../promises/system/SYS-CONTACTS.md).

---

## Helper interni (non API client)

Funzioni `SECURITY DEFINER` invocate **solo** da altre RPC SQL. **MUST NOT** avere `GRANT EXECUTE` per `authenticated` — evita enumerazione allow list e bypass gate via PostgREST.

| Funzione | Uso interno | Migrazione |
|----------|-------------|------------|
| `is_sender_allowed_for_reception(uuid, uuid)` | Gate allow list in `send_message_to_profile` | `20260704130000` |
| `is_bidirectional_allowed(uuid, uuid, uuid)` | Gate bidirezionale gruppo | `20260706120000` |
| `profile_kind_of(uuid)` | Routing `profile_kind` in RPC | `20260706120000` |
| `erogate_group_message(...)` | Fan-out proxy gruppo | `20260706120000` |

Revoca `authenticated`: migrazione `20260707190000`. Smoke: `supabase/tests/rpc_helper_security_smoke.sql`.

Spec: SYS-RECEPTION-028, SYS-GROUP-028, SYS-GROUP-027.

---

## Enum `message_content_type`

Valori su `main`: `text`, `gif`, `voice`, `location`.

Aggiunta enum in migrazioni separate (commit enum prima dell’uso in RPC).

---

## Smoke test

| File | Verifica |
|------|----------|
| `supabase/tests/schema_smoke.sql` | Assenza `inbox_threads`, `message_read_receipts`; schema mailbox |
| `supabase/tests/mailbox_schema_smoke.sql` | `owner_id`, assenza `delivery_status` su `messages` |
| `supabase/tests/mailbox_send_smoke.sql` | Invio + `delivered_at` |
| `supabase/tests/mailbox_idempotency_smoke.sql` | Idempotenza `client_message_id` |
| `supabase/tests/mailbox_delivery_smoke.sql` | Copia destinatario + outbox `completed` |
| `supabase/tests/mailbox_read_smoke.sql` | `mark_peer_read` → `read_at` mittente |
| `supabase/tests/mailbox_inbox_smoke.sql` | `list_inbox` + unread |
| `supabase/tests/mailbox_send_media_smoke.sql` | Validazione `gif`/`location` |
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
| `search_profiles` | `ContactService.searchProfiles` |
| `reception_allowlist` (PostgREST) | `ReceptionAllowlistService` |

---

## Riferimenti

- [alpha-full-stack.md](../../architecture/alpha-full-stack.md) §3
- Migrazioni in [alpha-pr-registry.md](../../architecture/alpha-pr-registry.md) § migrazioni
