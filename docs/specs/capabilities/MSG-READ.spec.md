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

Il mittente vede lo stato di recapito e lettura (✓ / ✓✓ / ✓✓ blu). Il destinatario, aprendo la chat, segna come letti i messaggi ricevuti. Semantica **cloud-first**: «consegnato» = nella fonte di verità server.

---

## 2. Requisiti

### MUST

| ID | Requisito |
|----|-----------|
| **MSG-READ-REQ-001** | UI mittente: `sent` → ✓ grigia; `delivered` → ✓✓ grigie; `read` → ✓✓ blu |
| **MSG-READ-REQ-002** | Stati transitori client: `pending` (ottimistico/coda), `failed` (retry) |
| **MSG-READ-REQ-003** | Internal: trigger `on_message_inserted` promuove `sent` → `delivered` nella stessa transazione insert |
| **MSG-READ-REQ-004** | Federato: insert `pending` + `outbox`; `delivered` dopo bridge (futuro) |
| **MSG-READ-REQ-005** | Destinatario: `mark_peer_read(peer_profile_id)` in `MessagesController._init` dopo `load()` |
| **MSG-READ-REQ-006** | `mark_peer_read` imposta `delivery_status = 'read'` su messaggi ricevuti da quel peer (`sent`/`delivered`) |
| **MSG-READ-REQ-007** | `mark_peer_read` inserisce `message_read_receipts` (idempotente) |
| **MSG-READ-REQ-008** | Lettura include body non vuoto **oppure** `content_type` ∈ `gif`, `voice`, `location`; esclude `marker_type` non null |
| **MSG-READ-REQ-009** | Mittente: aggiornamento `read` via Realtime UPDATE su canale peer |
| **MSG-READ-REQ-010** | `list_inbox()` esclude da `unread_count` messaggi con `delivery_status = 'read'` |

### SHOULD

| ID | Requisito |
|----|-----------|
| **MSG-READ-REQ-011** | `mark_peer_read` solo all’apertura chat (non al solo tap riga inbox) |
| **MSG-READ-REQ-012** | Checkmarks solo su bolle `isMine` |

### MUST NOT

| ID | Requisito |
|----|-----------|
| **MSG-READ-REQ-013** | `delivered` basato su Realtime del client destinatario (solo pipeline server/trigger/bridge) |
| **MSG-READ-REQ-014** | Semantica «consegnato» = «aperto sul device del peer» (P2P WhatsApp) |
| **MSG-READ-REQ-015** | Pipeline spunte distinte internal vs federato |

---

## 3. Fuori scope

- Bridge consumer XEP-0184 / XEP-0333 (schema pronto).
- Marker `marker_type` in UI Alpha.
- Modello caselle / `logical_message_id` (target mailbox).

---

## 4. Contratto

### 4.1 Backend

Vedi [contracts/schema.md](../contracts/schema.md) § `messages`, `message_read_receipts`; [contracts/rpc.md](../contracts/rpc.md) § `mark_peer_read`.

### 4.2 Client

| Componente | Responsabilità |
|------------|----------------|
| `MessagesController._init` | `load()` → `inboxService.markRead(peerProfileId)` |
| `InboxService.markRead` | RPC `mark_peer_read` |
| `messageStatusFromDelivery` | `delivery_status` → `MessageStatus` |
| `MessageBubble` / `_Checkmarks` | Rendering spunte |

### 4.3 Flusso internal

```
Invio → sent → trigger → delivered → (peer apre chat) mark_peer_read → read → realtime mittente
```

---

## 5. Tracciabilità

| REQ-ID | Verifica |
|--------|----------|
| MSG-READ-REQ-001 | `message_bubble_test.dart` — ✓, ✓✓ grigie, ✓✓ blu |
| MSG-READ-REQ-002 | `models_and_utils_test.dart` — `MessageStatus` da `delivery_status` |
| MSG-READ-REQ-003 | `20260626100000_internal_delivered_on_server.sql`; migrazione `on_message_inserted` in `20260627230000` |
| MSG-READ-REQ-005 | `messages_controller.dart` `_init`; `FakeInboxService.markReadCalls` in test |
| MSG-READ-REQ-006, REQ-007 | `20260702120100_message_location_support.sql` — corpo `mark_peer_read` |
| MSG-READ-REQ-008 | stessa migrazione — filtro `content_type` / `marker_type` |
| MSG-READ-REQ-009 | `messages_controller_multi_account_test.dart` — merge realtime |
| MSG-READ-REQ-010 | `list_inbox()` in `20260628100000` / location migration — `unread_count` |
| MSG-READ-REQ-011 | `MessagesController._init` ordine load → markRead |
| MSG-READ-REQ-012 | `message_bubble_test.dart` — checkmarks su messaggio outgoing |
| MSG-READ-REQ-013 | ADR [server-as-reception.md](../../decisions/server-as-reception.md); trigger server-side |
| MSG-READ-REQ-015 | ADR [no-internal-external-chat-distinction.md](../../decisions/no-internal-external-chat-distinction.md) |
| MSG-READ-REQ-001 (RPC) | `schema_smoke.sql` — `mark_peer_read(uuid)` presente |

Gate: `cd client && bash scripts/verify.sh` · Integrazione: `bash scripts/test.sh integration`

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [server-as-reception.md](../../decisions/server-as-reception.md) | ADR semantica cloud |
| [MSG-SEND](./MSG-SEND.spec.md) | Stato `sent` post-invio |

**Codice**: `messages_controller.dart`, `inbox_service.dart`, `message_bubble.dart`, `message.dart`
