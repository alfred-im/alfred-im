# MAILBOX-SEND — Invio e outbox sempre

| Campo | Valore |
|-------|--------|
| **Spec ID** | `MAILBOX-SEND` |
| **Layer** | capability |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-04 |
| **ADR** | [mailbox-inbox-outbox-spec.md](../../architecture/mailbox-inbox-outbox-spec.md), [bridge-stateless.md](../../decisions/bridge-stateless.md) |
| **PR** | #159 |
| **Supersedes** | [MSG-SEND.spec.md](./MSG-SEND.spec.md) (al merge) |
| **Superseded by** | — |

Documento per AI — invio unificato: copia mittente, outbox sempre (anche internal), driver sincrono in transazione RPC.

---

## 1. Problema / obiettivo

L’utente invia a un account Alfred (`peer_profile_id`). Il server crea la copia nel **proprio** archivio, accoda outbox, materializza la copia destinatario e valorizza `delivered_at` sul mittente — **nella stessa transazione RPC** per internal.

---

## 2. Requisiti

### MUST

| ID | Requisito |
|----|-----------|
| **MAILBOX-SEND-REQ-001** | Unico RPC invio: `send_message_to_profile` — firma invariata PostgREST — [contracts/rpc.md](../contracts/rpc.md) § mailbox |
| **MAILBOX-SEND-REQ-002** | Accettazione: INSERT copia mittente (`owner_id = author_id = auth.uid()`), `delivered_at`/`read_at` null, λ assegnato |
| **MAILBOX-SEND-REQ-003** | **Outbox sempre**: INSERT `outbox` per ogni invio, incluso `protocol = internal` |
| **MAILBOX-SEND-REQ-004** | Driver internal (stessa transazione RPC): materializza copia destinatario + valorizza `delivered_at` su copia mittente (match λ) |
| **MAILBOX-SEND-REQ-005** | Idempotenza: retry stesso `(owner_id, client_message_id)` → stessa riga mittente, no duplicati |
| **MAILBOX-SEND-REQ-006** | Tipi `content_type`: `text`, `gif`, `voice`, `location` — validazione invariata da MSG-SEND |
| **MAILBOX-SEND-REQ-007** | Upload media prima RPC: bucket `chat-media` `{auth.uid()}/{uuid}.*` |
| **MAILBOX-SEND-REQ-008** | Coda client `OutboundMessageQueue` + merge optimistic su `client_message_id` |
| **MAILBOX-SEND-REQ-009** | Outbox retry: `attempts`, `last_error`, `status` → `failed` dopo soglia (default 5 tentativi worker/cron futuro; internal sincrono non fallisce salvo errore transazione) |
| **MAILBOX-SEND-REQ-010** | Invio fallito server: `failed_at` timestamptz sulla copia mittente (opzionale null se non applicabile) |

### SHOULD

| ID | Requisito |
|----|-----------|
| **MAILBOX-SEND-REQ-011** | Payload outbox include λ, destinatario, snapshot contenuto, `media_url` |
| **MAILBOX-SEND-REQ-012** | Preview inbox coerente per tipo (funzioni `format_*_preview`) |

### MUST NOT

| ID | Requisito |
|----|-----------|
| **MAILBOX-SEND-REQ-013** | Shortcut trigger `sent → delivered` senza outbox e senza copia destinatario |
| **MAILBOX-SEND-REQ-014** | Invio a sé stessi |
| **MAILBOX-SEND-REQ-015** | Indirizzo esterno `user@server` senza errore utente (v1: **unsupported** in compose) |
| **MAILBOX-SEND-REQ-016** | Overload ambigui `send_message_to_profile` PostgREST |
| **MAILBOX-SEND-REQ-017** | Pipeline invio distinta per internal vs federato (solo driver recapito differisce in fase B) |

---

## 3. Fuori scope

- Consumer bridge Python (fase B)
- Signed URL media
- Eliminazione messaggi

---

## 4. Contratto

### 4.1 Flusso internal (transazione RPC)

```
send_message_to_profile
  → INSERT messages (owner=mittente, author=mittente, λ, peer=dest)
  → INSERT outbox (protocol=internal, payload con λ)
  → INSERT messages (owner=destinatario, author=mittente, stesso λ, stesso contenuto/media_url)
  → UPDATE messages SET delivered_at=now() WHERE owner=mittente AND λ
  → RETURN riga mittente
```

### 4.2 Client

| Componente | Responsabilità |
|------------|----------------|
| `MessageService.send*` | RPC invariato |
| `OutboundMessageQueue` | Retry; chiave `userId\|peerProfileId` |
| `MessagesController` | Optimistic `pending` client-side fino a risposta server |
| `ChatMessage` | `isMine` da `author_id == currentUserId` |

### 4.3 Stati UI mittente (da date)

| `delivered_at` | `read_at` | UI |
|----------------|-----------|-----|
| null | null | ✓ (inviato / in consegna) |
| set | null | ✓✓ grigie |
| set | set | ✓✓ blu |

`pending` / `failed` restano **solo client** fino ad ACK server o `failed_at`.

---

## 5. Tracciabilità

| REQ-ID | Verifica |
|--------|----------|
| MAILBOX-SEND-REQ-001 | `schema_smoke.sql` + `mailbox_send_smoke.sql` |
| MAILBOX-SEND-REQ-003, REQ-004 | `mailbox_delivery_smoke.sql` |
| MAILBOX-SEND-REQ-005 | `mailbox_idempotency_smoke.sql` |
| MAILBOX-SEND-REQ-006 | `mailbox_send_media_smoke.sql` |
| MAILBOX-SEND-REQ-008 | `messages_controller_multi_account_test.dart`, `multi_account_scope_test.dart` |
| MAILBOX-SEND-REQ-013 | assenza trigger `on_message_inserted` legacy internal delivered |
| MAILBOX-SEND-REQ-015 | `ComposeService` → errore esterno |
| MAILBOX-SEND-REQ-001–008 | `bash scripts/test.sh integration` |

Gate: `verify.sh` + `integration` + `e2e-multi`

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [MSG-SEND](./MSG-SEND.spec.md) | Baseline tipi media (fino a merge) |
| [MAILBOX-CORE](./MAILBOX-CORE.spec.md) | Schema e λ |
| [MAILBOX-READ](./MAILBOX-READ.spec.md) | `read_at` |

**Codice target**: `supabase/migrations/`, `message_service.dart`, `outbound_message_queue.dart`
