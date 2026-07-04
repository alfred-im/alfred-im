# MAILBOX-INBOX — Inbox da archivio owner

| Campo | Valore |
|-------|--------|
| **Spec ID** | `MAILBOX-INBOX` |
| **Layer** | capability |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-04 |
| **ADR** | [mailbox-inbox-outbox-spec.md](../../architecture/mailbox-inbox-outbox-spec.md), [no-internal-external-chat-distinction.md](../../decisions/no-internal-external-chat-distinction.md) |
| **PR** | #159 |
| **Supersedes** | [MSG-INBOX.spec.md](./MSG-INBOX.spec.md) (al merge) |
| **Superseded by** | — |

Documento per AI — elenco conversazioni = aggregazione on-read sul **mio** archivio (`owner_id = auth.uid()`). L’inbox non è tabella né entità.

---

## 1. Problema / obiettivo

L’utente vede conversazioni (preview, ordine, unread) senza duplicare metadati. Ogni riga in lista deriva solo da messaggi nel proprio archivio (in uscita e in entrata).

---

## 2. Requisiti

### MUST

| ID | Requisito |
|----|-----------|
| **MAILBOX-INBOX-REQ-001** | `list_inbox()` aggrega **solo** `messages` WHERE `owner_id = auth.uid()` |
| **MAILBOX-INBOX-REQ-002** | GROUP BY `peer_profile_id` (internal v1) |
| **MAILBOX-INBOX-REQ-003** | Payload riga: `peer_profile_id`, `display_name`, `last_message_preview`, `last_message_at`, `unread_count`, campi profilo peer |
| **MAILBOX-INBOX-REQ-004** | `list_peer_messages(peer)` = righe WHERE `owner_id = auth.uid()` AND `peer_profile_id = peer` ORDER BY `created_at` |
| **MAILBOX-INBOX-REQ-005** | Chat UI: `ChatPeer.profileId`; stessa schermata con storico vuoto o pieno |
| **MAILBOX-INBOX-REQ-006** | Prima riga inbox solo dopo primo messaggio nel mio archivio con quel peer |
| **MAILBOX-INBOX-REQ-007** | Realtime: subscribe Postgres su `messages` filtro `owner_id = io` → `InboxController.load()` |
| **MAILBOX-INBOX-REQ-008** | Realtime chat: stessa tabella; filtro `owner_id = io` AND `peer_profile_id` (canale per peer o filtro client) |
| **MAILBOX-INBOX-REQ-009** | `unread_count`: righe in entrata (`author_id <> auth.uid()`) con `read_at IS NULL` |
| **MAILBOX-INBOX-REQ-010** | Multi-account: inbox/realtime solo account in focus — [AUTH-MULTI](./AUTH-MULTI.spec.md) |
| **MAILBOX-INBOX-REQ-011** | Ricerca: [INBOX-SEARCH](./INBOX-SEARCH.spec.md) su `filteredPeers` invariato |

### SHOULD

| ID | Requisito |
|----|-----------|
| **MAILBOX-INBOX-REQ-012** | Preview per tipo: testo troncato, `[GIF]`, `🎤`, `📍 Posizione` |
| **MAILBOX-INBOX-REQ-013** | `last_message_at` = `created_at` dell’ultima riga nel mio archivio per quel peer |

### MUST NOT

| ID | Requisito |
|----|-----------|
| **MAILBOX-INBOX-REQ-014** | Tabella/cache/vista materializzata inbox |
| **MAILBOX-INBOX-REQ-015** | Query su righe dove l’utente non è `owner_id` |
| **MAILBOX-INBOX-REQ-016** | `thread_id` esposto al client |
| **MAILBOX-INBOX-REQ-017** | Record inbox prima del primo messaggio |
| **MAILBOX-INBOX-REQ-018** | Rubrica prerequisito per scrivere (invariato) |

---

## 3. Fuori scope

- Indirizzi esterni in compose (v1 unsupported)
- Offline cache inbox locale

---

## 4. Contratto

### 4.1 RPC

| RPC | Uso |
|-----|-----|
| `list_inbox()` | Elenco conversazioni da archivio owner |
| `list_peer_messages(uuid, limit?)` | Storico nel mio archivio con peer |
| `find_profile_by_username(text)` | Nuova chat |

### 4.2 Client

| Componente | Responsabilità |
|------------|----------------|
| `InboxController` | `load()` → `list_inbox()`; realtime `owner_id` |
| `InboxService` | RPC + canale Realtime |
| `MessagesController` | `peerProfileId`; `load()` anche lista vuota |
| `MessageService.subscribeToPeerMessages` | Filtro `owner_id` + peer (non più sender/recipient condiviso) |
| `HomeScreen` | `_activePeer`; `ValueKey(peer.profileId)` |

### 4.3 Semantica «inbox»

L’inbox è **organizzazione UI** della chat: un posto dove convivono messaggi inviati e ricevuti, tutti in `messages` con `owner_id = io`.

---

## 5. Tracciabilità

| REQ-ID | Verifica |
|--------|----------|
| MAILBOX-INBOX-REQ-001, REQ-002 | `mailbox_inbox_smoke.sql` |
| MAILBOX-INBOX-REQ-004 | stesso + `list_peer_messages` |
| MAILBOX-INBOX-REQ-006 | invio senza rubrica — smoke |
| MAILBOX-INBOX-REQ-007 | `inbox_provider_listen_test.dart`, `inbox_realtime_owner_filter_test.dart` |
| MAILBOX-INBOX-REQ-009 | smoke unread dopo messaggio in entrata non letto |
| MAILBOX-INBOX-REQ-010 | `multi_account_chat_scenario_test.dart` |
| MAILBOX-INBOX-REQ-011 | `INBOX-SEARCH.spec.md` |
| MAILBOX-INBOX-REQ-014 | `mailbox_schema_smoke.sql` |

Gate: `verify.sh` + `integration` + `e2e-multi`

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [MSG-INBOX](./MSG-INBOX.spec.md) | Baseline fino a merge |
| [MAILBOX-CORE](./MAILBOX-CORE.spec.md) | `owner_id` |

**Codice target**: `inbox_service.dart`, `message_service.dart`, `inbox_controller.dart`
