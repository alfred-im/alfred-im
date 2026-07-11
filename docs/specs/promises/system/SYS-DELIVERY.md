# SYS-DELIVERY — Piano recapito (outbox + worker)

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `SYS-DELIVERY` |
| **Classe** | SYSTEM |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-11 |
| **ADR** | [bridge-stateless.md](../../../decisions/bridge-stateless.md), [server-as-reception.md](../../../decisions/server-as-reception.md) |
| **PR origine** | (in corso) |

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
| **SYS-DELIVERY-005** | Payload `deliver` include λ, `sender_id`, `recipient_profile_id`, snapshot contenuto |
| **SYS-DELIVERY-006** | Payload `read_receipt` include λ, `reader_id`, `sender_profile_id` |
| **SYS-DELIVERY-007** | RLS `outbox`: deny `authenticated` (solo worker/service) |

### WORKER — `alfred_delivery`

#### MUST

| ID | Promessa |
|----|----------|
| **SYS-DELIVERY-010** | Schema `alfred_delivery`; funzioni `SECURITY DEFINER`, **nessun** `GRANT` a `authenticated` |
| **SYS-DELIVERY-011** | `process_outbox(outbox_id)` — dispatcher per `event_kind`; internal sincrono nella stessa transazione RPC account |
| **SYS-DELIVERY-012** | `deliver_internal`: valuta [SYS-RECEPTION](./SYS-RECEPTION.md); se consentito → INSERT copia destinatario (o archivio gruppo) + UPDATE `delivered_at` mittente; altrimenti skip silenzioso |
| **SYS-DELIVERY-013** | Destinatario gruppo: gate bidirezionale; INSERT archivio gruppo; `erogate_group_message` verso allow list |
| **SYS-DELIVERY-014** | `propagate_read_receipt`: UPDATE copia mittente `read_at` WHERE `owner_id = sender_profile_id` AND `logical_message_id = λ` |
| **SYS-DELIVERY-015** | `group_erogate`: per ogni partecipante allow list con gate → INSERT riga erogata (stesso λ) |
| **SYS-DELIVERY-016** | Al termine: `outbox.status = completed` (o `failed` con `last_error` su errore transazione) |
| **SYS-DELIVERY-017** | Idempotenza destinatario: `ON CONFLICT (owner_id, logical_message_id) DO NOTHING` |

#### MUST NOT

| ID | Promessa |
|----|----------|
| **SYS-DELIVERY-020** | RPC account che eseguono INSERT/UPDATE cross-boundary al posto del worker |
| **SYS-DELIVERY-021** | Errore RPC verso mittente su rifiuto allow list (rifiuto silenzioso invariato) |
| **SYS-DELIVERY-022** | Worker con `auth.uid()` come identità operativa |

### Flussi (internal sincrono)

```
send_message_to_profile (account mittente)
  → INSERT messages (solo owner=mittente)
  → INSERT outbox (event_kind=deliver, queued)
  → alfred_delivery.process_outbox
       → gate reception (lato destinatario)
       → SE ok: INSERT destinatario/gruppo + delivered_at mittente
       → outbox completed

mark_peer_read (account lettore)
  → UPDATE messages (solo owner=lettore, in entrata)
  → INSERT outbox (event_kind=read_receipt) per ogni λ
  → alfred_delivery.process_outbox
       → UPDATE read_at copia mittente
       → outbox completed
```

---

## 3. Implementazione contratto

| Elemento | Codice |
|----------|--------|
| Schema + worker | `supabase/migrations/*account_boundary_delivery*` |
| RPC account | `send_message_to_profile`, `mark_peer_read`, `broadcast_message_to_allowlist` |
| Helper gate | `is_sender_allowed_for_reception`, `is_bidirectional_allowed` (solo worker) |

---

## 4. Tracciabilità

| SYS-ID | Verifica |
|--------|----------|
| SYS-DELIVERY-001–012 | `mailbox_delivery_smoke.sql` |
| SYS-DELIVERY-003–014 | `mailbox_read_smoke.sql` |
| SYS-DELIVERY-012 | `reception_allowlist_gate_smoke.sql` |
| SYS-DELIVERY-013–015 | `group_delivery_smoke.sql`, `group_broadcast_smoke.sql` |

---

## 5. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [SYS-ACCOUNT-BOUNDARY](./SYS-ACCOUNT-BOUNDARY.md) | Legge madre confine |
| [SYS-MAILBOX](./SYS-MAILBOX.md) | Semantica archivio e date spunta |
| [SYS-RECEPTION](./SYS-RECEPTION.md) | Gate allow list nel worker |
