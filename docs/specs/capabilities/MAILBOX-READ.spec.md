# MAILBOX-READ — Date consegna e lettura

| Campo | Valore |
|-------|--------|
| **Spec ID** | `MAILBOX-READ` |
| **Layer** | capability |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-04 |
| **ADR** | [server-as-reception.md](../../decisions/server-as-reception.md), [mailbox-inbox-outbox-spec.md](../../architecture/mailbox-inbox-outbox-spec.md) |
| **PR** | #159 |
| **Supersedes** | [MSG-READ.spec.md](./MSG-READ.spec.md) (al merge) |
| **Superseded by** | — |

Documento per AI — spunte da **date nullable** su copia mittente; lettura locale su copia destinatario; segnali via λ senza modificare archivio altrui.

---

## 1. Problema / obiettivo

Il mittente vede ✓ / ✓✓ / ✓✓ blu da `delivered_at` e `read_at` sulla **propria** riga in uscita. Il destinatario, aprendo la chat, marca `read_at` sulle righe in entrata nel **proprio** archivio e innesca aggiornamento `read_at` sulla copia mittente (stesso λ).

---

## 2. Requisiti

### MUST

| ID | Requisito |
|----|-----------|
| **MAILBOX-READ-REQ-001** | UI mittente: `delivered_at` null → ✓; `delivered_at` set e `read_at` null → ✓✓ grigie; `read_at` set → ✓✓ blu |
| **MAILBOX-READ-REQ-002** | `delivered_at` valorizzato solo dopo materializzazione copia destinatario (MAILBOX-SEND) — non da Realtime client destinatario |
| **MAILBOX-READ-REQ-003** | `mark_peer_read(peer)` chiamato dal destinatario in `MessagesController._init` dopo `load()` |
| **MAILBOX-READ-REQ-004** | `mark_peer_read`: UPDATE righe in entrata nel mio archivio (`owner_id = io`, `author_id = peer`, `read_at IS NULL`) SET `read_at = now()` |
| **MAILBOX-READ-REQ-005** | Per ogni λ delle righe lette: UPDATE copia mittente SET `read_at = now()` WHERE `owner_id = peer` (mittente) AND `logical_message_id = λ` AND `read_at IS NULL` — SECURITY DEFINER |
| **MAILBOX-READ-REQ-006** | Lettura include body non vuoto OPPURE `content_type` ∈ gif, voice, location |
| **MAILBOX-READ-REQ-007** | Mittente: aggiornamento `read_at` via Realtime UPDATE su proprie righe (`owner_id = io`) |
| **MAILBOX-READ-REQ-008** | `list_inbox` unread: righe in entrata con `read_at IS NULL` |
| **MAILBOX-READ-REQ-009** | Stati client `pending`/`failed` solo lato mittente pre-ACK server — non persistiti come enum DB |

### SHOULD

| ID | Requisito |
|----|-----------|
| **MAILBOX-READ-REQ-010** | `mark_peer_read` solo all’apertura chat, non al tap riga inbox |
| **MAILBOX-READ-REQ-011** | Checkmarks solo bolle `isMine` (author = io) |

### MUST NOT

| ID | Requisito |
|----|-----------|
| **MAILBOX-READ-REQ-012** | UPDATE archivio destinatario per mostrare spunte al mittente |
| **MAILBOX-READ-REQ-013** | Enum `message_delivery_status` su `messages` target |
| **MAILBOX-READ-REQ-014** | Tabella `message_read_receipts` |
| **MAILBOX-READ-REQ-015** | Regressione spunte: se `read_at` già set, ignorare segnale `delivered_at` tardivo |
| **MAILBOX-READ-REQ-016** | Semantica «consegnato» = device P2P peer |

---

## 3. Fuori scope

- Bridge XEP-0184 / XEP-0333 (fase B: stesso meccanismo date su copia mittente)
- Marker `marker_type` legacy

---

## 4. Contratto

### 4.1 RPC `mark_peer_read`

```sql
mark_peer_read(p_peer_profile_id uuid) → void
```

Effetti:
1. UPDATE `messages` SET `read_at = now()` WHERE `owner_id = auth.uid()` AND `peer_profile_id = p_peer` AND `author_id = p_peer` AND `read_at IS NULL` AND contenuto leggibile
2. Per ogni λ toccato: UPDATE copia mittente `read_at` (funzione interna SECURITY DEFINER)

### 4.2 Client

| Componente | Responsabilità |
|------------|----------------|
| `messageStatusFromMailbox` | Helper da `delivered_at`/`read_at`/`failed_at` (implementato in `message.dart`) |
| `messageStatusFromDelivery` | Legacy shim — solo test |
| `MessageBubble` | Checkmarks da date |
| `InboxService.markRead` | RPC invariato |

### 4.3 Flusso

```
Paolo apre chat con Mario
  → mark_peer_read(Mario)
  → read_at su righe Paolo (entrata, author=Mario)
  → read_at su righe Mario (uscita, stesso λ)
  → Realtime su Mario → ✓✓ blu
```

---

## 5. Tracciabilità

| REQ-ID | Verifica |
|--------|----------|
| MAILBOX-READ-REQ-001 | `message_bubble_test.dart`, `models_and_utils_test.dart` |
| MAILBOX-READ-REQ-002 | `mailbox_delivery_smoke.sql` |
| MAILBOX-READ-REQ-003–005 | `mailbox_read_smoke.sql` |
| MAILBOX-READ-REQ-006 | smoke filtri content_type |
| MAILBOX-READ-REQ-007 | `messages_controller_multi_account_test.dart` |
| MAILBOX-READ-REQ-008 | `mailbox_inbox_smoke.sql` unread |
| MAILBOX-READ-REQ-015 | test unit SQL o Dart — read prima di delivered tardivo |
| MAILBOX-READ-REQ-001–008 | `bash scripts/test.sh integration` + `e2e-multi` |

Gate: `verify.sh` + `integration` + `e2e-multi`

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [MSG-READ](./MSG-READ.spec.md) | Baseline fino a merge |
| [MAILBOX-SEND](./MAILBOX-SEND.spec.md) | `delivered_at` |

**Codice target**: migrazioni `mark_peer_read`, `message.dart`, `message_bubble.dart`
