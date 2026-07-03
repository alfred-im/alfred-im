# Contratto RPC — messaggistica Alpha

**Ultima revisione**: 2026-07-03  
**Status**: `implemented` (allineato a `main`, migrazioni fino a `20260702120100`)  
**Spec**: [MSG-INBOX](../capabilities/MSG-INBOX.spec.md), [MSG-SEND](../capabilities/MSG-SEND.spec.md)

Fonte di verità: `supabase/migrations/`. PostgREST espone solo overload **espliciti** — niente ambiguità di firma.

Tutte le RPC sotto: `SECURITY DEFINER`, `authenticated` only (revoke da `anon`).

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

Insert: `delivery_status = 'sent'`, `protocol = 'internal'`. Trigger `on_message_inserted` promuove a `delivered` (internal) o scrive `outbox` (federato).

**Migrazioni**: `20260627210000`, `20260627220000` (drop overload 5-arg), `20260627120100` (voice), `20260702120100` (location).

---

## `list_inbox`

```sql
list_inbox() → setof record
```

Righe derivate da `messages` per `auth.uid()`:

- Raggruppamento per `peer_profile_id`
- `display_name`, `last_message_preview`, `last_message_at`, `unread_count`, `protocol`
- Campi profilo peer (#134): avatar, username, ecc. dove presenti in migrazione `20260628100000`
- Ordine: `last_message_at` DESC

Preview per tipo: testo troncato, `[GIF]`, `format_voice_preview`, `format_location_preview`.

**Migrazioni**: `20260627230000`, `20260628100000`, aggiornamenti voice/location.

---

## `list_peer_messages`

```sql
list_peer_messages(
  p_peer_profile_id uuid,
  p_limit integer default null
) → setof messages
```

Storico bidirezionale tra utente corrente e `p_peer_profile_id`, ordinato per `created_at`.

---

## `mark_peer_read`

```sql
mark_peer_read(p_peer_profile_id uuid) → void
```

Aggiorna `delivery_status = 'read'` su messaggi **ricevuti** da quel peer (tutti i `content_type` supportati).

---

## `find_profile_by_username`

```sql
find_profile_by_username(p_username text) → profiles
```

Risoluzione indirizzo Alfred interno → profilo. Usato da nuova chat / compose.

**Migrazione**: `20260627200000_address_based_messaging.sql`.

---

## Enum `message_content_type`

Valori su `main`: `text`, `gif`, `voice`, `location`.

Aggiunta enum in migrazioni separate (commit enum prima dell’uso in RPC).

---

## Smoke test

| File | Verifica |
|------|----------|
| `supabase/tests/schema_smoke.sql` | Assenza `inbox_threads`; overload RPC corretti |
| `supabase/tests/send_message_to_profile_smoke.sql` | Invio a profilo non in rubrica |

---

## Client mapping

| RPC | Service Dart |
|-----|--------------|
| `send_message_to_profile` | `MessageService.sendToProfile` |
| `list_inbox` | `InboxService.fetchInbox` |
| `list_peer_messages` | `MessageService.fetchPeerMessages` |
| `mark_peer_read` | `InboxService.markPeerRead` |
| `find_profile_by_username` | `ComposeService` / profile lookup |

---

## Riferimenti

- [alpha-full-stack.md](../../architecture/alpha-full-stack.md) §3
- Migrazioni in [alpha-pr-registry.md](../../architecture/alpha-pr-registry.md) § migrazioni
