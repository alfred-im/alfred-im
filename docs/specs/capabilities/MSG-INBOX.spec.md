# MSG-INBOX — Inbox derivata da messaggi

| Campo | Valore |
|-------|--------|
| **Spec ID** | `MSG-INBOX` |
| **Layer** | capability |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-03 |
| **ADR** | [address-based-messaging.md](../../decisions/address-based-messaging.md), [no-internal-external-chat-distinction.md](../../decisions/no-internal-external-chat-distinction.md) |
| **PR** | #130, #134 |
| **Supersedes** | `implementation/messages-only-inbox.md` (evidenza), modello `inbox_threads` (rimosso) |
| **Superseded by** | — (futuro: modello caselle `mailbox-inbox-outbox-spec.md`) |

Documento per AI — contratto inbox Alpha su `main`: aggregazione on-read su `messages`, chat per `peer_profile_id`.

---

## 1. Problema / obiettivo

L’utente deve vedere l’elenco delle conversazioni (preview, ordine, unread) senza duplicare metadati in tabelle separate. La chat è identificata dall’**account peer**, non da thread id o bozze.

---

## 2. Requisiti

### MUST

| ID | Requisito |
|----|-----------|
| **MSG-INBOX-REQ-001** | Inbox = aggregazione **on-read** su `messages` via `list_inbox()` — nessuna tabella/cache inbox dedicata |
| **MSG-INBOX-REQ-002** | Raggruppamento per `peer_profile_id` (account Alfred interno) |
| **MSG-INBOX-REQ-003** | Payload riga: `peer_profile_id`, `display_name`, `last_message_preview`, `last_message_at`, `unread_count`, `protocol`, `peer_avatar_url`, `peer_pronouns` |
| **MSG-INBOX-REQ-004** | Chat identificata da `ChatPeer.profileId` — stessa UI con storico vuoto o pieno |
| **MSG-INBOX-REQ-005** | Nuova chat: username → profilo → pannello chat; prima riga inbox solo dopo primo messaggio (`list_inbox`) |
| **MSG-INBOX-REQ-006** | Storico: RPC `list_peer_messages(peer_profile_id)` |
| **MSG-INBOX-REQ-007** | Lettura messaggi: [MSG-READ](./MSG-READ.spec.md) — `mark_peer_read` all’apertura chat |
| **MSG-INBOX-REQ-008** | Realtime inbox: subscribe `messages` (sender o recipient = io) → `InboxController.load()` |
| **MSG-INBOX-REQ-009** | Realtime chat: canale `messages-peer-{me}-{peer}` su INSERT/UPDATE |
| **MSG-INBOX-REQ-010** | Ricerca conversazioni: [INBOX-SEARCH](./INBOX-SEARCH.spec.md) su `filteredPeers` |
| **MSG-INBOX-REQ-011** | Multi-account: inbox + realtime solo su account in focus — [AUTH-MULTI](./AUTH-MULTI.spec.md) |

### SHOULD

| ID | Requisito |
|----|-----------|
| **MSG-INBOX-REQ-012** | Indici su `messages` per coppia sender/recipient + `created_at` |
| **MSG-INBOX-REQ-013** | Preview per tipo: testo troncato, `[GIF]`, `🎤`, `📍 Posizione` |

### MUST NOT

| ID | Requisito |
|----|-----------|
| **MSG-INBOX-REQ-014** | Tabella `inbox_threads`, `conversations`, `conversation_participants` o equivalenti |
| **MSG-INBOX-REQ-015** | FK verso aggregati inbox (`inbox_thread_id`, ecc.) |
| **MSG-INBOX-REQ-016** | `thread_id` esposto al client |
| **MSG-INBOX-REQ-017** | Bozze / promozione thread / `get_or_create_*` inbox |
| **MSG-INBOX-REQ-018** | Rubrica (`contacts`) prerequisito per scrivere a account interni |
| **MSG-INBOX-REQ-019** | Record inbox creato prima del primo messaggio |

---

## 3. Fuori scope

- Indirizzi esterni `user@server` (Alpha: `unsupported`).
- Modello caselle per-owner (target mailbox).
- Offline / cache locale inbox (D-031).

---

## 4. Contratto

### 4.1 Backend / RPC

Vedi [contracts/rpc.md](../contracts/rpc.md), [contracts/schema.md](../contracts/schema.md).

| RPC | Uso |
|-----|-----|
| `list_inbox()` | Elenco conversazioni |
| `list_peer_messages(uuid, limit?)` | Storico peer |
| `find_profile_by_username(text)` | Nuova chat |

Trigger `on_message_inserted`: solo `delivery_status` / `outbox` — **nessun** upsert inbox.

### 4.2 Client

| Componente | Responsabilità |
|------------|----------------|
| `InboxController` | `load()` → `list_inbox()`; realtime focus |
| `InboxService` | RPC + canale realtime |
| `MessagesController` | `peerProfileId`; `load()` anche lista vuota |
| `ChatPeer` | Identità = `profileId` |
| `HomeScreen` | `_activePeer`; `ValueKey(peer.profileId)` |
| `ComposeService` | Username → `ChatPeer` |

---

## 5. Tracciabilità

| REQ-ID | Verifica |
|--------|----------|
| MSG-INBOX-REQ-001 | `schema_smoke.sql` — assenza `inbox_threads`; `list_inbox()` presente |
| MSG-INBOX-REQ-002, REQ-003 | `send_message_to_profile_smoke.sql` — peer in `list_inbox` dopo invio |
| MSG-INBOX-REQ-004 | `models_and_utils_test.dart` — `ChatPeer.fromInboxRow` |
| MSG-INBOX-REQ-005 | `send_message_to_profile_smoke.sql` — invio senza rubrica |
| MSG-INBOX-REQ-006 | `schema_smoke.sql` — `list_peer_messages(uuid, integer)` |
| MSG-INBOX-REQ-007 | `MSG-READ.spec.md`; `FakeInboxService.markRead` in test messaggi |
| MSG-INBOX-REQ-008 | `inbox_provider_listen_test.dart` — `InboxController` notify |
| MSG-INBOX-REQ-009 | `message_service.dart` + `messages_controller_multi_account_test.dart` (realtime mock) |
| MSG-INBOX-REQ-010 | `INBOX-SEARCH.spec.md` |
| MSG-INBOX-REQ-011 | `inbox_provider_lifecycle_test.dart`; `multi_account_chat_scenario_test.dart` |
| MSG-INBOX-REQ-014 | `schema_smoke.sql`, `send_message_to_profile_smoke.sql` |
| MSG-INBOX-REQ-018 | `send_message_to_profile_smoke.sql` — profilo non in rubrica |

Gate: `cd client && bash scripts/verify.sh` · Integrazione: `bash scripts/test.sh integration`

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [messages-only-inbox.md](../../implementation/messages-only-inbox.md) | Evidenza PR #130 |
| [alpha-full-stack.md](../../architecture/alpha-full-stack.md) | Panoramica (slim) |
| [mailbox-inbox-outbox-spec.md](../../architecture/mailbox-inbox-outbox-spec.md) | Target futuro |

**Codice**: `inbox_controller.dart`, `inbox_service.dart`, `chat_peer.dart`, `home_screen.dart`
