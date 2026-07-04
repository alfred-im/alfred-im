# MAILBOX-CORE — Archivio per owner e identificatori

| Campo | Valore |
|-------|--------|
| **Spec ID** | `MAILBOX-CORE` |
| **Layer** | capability |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-04 |
| **ADR** | [mailbox-inbox-outbox-spec.md](../../architecture/mailbox-inbox-outbox-spec.md), [server-as-reception.md](../../decisions/server-as-reception.md), [no-internal-external-chat-distinction.md](../../decisions/no-internal-external-chat-distinction.md) |
| **PR** | #159 |
| **Supersedes** | — |
| **Superseded by** | — |

Documento per AI — contratto fondazione modello caselle: archivio per owner, identificatori, RLS, migrazione greenfield prototipo.

**Discovery**: 2026-07-04 — prototipo (non produzione); wipe DB dev; `messages` drop e ricrea stesso nome.

---

## 1. Problema / obiettivo

Ogni utente ha un **archivio messaggi indipendente** (analogia casella email). Non esiste riga condivisa tra mittente e destinatario. L’inbox non è un’entità: è aggregazione on-read sull’archivio dell’owner.

---

## 2. Requisiti

### MUST

| ID | Requisito |
|----|-----------|
| **MAILBOX-CORE-REQ-001** | Tabella `messages` ricreata con `owner_id` (archivio) e `author_id` (autore originale del contenuto) — [contracts/schema.md](../contracts/schema.md) § target mailbox |
| **MAILBOX-CORE-REQ-002** | Nessuna riga visibile a due owner: mittente e destinatario hanno **sempre** `id` riga distinti |
| **MAILBOX-CORE-REQ-003** | `logical_message_id` (λ) UUID generato server alla accettazione invio; correlazione copie e segnali spunta |
| **MAILBOX-CORE-REQ-004** | `client_message_id` solo sulla copia mittente (`owner_id = author_id = mittente`); dedup UNIQUE `(owner_id, client_message_id)` WHERE `client_message_id IS NOT NULL` |
| **MAILBOX-CORE-REQ-005** | Dedup materializzazione destinatario: UNIQUE `(owner_id, logical_message_id)` |
| **MAILBOX-CORE-REQ-006** | RLS: SELECT/INSERT/UPDATE solo `owner_id = auth.uid()` — **nessuna eccezione** |
| **MAILBOX-CORE-REQ-007** | Chat client = `(io, indirizzo peer)` — `username` interno; nessun `thread_id` esposto |
| **MAILBOX-CORE-REQ-008** | Colonna `peer_profile_id` denormalizzata per raggruppamento inbox/storico (internal) |
| **MAILBOX-CORE-REQ-009** | Migrazione prototipo: drop modello message-centric + wipe dati test; ricrea schema mailbox; pulizia blob `chat-media` **non referenziati** post-migrazione |
| **MAILBOX-CORE-REQ-010** | Media: stesso `media_url` su copia mittente e destinatario; un upload, nessuna duplicazione blob |

### SHOULD

| ID | Requisito |
|----|-----------|
| **MAILBOX-CORE-REQ-011** | Indici `(owner_id, peer_profile_id, created_at DESC)` e `(owner_id, logical_message_id)` |
| **MAILBOX-CORE-REQ-012** | `peer_external_address` nullable per federazione futura (non usata in v1 UI) |

### MUST NOT

| ID | Requisito |
|----|-----------|
| **MAILBOX-CORE-REQ-013** | Tabella `inbox_threads`, cache inbox, `thread_id` client |
| **MAILBOX-CORE-REQ-014** | Colonna `direction` — in/out da `author_id` vs `owner_id` |
| **MAILBOX-CORE-REQ-015** | Tabella `message_read_receipts` (sostituita da date su `messages`) |
| **MAILBOX-CORE-REQ-016** | RLS che permette lettura archivio altrui |
| **MAILBOX-CORE-REQ-017** | Doppia scrittura message-centric + mailbox |

---

## 3. Fuori scope

- Delete chat / messaggio singolo
- Gruppi (MUC)
- GC refcount continuo (solo purge orfani a migrazione + policy futura)
- Preservazione dati produzione (prototipo dev only)
- Bridge consumer (fase B post-mailbox)

---

## 4. Contratto

### 4.1 Identificatori

| Id | Scope | Ruolo |
|----|-------|-------|
| `id` | Per owner | PK riga archivio locale |
| `client_message_id` | Copia mittente | Idempotenza invio client |
| `logical_message_id` | Piattaforma | Correlazione copie + spunte |
| `external_id` | Federato futuro | Bridge (fase B) |

### 4.2 Date spunta (v1)

Niente enum `delivery_status` su `messages` target.

| Copia | Campi | Semantica |
|-------|-------|-----------|
| Mittente (uscita) | `delivered_at`, `read_at` | null = non ancora; valorizzate da pipeline / segnali |
| Destinatario (entrata) | `read_at` | Lettura locale; alimenta `mark_peer_read` |

Regola: se `read_at` valorizzata su copia mittente, `delivered_at` tardivo non la azzera.

### 4.3 Migrazione

1. Drop trigger/funzioni/RPC message-centric obsolete
2. Drop `message_read_receipts`, ricrea `messages`, aggiorna `outbox`
3. Wipe righe test
4. Job/script: delete oggetti `chat-media` senza riferimento in `messages.media_url`

---

## 5. Tracciabilità

| REQ-ID | Verifica |
|--------|----------|
| MAILBOX-CORE-REQ-001, REQ-002 | `supabase/tests/mailbox_schema_smoke.sql` |
| MAILBOX-CORE-REQ-004, REQ-005 | `supabase/tests/mailbox_idempotency_smoke.sql` |
| MAILBOX-CORE-REQ-006 | stesso schema smoke — policy RLS |
| MAILBOX-CORE-REQ-009 | migrazione `supabase/migrations/*mailbox*` |
| MAILBOX-CORE-REQ-013, REQ-015 | schema smoke — assenza oggetti legacy |
| MAILBOX-CORE-REQ-010 | `mailbox_send_media_smoke.sql` |

Gate implementazione: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh`

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [mailbox-inbox-outbox-spec.md](../../architecture/mailbox-inbox-outbox-spec.md) | Principi architetturali |
| [MAILBOX-SEND](./MAILBOX-SEND.spec.md) | Pipeline invio/outbox |
| [MAILBOX-INBOX](./MAILBOX-INBOX.spec.md) | Aggregazione inbox |
| [MAILBOX-READ](./MAILBOX-READ.spec.md) | Date spunta |

**Codice target**: `supabase/migrations/`, `docs/specs/contracts/schema.md` § mailbox
