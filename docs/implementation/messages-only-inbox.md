# Inbox solo messaggi (messages-only)

**Data**: 2026-06-27  
**PR**: #130  
**ADR**: [address-based-messaging.md](../decisions/address-based-messaging.md)  
**Migrazione**: `supabase/migrations/20260627230000_messages_only_inbox.sql`

Documento per AI — implementazione completata del modello «solo messaggi + account», senza metadati inbox duplicati.

---

## Problema risolto

Il refactor intermedio (`inbox_threads`) introduceva:

- Tabella metadati inbox separata da `messages`
- `thread_id` esposto al client
- Distinzione bozza / thread con promozione al primo invio
- Race: `_onFirstMessageSent` azzerava la bozza prima che esistesse il thread → chat che si chiudeva dopo il primo messaggio a un account sconosciuto

**Soluzione**: inbox = aggregazione on-read su `messages` (RPC `list_inbox()`); chat identificata da `peer_profile_id` (`ChatPeer`). Niente tabella/cache inbox, niente FK verso derivati.

---

## Database

### Eliminato

| Oggetto | Motivo |
|---------|--------|
| Tabella `inbox_threads` | Duplicava preview/unread già derivabili da `messages` |
| RPC `list_thread_messages`, `mark_thread_read`, `upsert_inbox_thread` | Sostituiti da varianti peer-based |
| Trigger upsert inbox su insert messaggio | Inbox non è più una tabella |

### Aggiunto / riscritto

| Oggetto | Comportamento |
|---------|---------------|
| `list_inbox()` | `GROUP BY peer_profile_id` su messaggi inviati/ricevuti; preview, unread, ordine |
| `list_peer_messages(p_peer_profile_id)` | Storico bidirezionale con un account |
| `mark_peer_read(p_peer_profile_id)` | `read` su messaggi ricevuti da quel peer |
| `on_message_inserted` | Solo `delivered` (interno) o `outbox` (federato) |
| `sync_cursors.peer_profile_id` | Sostituisce `inbox_thread_id` (bridge futuro) |

### Realtime

- Inbox: subscribe su `messages` (sender o recipient = utente corrente)
- Chat: canale `messages-peer-{me}-{peer}` su INSERT/UPDATE

### Smoke test

- `supabase/tests/schema_smoke.sql` — `inbox_threads` non deve esistere
- `supabase/tests/send_message_to_profile_smoke.sql` — invio a profilo non in rubrica

---

## Client Flutter

### Modello

| Prima | Dopo |
|-------|------|
| `InboxThread`, `ComposeTarget` | `ChatPeer` (`profileId` only) |
| `_draftTarget` + `_activeThread` | `_activePeer` unico |
| `onFirstMessageSent` / promozione | Eliminato — stesso peer prima e dopo invio |

### File chiave

| File | Ruolo |
|------|-------|
| `lib/models/chat_peer.dart` | Identità chat = `profileId` |
| `lib/screens/home_screen.dart` | `_activePeer`; `ValueKey(peer.profileId)` su pannello chat |
| `lib/providers/messages_controller.dart` | Sempre `peerProfileId`; `load()` anche con lista vuota |
| `lib/services/inbox_service.dart` | `mark_peer_read`, realtime su `messages` |
| `lib/services/message_service.dart` | `fetchPeerMessages` via `list_peer_messages` |
| `lib/services/compose_service.dart` | Risolve username → `ChatPeer.internal(...)` |
| `lib/widgets/inbox_peer_tile.dart` | Riga inbox (ex `inbox_thread_tile`) |

### Flussi UI

1. **FAB → username**: `ComposeService` → `ChatPeer` → pannello chat vuoto → invio → chat resta aperta (stesso `profileId`)
2. **Tap riga inbox**: `ChatPeer.fromInboxRow` → carica storico
3. **Rubrica «Scrivi»**: `ChatPeer.internal` dal contatto

---

## Verifica

```bash
cd client && bash scripts/verify.sh   # obbligatorio prima di push
```

Alpha DB: migrazione applicata via Supabase MCP (`messages_only_inbox_v2`, `messages_only_inbox_rpc_drop`).

---

## Riferimenti

- Architettura Alpha: `docs/architecture/alpha-full-stack.md` §2.5, §3.5
- Registro PR: `docs/architecture/alpha-pr-registry.md`
- `PROJECT_MAP.md`, `CHANGELOG.md`, `client/README.md`
