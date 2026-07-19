# PROM-OUTBOUND-SEND — Coda invio e merge optimistic

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-OUTBOUND-SEND` |
| **Classe** | PRODUCT |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-19 |
| **PR origine** | #159 |

Promessa di prodotto: messaggi in uscita accodati client-side con UI optimistic fino ad ACK server; merge per `client_message_id`.

Pipeline RPC `send_message_to_profile`: [SYS-MAILBOX](../system/SYS-MAILBOX.md) e [contracts/rpc.md](../../contracts/rpc.md).

---

## 1. Problema / obiettivo

L'utente vede il proprio messaggio subito in chat (stato pending) mentre il client gestisce retry e deduplica. All'arrivo della risposta server, la bolla optimistic si fonde con la riga persistita senza duplicati.

---

## 2. Promesse

### MUST

| ID | Promessa |
|----|----------|
| **PROM-OUTBOUND-SEND-001** | Coda client per messaggi in uscita con retry |
| **PROM-OUTBOUND-SEND-002** | Chiave coda: `userId\|peerProfileId` — scoped per account e peer |
| **PROM-OUTBOUND-SEND-003** | Merge optimistic su `client_message_id` — una sola bolla per id client |
| **PROM-OUTBOUND-SEND-004** | UI mittente: stato «in invio» fino a risposta server |
| **PROM-OUTBOUND-SEND-005** | Bolle mittente identificate dall'account in focus corrente |
| **PROM-OUTBOUND-SEND-006** | Multi-account: coda e controller scoped alla sessione in focus — [PROM-MULTI-ACCOUNT](./PROM-MULTI-ACCOUNT.md) |

### MUST NOT

| ID | Promessa |
|----|----------|
| **PROM-OUTBOUND-SEND-010** | Duplicare bolle optimistic e server per lo stesso `client_message_id` |
| **PROM-OUTBOUND-SEND-011** | Coda globale condivisa tra account senza scope `userId` |

---


## 3. Modello (riferimento)

| Elemento | Artefatto |
|----------|-----------|
| Glossario / comandi | [docs/domain/messaging/](../../../domain/messaging/) |
| UML | [docs/model/uml/messaging/messaging-state.puml](../../model/uml/messaging/messaging-state.puml) |
| Statechart client | [client/lib/machines/messaging/](../../../client/lib/machines/messaging/) |
| Invio contenuto | `SendContent` → `ContentSent` / `ContentSendFailed` |

**Implementazione (non vincolante):** [docs/domain/messaging/README.md](../../../domain/messaging/README.md) · RPC: [contracts/rpc.md](../../contracts/rpc.md)


## 4. Superfici conformi

| Superficie | Stato | File |
|------------|-------|------|
| Chat 1:1 | `implemented` | `messages_controller.dart`, `chat_panel.dart` |
| Chat gruppo | `implemented` | `group_messages_controller.dart` |

---

## 5. Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| PROM-OUTBOUND-SEND-001–004 | `messages_controller_multi_account_test.dart`, `multi_account_scope_test.dart` |
| PROM-OUTBOUND-SEND-003 | `mailbox_idempotency_smoke.sql` — dedup `(owner_id, client_message_id)` |
| PROM-OUTBOUND-SEND-006 | `multi_account_scope_test.dart` |
| PROM-OUTBOUND-SEND | `bash scripts/test.sh integration` |


Gate: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh`

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [registry.md](../../registry.md) | Indice promesse |
| [SYS-MAILBOX](../system/SYS-MAILBOX.md) | Pipeline invio server |
| [PROM-MESSAGE-STATUS](./PROM-MESSAGE-STATUS.md) | Spunte post-ACK |
| [PROM-MULTI-ACCOUNT](./PROM-MULTI-ACCOUNT.md) | Scope per focus |
