# SYS-DELIVERY — Piano recapito (outbox + worker)

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `SYS-DELIVERY` |
| **Classe** | SYSTEM |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-08-08 |
| **ADR** | [bridge-stateless.md](../../../decisions/bridge-stateless.md), [server-as-reception.md](../../../decisions/server-as-reception.md) |
| **PR origine** | #179 |

Promessa SYSTEM — infrastruttura **non-account** che attraversa i confini [SYS-ACCOUNT-BOUNDARY](./SYS-ACCOUNT-BOUNDARY.md): bus `outbox`, worker `alfred_delivery.*`, stesso contratto per internal oggi e federazione domani.

**Dettaglio canonico**: [contracts/schema.md](../../contracts/schema.md) § outbox · [contracts/rpc.md](../../contracts/rpc.md)

---

## 1. Problema / obiettivo

Gli account accettano invio/lettura solo nel proprio archivio e accodano eventi su `outbox`. Il worker delivery materializza copie destinatario, aggiorna `delivered_at`/`read_at` sul mittente, eroga messaggi gruppo — senza sessione GoTrue di nessun utente.

---

## 2. Promesse

### OUTBOX — bus eventi

#### MUST

| ID | Promessa |
|----|----------|
| **SYS-DELIVERY-001** | Ogni invio account accoda `outbox` con `protocol = internal`, `status = queued`, payload con `event_kind` |
| **SYS-DELIVERY-002** | `event_kind = deliver` — recapito messaggio (1:1 o verso gruppo) |
| **SYS-DELIVERY-003** | `event_kind = read_receipt` — propagazione `read_at` verso copia mittente |
| **SYS-DELIVERY-004** | `event_kind = group_erogate` — distribuzione proxy da archivio gruppo |
| **SYS-DELIVERY-004b** | `event_kind = reaction_fact` — persistenza append-only su `message_reaction_facts` (worker; RPC account solo accoda) |
| **SYS-DELIVERY-005** | Payload `deliver` include λ, `sender_id`, `recipient_profile_id`, snapshot contenuto |
| **SYS-DELIVERY-006** | Payload `read_receipt` include id logico messaggio, `read_receipt_id`, `reader_id`, `sender_profile_id` |
| **SYS-DELIVERY-007** | RLS `outbox`: deny `authenticated` (solo worker/service) |
| **SYS-DELIVERY-008** | `event_kind = push_notify` — invio notifica Web Push post-recapito ([SYS-PUSH](./SYS-PUSH.md), `implemented`) |
| **SYS-DELIVERY-009** | Payload `push_notify` include `recipient_user_id`, `peer_profile_id`, `peer_display_name`, `preview_text`, `logical_message_id`, `content_type` |

### WORKER — `alfred_delivery`

#### MUST

| ID | Promessa |
|----|----------|
| **SYS-DELIVERY-010** | Schema `alfred_delivery`; funzioni `SECURITY DEFINER`, **nessun** `GRANT` a `authenticated` |
| **SYS-DELIVERY-011** | `process_outbox(outbox_id)` — dispatcher per `event_kind`; internal sincrono nella stessa transazione RPC account |
| **SYS-DELIVERY-012** | `deliver_internal`: valuta [SYS-RECEPTION](./SYS-RECEPTION.md); se consentito → INSERT copia destinatario (o archivio gruppo) + UPDATE `delivered_at` mittente; altrimenti skip silenzioso |
| **SYS-DELIVERY-013** | Destinatario gruppo: gate bidirezionale; INSERT archivio gruppo; `erogate_group_message` verso allow list |
| **SYS-DELIVERY-014** | `propagate_read_receipt`: UPDATE copia mittente `read_at` + `read_receipt_id` (stesso id della copia lettore) WHERE `archive_user_id = sender_profile_id` AND id logico messaggio |
| **SYS-DELIVERY-014b** | `process_reaction_fact`: INSERT su `message_reaction_facts`; payload include λ, `reactor_id`, `kind`, `emoji` (se `applied`); outbox completata con `reaction_fact_id` |
| **SYS-DELIVERY-015** | `group_erogate`: per ogni partecipante allow list con gate → INSERT riga erogata (stesso λ) |
| **SYS-DELIVERY-016** | Al termine: `outbox.status = completed` (o `failed` con `last_error` su errore transazione) |
| **SYS-DELIVERY-017** | Idempotenza destinatario: `ON CONFLICT (archive_user_id, logical_message_id) DO NOTHING` |
| **SYS-DELIVERY-018** | ✓ singola: copia mittente con `delivered_at` null permanente se gate rifiuta |
| **SYS-DELIVERY-019** | ✓✓ grigie: worker `deliver` valorizza `delivered_at` su copia mittente; `read_at` null |
| **SYS-DELIVERY-020** | ✓✓ blu: lettore aggiorna solo archivio locale; worker `read_receipt` propaga `read_at` alla copia mittente |
| **SYS-DELIVERY-021** | Dopo recapito riuscito (`deliver_internal` / erogazione gruppo): accoda `push_notify` o invoca pipeline [SYS-PUSH](./SYS-PUSH.md) |
| **SYS-DELIVERY-022** | `push_notify` eseguito **solo** se copia destinatario materializzata (stessa condizione di ✓✓ grigie) |
| **SYS-DELIVERY-023** | `process_push_notify`: risolve preview, SELECT subscriptions destinatario, invoca Edge Function `send-push` |

### MUST NOT

| ID | Promessa |
|----|----------|
| **SYS-DELIVERY-026** | RPC account che eseguono INSERT/UPDATE cross-boundary al posto del worker |
| **SYS-DELIVERY-027** | Errore RPC verso mittente su rifiuto allow list (rifiuto silenzioso invariato) |
| **SYS-DELIVERY-028** | Worker con `auth.uid()` come identità operativa |
| **SYS-DELIVERY-029** | `push_notify` su recapito rifiutato da allow list |

### Flussi (internal sincrono)

Flusso delivery canonico: [mailbox-inbox-outbox-spec.md](../../../architecture/mailbox-inbox-outbox-spec.md) § Consegna / Flusso internal

---

## 3. Implementazione contratto

| Elemento | Codice |
|----------|--------|
| Schema + worker | `supabase/migrations/*account_boundary_delivery*` |
| RPC account | `send_message_to_profile`, `mark_peer_read`, `broadcast_message_to_allowlist` |
| Helper gate | `is_sender_allowed_for_reception`, `is_bidirectional_allowed` (solo worker) |
| Push | `supabase/functions/send-push/`, migrazione `push_subscriptions` — [SYS-PUSH](./SYS-PUSH.md) (`implemented`) |

---

## 4. Tracciabilità

| SYS-ID | Verifica |
|--------|----------|
| SYS-DELIVERY-001–012 | `mailbox_delivery_smoke.sql`, `delivery_ticks_smoke.sql` |
| SYS-DELIVERY-003–014 | `mailbox_read_smoke.sql`, `delivery_ticks_smoke.sql` |
| SYS-DELIVERY-004b, 014b | `message_reaction_facts_smoke.sql` |
| SYS-DELIVERY-012 | `reception_allowlist_gate_smoke.sql`, `delivery_ticks_smoke.sql` |
| SYS-DELIVERY-018–020 | `delivery_ticks_smoke.sql`, `bash scripts/test.sh integration-ticks` |
| SYS-DELIVERY-013–015 | `group_delivery_smoke.sql`, `group_broadcast_smoke.sql` |
| SYS-DELIVERY-008–009, 021–023, 029 | `push_delivery_trigger_smoke.sql`, `push_multi_device_smoke.sql` (post SYS-PUSH) |

---

## 5. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [SYS-ACCOUNT-BOUNDARY](./SYS-ACCOUNT-BOUNDARY.md) | Legge madre confine |
| [SYS-MAILBOX](./SYS-MAILBOX.md) | Semantica archivio e date spunta |
| [SYS-RECEPTION](./SYS-RECEPTION.md) | Gate allow list nel worker |
| [SYS-PUSH](./SYS-PUSH.md) | Web Push post-recapito (`implemented`) |
