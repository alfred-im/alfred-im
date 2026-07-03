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

- Inbox = risultato di aggregazione **on-read** su `messages` via RPC `list_inbox()` — nessuna tabella, vista materializzata o cache inbox dedicata.
- Ogni riga inbox raggruppa per `peer_profile_id` (account Alfred interno).
- Payload riga: `peer_profile_id`, `display_name`, `last_message_preview`, `last_message_at`, `unread_count`, `protocol` (+ campi profilo da #134 dove applicabile).
- Chat identificata da `ChatPeer.profileId` — stessa UI con storico vuoto o pieno.
- Nuova chat: indirizzo `username` → risoluzione profilo → pannello chat → primo invio crea riga in inbox al prossimo `list_inbox()`.
- Storico chat: RPC `list_peer_messages(peer_profile_id)`.
- Segna letti: RPC `mark_peer_read(peer_profile_id)` all’apertura chat.
- Realtime inbox: subscribe su `messages` dove `sender_id` o `recipient_profile_id` = utente corrente → `InboxController.load()`.
- Realtime chat: canale `messages-peer-{me}-{peer}` su INSERT/UPDATE.

### SHOULD

- Indici su `messages` per coppia sender/recipient + `created_at` (prestazione Alpha).
- Preview formattata per tipo contenuto (testo troncato, `[GIF]`, `🎤`, `📍 Posizione`).

### MUST NOT

- Tabella `inbox_threads`, `conversations`, `conversation_participants` o equivalenti.
- FK da `messages` o altre tabelle verso aggregati inbox (`inbox_thread_id`, ecc.).
- `thread_id` esposto al client.
- Concetti bozza / promozione thread / `get_or_create_*` inbox.
- Prerequisito rubrica (`contacts`) per scrivere a account interni.
- Record inbox creato **prima** del primo messaggio.

---

## 3. Fuori scope

- Indirizzi esterni `user@server` (Alpha: `unsupported` fino ai bridge).
- Ricerca inbox on-demand (spec separata INBOX-SEARCH, #132).
- Modello caselle per-owner (target futuro mailbox).
- Offline / cache locale inbox (web online-only, D-031).

---

## 4. Contratto

### 4.1 Backend / RPC

Vedi [contracts/rpc.md](../contracts/rpc.md).

| RPC | Uso inbox |
|-----|-----------|
| `list_inbox()` | Elenco conversazioni derivato |
| `list_peer_messages(uuid, limit?)` | Storico con un peer |
| `mark_peer_read(uuid)` | Unread → read per messaggi ricevuti da quel peer |
| `find_profile_by_username(text)` | Risoluzione indirizzo → profilo (nuova chat) |

Trigger `on_message_inserted`: solo `delivery_status` (`delivered` interno / `outbox` federato) — **nessun** upsert inbox.

Migrazioni chiave: `20260627230000_messages_only_inbox.sql`, `20260628100000_inbox_peer_profile_fields.sql`, aggiornamenti preview in voice/location migrations.

### 4.2 Client

| Componente | Responsabilità |
|------------|----------------|
| `InboxController` | `load()` → `list_inbox()`; realtime sul focus account |
| `InboxService` | RPC + canale realtime inbox |
| `MessagesController` | `peerProfileId` obbligatorio; `load()` anche lista vuota |
| `ChatPeer` | Identità chat = `profileId` |
| `HomeScreen` | `_activePeer`; `ValueKey(peer.profileId)` su pannello chat |
| `ComposeService` | Username → `ChatPeer.internal(...)` |
| `InboxPeerTile` | Riga lista inbox |

Multi-account: inbox e realtime solo sull’account in **focus** ([AUTH-MULTI](./AUTH-MULTI.spec.md)).

### 4.3 UX

| Azione | Comportamento |
|--------|---------------|
| FAB → username | Chat vuota, stesso peer dopo primo messaggio |
| Tap riga inbox | Carica storico peer |
| Rubrica «Scrivi» | Apre chat per `profile_id` contatto |
| Messaggio ricevuto senza rubrica | Compare in inbox |

---

## 5. Verifica

| Tipo | Riferimento |
|------|-------------|
| Gate | `cd client && bash scripts/verify.sh` |
| Smoke DB | `supabase/tests/schema_smoke.sql` — `inbox_threads` non deve esistere |
| Smoke invio | `supabase/tests/send_message_to_profile_smoke.sql` |
| Integrazione | `bash scripts/test.sh integration` |
| Unit | `messages_controller_multi_account_test.dart`, `inbox_provider_lifecycle_test.dart` |

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [messages-only-inbox.md](../../implementation/messages-only-inbox.md) | Evidenza implementazione PR #130 |
| [alpha-full-stack.md](../../architecture/alpha-full-stack.md) §2.5–2.6 | Panoramica architettura |
| [mailbox-inbox-outbox-spec.md](../../architecture/mailbox-inbox-outbox-spec.md) | Target futuro (sostituirà questo modello) |

**Codice**: `client/lib/providers/inbox_controller.dart`, `services/inbox_service.dart`, `models/chat_peer.dart`, `screens/home_screen.dart`
