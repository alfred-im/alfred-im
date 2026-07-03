# MSG-READ — Spunte e lettura

| Campo | Valore |
|-------|--------|
| **Spec ID** | `MSG-READ` |
| **Layer** | capability |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-03 |
| **ADR** | [server-as-reception.md](../../decisions/server-as-reception.md), [no-internal-external-chat-distinction.md](../../decisions/no-internal-external-chat-distinction.md) |
| **PR** | #122 (delivered), #130 (peer-based `mark_peer_read`) |
| **Correlata** | [MSG-SEND](./MSG-SEND.spec.md), [MSG-INBOX](./MSG-INBOX.spec.md) |

Documento per AI — contratto spunte (delivery status) e lettura messaggi su `main`.

---

## 1. Problema / obiettivo

Il mittente deve vedere lo stato di recapito e lettura dei propri messaggi (✓ / ✓✓ / ✓✓ blu). Il destinatario, aprendo la chat, segna come letti i messaggi ricevuti. La semantica è **cloud-first**: «consegnato» = nella fonte di verità server, non «arrivato sul device del peer».

---

## 2. Requisiti

### MUST

- Tre livelli UI per messaggi **in uscita** (mittente):

| Livello | `delivery_status` | UI |
|---------|-------------------|-----|
| Inviato | `sent` | ✓ grigia (`Icons.done`) |
| Consegnato | `delivered` | ✓✓ grigie (`Icons.done_all`) |
| Lettura | `read` | ✓✓ blu (`Icons.done_all`, `AlfredColors.accentBlue`) |

- Stati aggiuntivi client-only / transitori: `pending` (ottimistico / coda), `failed` (retry).
- **Consegnato (internal)**: trigger `on_message_inserted` promuove `sent` → `delivered` nella stessa transazione di insert — messaggio in fonte di verità piattaforma.
- **Federato** (`protocol` xmpp/matrix): insert con `pending` + riga `outbox`; `delivered` solo dopo ack bridge (futuro).
- **Lettura**: RPC `mark_peer_read(peer_profile_id)` invocata dal **destinatario** all’apertura chat (`MessagesController._init` dopo `load()`).
- `mark_peer_read` aggiorna `delivery_status = 'read'` su messaggi `sender_id = peer` AND `recipient_profile_id = io` con status in (`sent`, `delivered`).
- `mark_peer_read` inserisce righe in `message_read_receipts` (idempotente, `on conflict do nothing`).
- Messaggi inclusi in lettura: body non vuoto **oppure** `content_type` in (`gif`, `voice`, `location`). Esclusi `marker_type` non null.
- Mittente vede aggiornamento `read` via Realtime UPDATE su canale `messages-peer-{me}-{peer}`.
- `list_inbox()` calcola `unread_count` escludendo messaggi con `delivery_status = 'read'` (lato destinatario).

### SHOULD

- `mark_peer_read` all’apertura chat, non al solo tap riga inbox senza aprire pannello messaggi.
- Checkmarks solo su bolle `isMine`; messaggi in entrata senza spunte.

### MUST NOT

- `delivered` basato su evento Realtime del client destinatario (deve essere pipeline server / trigger / bridge).
- Confondere «consegnato» con «aperto sul telefono del destinatario» (semantica WhatsApp P2P).
- Due pipeline spunte distinte per chat interna vs federata ([no-internal-external-chat-distinction](../../decisions/no-internal-external-chat-distinction.md)).

---

## 3. Fuori scope

- Bridge consumer che promuove `delivered`/`read` da XEP-0184 / XEP-0333 (schema pronto, bridge stub).
- Marker messaggio (`marker_type` / `marker_for`) in UI Alpha.
- Notifiche push «letto» su device offline.
- Modello caselle con segnali su `logical_message_id` (target mailbox).

---

## 4. Contratto

### 4.1 Backend

| Elemento | Comportamento |
|----------|---------------|
| Colonna `messages.delivery_status` | Enum `message_delivery_status`: `pending`, `sent`, `delivered`, `read`, `failed` |
| `on_message_inserted` | `internal` → `delivered`; `xmpp`/`matrix` → `pending` + `outbox` |
| `mark_peer_read(uuid)` | Vedi [contracts/rpc.md](../contracts/rpc.md) |
| `message_read_receipts` | Audit lettura per messaggio + profilo lettore |

Migrazioni chiave: `20260626100000_internal_delivered_on_server.sql`, `20260627230000_messages_only_inbox.sql`, aggiornamenti voice/location su `mark_peer_read`.

### 4.2 Client

| Componente | Responsabilità |
|------------|----------------|
| `MessagesController._init` | `load()` → `inboxService.markRead(peerProfileId)` |
| `InboxService.markRead` | RPC `mark_peer_read` |
| `MessageService.subscribeToPeerMessages` | Realtime INSERT/UPDATE → merge `delivery_status` |
| `ChatMessage` / `messageStatusFromDelivery` | Mapping `delivery_status` → `MessageStatus` |
| `MessageBubble` / `_Checkmarks` | Rendering ✓ / ✓✓ / ✓✓ blu / failed / pending |

### 4.3 Flusso internal (Alpha)

```
Mittente: send_message_to_profile → row delivery_status=sent
       → trigger → delivered (stessa transazione)
       → UI mittente ✓✓ grigie (via risposta RPC o realtime)

Destinatario: apre chat → mark_peer_read(peer)
       → row delivery_status=read
       → realtime UPDATE → mittente vede ✓✓ blu
```

---

## 5. Verifica

| Tipo | Riferimento |
|------|-------------|
| Gate | `cd client && bash scripts/verify.sh` |
| Smoke DB | `supabase/tests/schema_smoke.sql` — `mark_peer_read(uuid)` presente |
| Unit | `message_bubble_test.dart` — checkmarks delivered/read |
| Integrazione | `bash scripts/test.sh integration` |

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [server-as-reception.md](../../decisions/server-as-reception.md) | ADR semantica cloud |
| [alpha-full-stack.md](../../architecture/alpha-full-stack.md) §2.9 | Panoramica |
| [MSG-SEND](./MSG-SEND.spec.md) | Invio e stato `sent` |

**Codice**: `client/lib/providers/messages_controller.dart`, `services/inbox_service.dart`, `widgets/message_bubble.dart`, `models/message.dart`
