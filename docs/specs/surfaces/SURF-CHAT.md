# SURF-CHAT — Pannello conversazione 1:1

| Campo | Valore |
|-------|--------|
| **Superficie ID** | `SURF-CHAT` |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-08 |
| **Promesse** | [SYS-RECEPTION](../promises/system/SYS-RECEPTION.md) (semantica spunte) |
| **PR** | #159 |

Binding UX conversazione peer-to-peer: stessa schermata con storico vuoto o pieno, spunte, invio optimistic, preview inbox.

---

## 1. Superficie

| Elemento | Valore |
|----------|--------|
| Widget | `client/lib/widgets/chat_panel.dart`, `message_bubble.dart` |
| Controller | `MessagesController` — `peerProfileId`, `load()`, invio optimistic |
| Servizi | `MessageService`, `OutboundMessageQueue` |
| Parent | `HomeScreen` — `_activePeer`; `ValueKey(peer.profileId)` |
| Modello | `ChatPeer`, `ChatMessage` — `isMine` da `author_id == currentUserId` |

---

## 2. Promesse SURFACE

### MUST

| ID | Promessa |
|----|----------|
| **SURF-CHAT-001** | Chat UI: `ChatPeer.profileId`; stessa schermata con storico vuoto o pieno |
| **SURF-CHAT-002** | Prima riga inbox solo dopo primo messaggio nel mio archivio con quel peer |
| **SURF-CHAT-003** | UI mittente: `delivered_at` null → ✓; `delivered_at` set e `read_at` null → ✓✓ grigie; `read_at` set → ✓✓ blu |
| **SURF-CHAT-004** | `mark_peer_read(peer)` chiamato dal destinatario in `MessagesController._init` dopo `load()` — non al tap riga inbox |
| **SURF-CHAT-005** | Checkmarks solo bolle `isMine` (author = io) |
| **SURF-CHAT-006** | Coda client `OutboundMessageQueue` + merge optimistic su `client_message_id` |
| **SURF-CHAT-007** | Stati client `pending`/`failed` solo lato mittente pre-ACK server — non persistiti come enum DB |
| **SURF-CHAT-008** | Preview inbox per tipo: testo troncato, `[GIF]`, `🎤`, `📍 Posizione` |

### SHOULD

| ID | Promessa |
|----|----------|
| **SURF-CHAT-009** | `pending` / `failed` visibili solo fino ad ACK server o `failed_at` sulla copia mittente |

### MUST NOT

| ID | Promessa |
|----|----------|
| **SURF-CHAT-010** | Semantica «consegnato» = device P2P peer |
| **SURF-CHAT-011** | Regressione spunte: se `read_at` già set, ignorare segnale `delivered_at` tardivo |

---

## 4. Tracciabilità

| SURF-ID | Verifica |
|---------|----------|
| SURF-CHAT-001 | `home_screen.dart` — `_activePeer`; `chat_panel.dart` |
| SURF-CHAT-002 | invio senza rubrica — smoke |
| SURF-CHAT-003 | `message_bubble_test.dart`, `models_and_utils_test.dart` |
| SURF-CHAT-004 | `mailbox_read_smoke.sql`; `messages_controller` `_init` |
| SURF-CHAT-005 | `message_bubble_test.dart` |
| SURF-CHAT-006 | `messages_controller_multi_account_test.dart`, `multi_account_scope_test.dart` |
| SURF-CHAT-008 | `inbox_controller.dart` preview helpers |
| SURF-CHAT-011 | `client/test/unit/models_and_utils_test.dart` |

Gate: `verify.sh` + `integration` + `e2e-multi`

---

## 5. Riferimenti

- [SYS-MAILBOX.md](../promises/system/SYS-MAILBOX.md) — backend RPC/realtime (invio, inbox, lettura)
- [SURF-INBOX.md](./SURF-INBOX.md) — filtro lista inbox
- [SYS-RECEPTION.md](../promises/system/SYS-RECEPTION.md) — `delivered_at` null permanente su blocco allow list
- [registry.md](../registry.md)
