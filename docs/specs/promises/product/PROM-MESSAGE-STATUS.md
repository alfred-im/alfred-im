# PROM-MESSAGE-STATUS — Spunte da date mailbox

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-MESSAGE-STATUS` |
| **Classe** | PRODUCT |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-08 |
| **PR origine** | #159 |

Promessa di prodotto: spunte mittente (✓ / ✓✓ grigie / ✓✓ blu) derivate da `delivered_at` e `read_at` sulla copia in uscita; stati `pending`/`failed` solo client pre-ACK.

RPC `mark_peer_read`: [SYS-MAILBOX](../system/SYS-MAILBOX.md) e [contracts/rpc.md](../../contracts/rpc.md).

---

## 1. Problema / obiettivo

Il mittente interpreta lo stato del proprio messaggio da date nullable sulla **propria** riga in uscita — non da enum DB né da aggiornamenti sull'archivio altrui. `delivered_at` null **permanente** può indicare blocco allow list ([PROM-RECEPTION-FILTER](./PROM-RECEPTION-FILTER.md)), non errore di invio.

---

## 2. Promesse

### MUST — mapping UI

| ID | Promessa |
|----|----------|
| **PROM-MESSAGE-STATUS-001** | UI mittente: `delivered_at` null → **✓** (accettato server) |
| **PROM-MESSAGE-STATUS-002** | UI mittente: `delivered_at` set e `read_at` null → **✓✓ grigie** (consegnato) |
| **PROM-MESSAGE-STATUS-003** | UI mittente: `read_at` set → **✓✓ blu** (letto) |
| **PROM-MESSAGE-STATUS-004** | Helper `messageStatusFromMailbox` da `delivered_at` / `read_at` / `failed_at` |

### MUST — stati client

| ID | Promessa |
|----|----------|
| **PROM-MESSAGE-STATUS-005** | Stati `pending` / `failed` solo lato mittente **pre-ACK** server — non persistiti come enum DB |
| **PROM-MESSAGE-STATUS-006** | Integrazione con coda optimistic — vedi [PROM-OUTBOUND-SEND](./PROM-OUTBOUND-SEND.md) |

### SHOULD

| ID | Promessa |
|----|----------|
| **PROM-MESSAGE-STATUS-010** | Checkmarks solo bolle `isMine` (`author_id = io`) |

### MUST NOT

| ID | Promessa |
|----|----------|
| **PROM-MESSAGE-STATUS-020** | Regressione spunte: se `read_at` già set, ignorare segnale `delivered_at` tardivo |
| **PROM-MESSAGE-STATUS-021** | Enum `message_delivery_status` su `messages` |
| **PROM-MESSAGE-STATUS-022** | Semantica «consegnato» = device P2P peer |

---

## 4. Contratto implementativo

| Elemento | Responsabilità |
|----------|----------------|
| `messageStatusFromMailbox` | Mapping date → stato UI in `message.dart` |
| `MessageBubble` | Rendering checkmarks da stato |
| `delivered_at` | Valorizzato solo dopo materializzazione copia destinatario ([SYS-MAILBOX](./SYS-MAILBOX.md)) |
| `read_at` | Aggiornato su lettura destinatario + propagazione a copia mittente via λ |

### Tabella stati UI mittente

| `delivered_at` | `read_at` | UI | Significato |
|----------------|-----------|-----|-------------|
| null | null | ✓ | Accettato server; può essere in attesa recapito o blocco allow list permanente |
| set | null | ✓✓ grigie | Consegnato — copia destinatario materializzata |
| set | set | ✓✓ blu | Letto dal destinatario |
| (pre-ACK) | — | pending/failed | Solo client — [PROM-OUTBOUND-SEND](./PROM-OUTBOUND-SEND.md) |

---

## 5. Superfici conformi

| Superficie | Stato | File |
|------------|-------|------|
| Chat 1:1 | `implemented` | `message_bubble.dart` |
| Chat gruppo (erogati) | `implemented` | [PROM-GROUP-TICKS](./PROM-GROUP-TICKS.md) |

---

## 6. Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| PROM-MESSAGE-STATUS-001–004 | `message_bubble_test.dart`, `models_and_utils_test.dart` |
| PROM-MESSAGE-STATUS-005 | `messages_controller_multi_account_test.dart` |
| PROM-MESSAGE-STATUS-010 | `message_bubble_test.dart` |
| PROM-MESSAGE-STATUS-020 | `models_and_utils_test.dart` — read_at prevale su delivered_at tardivo |
| PROM-MESSAGE-STATUS-001–008 | `bash scripts/test.sh integration` + `e2e-multi` |


Gate: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh`

---

## 7. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [registry.md](../../registry.md) | Indice promesse |
| [SYS-MAILBOX](../system/SYS-MAILBOX.md) | Date consegna/lettura, `mark_peer_read` |
| [PROM-RECEPTION-FILTER](./PROM-RECEPTION-FILTER.md) | `delivered_at` null permanente |
| [PROM-REALTIME-OWNER](./PROM-REALTIME-OWNER.md) | Aggiornamento `read_at` via Realtime |
