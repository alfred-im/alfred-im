# PROM-REALTIME-ARCHIVE — Realtime scoped all'archivio titolare

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-REALTIME-ARCHIVE` |
| **Classe** | PRODUCT |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-27 |
| **PR origine** | #159, #179 |

Promessa di prodotto: subscribe Realtime Postgres su `messages` filtrato per `archive_user_id = io` — inbox, chat per peer e aggiornamento spunte mittente.

---

## 1. Problema / obiettivo

L'utente riceve aggiornamenti live solo sul **proprio** archivio messaggi. Inbox e chat si aggiornano senza polling; il mittente vede ✓✓ blu quando il destinatario legge, via UPDATE sulla propria copia in uscita.

Multi-account: realtime solo sull'account in focus — [PROM-MULTI-ACCOUNT](./PROM-MULTI-ACCOUNT.md).

---

## 2. Promesse

### MUST — inbox

| ID | Promessa |
|----|----------|
| **PROM-REALTIME-ARCHIVE-001** | Realtime inbox: subscribe Postgres su `messages` filtro `archive_user_id = io` → `InboxController.load()` |
| **PROM-REALTIME-ARCHIVE-002** | Nessun subscribe su righe dove l'utente non è `archive_user_id` |

### MUST — chat per peer

| ID | Promessa |
|----|----------|
| **PROM-REALTIME-ARCHIVE-003** | Realtime chat: stessa tabella `messages`; filtro `archive_user_id = io` AND `peer_profile_id` (canale per peer o filtro client) |
| **PROM-REALTIME-ARCHIVE-004** | `MessageService.subscribeToPeerMessages` — non più modello sender/recipient condiviso |

### MUST — spunte mittente

| ID | Promessa |
|----|----------|
| **PROM-REALTIME-ARCHIVE-005** | Mittente: aggiornamento `read_at` via Realtime UPDATE su proprie righe (`archive_user_id = io`) |
| **PROM-REALTIME-ARCHIVE-006** | `delivered_at` **non** valorizzato da Realtime client destinatario — solo da pipeline server ([PROM-MESSAGE-STATUS](./PROM-MESSAGE-STATUS.md)) |

### MUST — multi-account

| ID | Promessa |
|----|----------|
| **PROM-REALTIME-ARCHIVE-007** | Inbox/realtime solo account in focus; al `setFocus`: swap canali senza dispose stato view per account |

### MUST NOT

| ID | Promessa |
|----|----------|
| **PROM-REALTIME-ARCHIVE-010** | Realtime inbox per account non in focus (trade-off single-active GoTrue) |
| **PROM-REALTIME-ARCHIVE-011** | Subscribe globale senza filtro `archive_user_id` |

---


## 3. Modello (riferimento)

| Elemento | Artefatto |
|----------|-----------|
| Glossario / comandi | [docs/domain/messaging/](../../../domain/messaging/), [docs/domain/multi-account/](../../../domain/multi-account/) |
| UML | [docs/model/uml/messaging/](../../../model/uml/messaging/) |
| Statechart client | [client/lib/machines/messaging/](../../../../client/lib/machines/messaging/) |
| Eventi realtime | `RealtimeReceived` → `ConversationUpdated` (statechart messaging); spunte mittente via UPDATE `read_at` |

**Implementazione (non vincolante):** [docs/domain/messaging/README.md](../../../domain/messaging/README.md)


## 4. Superfici conformi

| Superficie | Stato | File |
|------------|-------|------|
| SURF-INBOX | `implemented` | [SURF-INBOX.md](../../surfaces/SURF-INBOX.md) |
| Chat 1:1 | `implemented` | `inbox_service.dart`, `message_service.dart` |
| Chat gruppo | `implemented` | [PROM-GROUP-AUTHOR-DISPLAY](./PROM-GROUP-AUTHOR-DISPLAY.md) |

---

## 5. Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| PROM-REALTIME-ARCHIVE-001 | `inbox_provider_listen_test.dart`, `inbox_realtime_archive_filter_test.dart` |
| PROM-REALTIME-ARCHIVE-003, 004 | `inbox_realtime_archive_filter_test.dart` |
| PROM-REALTIME-ARCHIVE-005 | `messages_controller_multi_account_test.dart` |
| PROM-REALTIME-ARCHIVE-007 | `inbox_provider_lifecycle_test.dart`; `multi_account_chat_scenario_test.dart` |
| PROM-REALTIME-ARCHIVE-001–007 | `bash scripts/test.sh integration` + `e2e` |


Gate: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh`

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [registry.md](../../registry.md) | Indice promesse |
| [SYS-MAILBOX](../system/SYS-MAILBOX.md) | Aggregazione inbox, `mark_peer_read` |
| [PROM-MULTI-ACCOUNT](./PROM-MULTI-ACCOUNT.md) | Scope focus |
| [PROM-MESSAGE-STATUS](./PROM-MESSAGE-STATUS.md) | Spunte da date |
