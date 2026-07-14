# SYS-MAILBOX — Archivio messaggi, invio, inbox e lettura

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `SYS-MAILBOX` |
| **Classe** | SYSTEM |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-11 |
| **ADR** | [mailbox-inbox-outbox-spec.md](../../../architecture/mailbox-inbox-outbox-spec.md), [server-as-reception.md](../../../decisions/server-as-reception.md), [no-internal-external-chat-distinction.md](../../../decisions/no-internal-external-chat-distinction.md), [bridge-stateless.md](../../../decisions/bridge-stateless.md) |
| **PR origine** | #159, #179 |

Promessa SYSTEM — modello **mailbox** (archivio per owner), pipeline invio/outbox, aggregazione inbox on-read, date consegna/lettura. Il dettaglio canonico di schema e RPC resta nei contratti; questo file è indice promessa + tracciabilità v2.

**Dettaglio canonico**: [contracts/schema.md](../../contracts/schema.md) § mailbox · [contracts/rpc.md](../../contracts/rpc.md) § mailbox

---

## 1. Problema / obiettivo

Ogni utente ha un **archivio messaggi indipendente** (`owner_id`). Mittente e destinatario hanno sempre righe distinte correlate da `logical_message_id` (λ). L'inbox non è entità DB: è aggregazione on-read sull'archivio dell'owner. Invio unificato via `send_message_to_profile` (solo confine mittente); recapito internal sincrono in transazione RPC tramite worker [SYS-DELIVERY](./SYS-DELIVERY.md) con gate [SYS-RECEPTION](./SYS-RECEPTION.md). Spunte da date nullable su copia mittente; lettura locale su copia destinatario con propagazione `read_at` via worker `read_receipt`.

Requisiti **client/UI** (coda outbound, realtime subscribe, checkmark rendering, multi-account focus, filtro lista) sono delegati a promesse **PRODUCT** / **SURFACE** — vedi §6.

---

## 2. Promesse backend

### SCHEMA — modello archivio e migrazione

#### MUST

| ID | Promessa |
|----|----------|
| **SYS-MAILBOX-001** | Tabella `messages` con `owner_id` (archivio) e `author_id` (autore originale contenuto) — [schema.md](../../contracts/schema.md) § mailbox |
| **SYS-MAILBOX-002** | Nessuna riga visibile a due owner: mittente e destinatario hanno **sempre** `id` riga distinti |
| **SYS-MAILBOX-003** | `logical_message_id` (λ) UUID generato server alla accettazione invio; correlazione copie e segnali spunta |
| **SYS-MAILBOX-004** | `client_message_id` solo sulla copia mittente (`owner_id = author_id = mittente`); dedup UNIQUE `(owner_id, client_message_id)` WHERE `client_message_id IS NOT NULL` |
| **SYS-MAILBOX-005** | Dedup materializzazione destinatario: UNIQUE `(owner_id, logical_message_id)` |
| **SYS-MAILBOX-006** | RLS: SELECT/INSERT/UPDATE solo `owner_id = auth.uid()` — **nessuna eccezione** |
| **SYS-MAILBOX-007** | Colonna `peer_profile_id` denormalizzata per raggruppamento inbox/storico (internal) |
| **SYS-MAILBOX-008** | Migrazione prototipo: drop modello message-centric + wipe dati test; ricrea schema mailbox; pulizia blob `chat-media` **non referenziati** post-migrazione |
| **SYS-MAILBOX-009** | Media: stesso `media_url` su copia mittente e destinatario; un upload, nessuna duplicazione blob |

#### SHOULD

| ID | Promessa |
|----|----------|
| **SYS-MAILBOX-010** | Indici `(owner_id, peer_profile_id, created_at DESC)` e `(owner_id, logical_message_id)` |
| **SYS-MAILBOX-011** | `peer_external_address` nullable per federazione futura (non usata (scope attuale) UI) |

#### MUST NOT

| ID | Promessa |
|----|----------|
| **SYS-MAILBOX-012** | Tabella `inbox_threads`, cache inbox, `thread_id` client |
| **SYS-MAILBOX-013** | Colonna `direction` — in/out da `author_id` vs `owner_id` |
| **SYS-MAILBOX-014** | Tabella `message_read_receipts` (sostituita da date su `messages`) |
| **SYS-MAILBOX-015** | RLS che permette lettura archivio altrui |
| **SYS-MAILBOX-016** | Doppia scrittura message-centric + mailbox |

---

### SEND — invio e outbox

#### MUST

| ID | Promessa |
|----|----------|
| **SYS-MAILBOX-017** | Unico RPC invio: `send_message_to_profile` — firma invariata PostgREST — [rpc.md](../../contracts/rpc.md) § mailbox |
| **SYS-MAILBOX-018** | Accettazione: INSERT copia mittente (`owner_id = author_id = auth.uid()`), `delivered_at`/`read_at` null, λ assegnato |
| **SYS-MAILBOX-019** | **Outbox sempre**: INSERT `outbox` (`event_kind = deliver`) per ogni invio, incluso `protocol = internal` |
| **SYS-MAILBOX-020** | Driver internal: worker [SYS-DELIVERY](./SYS-DELIVERY.md) nella stessa transazione RPC — **se** gate reception → materializza copia destinatario + `delivered_at` mittente; **altrimenti** rifiuto silenzioso |
| **SYS-MAILBOX-021** | Idempotenza: retry stesso `(owner_id, client_message_id)` → stessa riga mittente, no duplicati |
| **SYS-MAILBOX-022** | Tipi `content_type`: `text`, `gif`, `voice`, `location`, `image`, `video` — validazione in [PROM-CHAT-MEDIA](../product/PROM-CHAT-MEDIA.md) |
| **SYS-MAILBOX-023** | Bucket storage `chat-media`: path `{auth.uid()}/{uuid}.*` (upload prima RPC) |
| **SYS-MAILBOX-024** | Outbox retry: `attempts`, `last_error`, `status` → `failed` dopo soglia (default 5 tentativi worker/cron futuro; internal sincrono non fallisce salvo errore transazione) |
| **SYS-MAILBOX-025** | Invio fallito server: `failed_at` timestamptz sulla copia mittente (opzionale null se non applicabile) |

#### SHOULD

| ID | Promessa |
|----|----------|
| **SYS-MAILBOX-026** | Payload outbox include λ, destinatario, snapshot contenuto, `media_url` |
| **SYS-MAILBOX-027** | Preview inbox coerente per tipo (funzioni `format_*_preview`) |

#### MUST NOT

| ID | Promessa |
|----|----------|
| **SYS-MAILBOX-028** | Shortcut trigger `sent → delivered` senza outbox e senza copia destinatario |
| **SYS-MAILBOX-029** | Invio a sé stessi |
| **SYS-MAILBOX-030** | Indirizzo esterno `user@server` senza errore utente (v1: **unsupported** in compose) |
| **SYS-MAILBOX-031** | Overload ambigui `send_message_to_profile` PostgREST |
| **SYS-MAILBOX-032** | Pipeline invio distinta per internal vs federato (solo driver recapito differisce in fase B) |

---

### INBOX — aggregazione on-read

#### MUST

| ID | Promessa |
|----|----------|
| **SYS-MAILBOX-033** | `list_inbox()` aggrega **solo** `messages` WHERE `owner_id = auth.uid()` |
| **SYS-MAILBOX-034** | GROUP BY `peer_profile_id` (interni (stessa istanza)) |
| **SYS-MAILBOX-035** | Payload riga: `peer_profile_id`, `display_name`, `last_message_preview`, `last_message_at`, `unread_count`, campi profilo peer |
| **SYS-MAILBOX-036** | `list_peer_messages(peer)` = righe WHERE `owner_id = auth.uid()` AND `peer_profile_id = peer` ORDER BY `created_at` |
| **SYS-MAILBOX-037** | Prima riga inbox solo dopo primo messaggio nel mio archivio con quel peer |
| **SYS-MAILBOX-038** | `unread_count`: righe in entrata (`author_id <> auth.uid()`) con `read_at IS NULL` |

#### SHOULD

| ID | Promessa |
|----|----------|
| **SYS-MAILBOX-039** | Preview per tipo: testo troncato, `[GIF]`, `🎤`, `📍 Posizione` |
| **SYS-MAILBOX-040** | `last_message_at` = `created_at` dell'ultima riga nel mio archivio per quel peer |

#### MUST NOT

| ID | Promessa |
|----|----------|
| **SYS-MAILBOX-041** | Tabella/cache/vista materializzata inbox |
| **SYS-MAILBOX-042** | Query su righe dove l'utente non è `owner_id` |
| **SYS-MAILBOX-043** | `thread_id` esposto al client |
| **SYS-MAILBOX-044** | Record inbox prima del primo messaggio |
| **SYS-MAILBOX-045** | Rubrica prerequisito per scrivere (invariato) |

---

### READ — date consegna e lettura

#### MUST

| ID | Promessa |
|----|----------|
| **SYS-MAILBOX-046** | `delivered_at` valorizzato solo dopo materializzazione copia destinatario ([SYS-MAILBOX](./SYS-MAILBOX.md) invio) — non da Realtime client destinatario |
| **SYS-MAILBOX-047** | `mark_peer_read(peer)`: UPDATE righe in entrata nel mio archivio (`owner_id = io`, `author_id = peer`, `read_at IS NULL`) SET `read_at = now()` |
| **SYS-MAILBOX-048** | Per ogni λ letto: accoda `outbox` `event_kind = read_receipt`; worker [SYS-DELIVERY](./SYS-DELIVERY.md) aggiorna `read_at` sulla copia mittente — **nessuna** UPDATE account cross-boundary |
| **SYS-MAILBOX-049** | Lettura include body non vuoto OPPURE `content_type` ∈ gif, voice, location, image, video |
| **SYS-MAILBOX-050** | `list_inbox` unread: righe in entrata con `read_at IS NULL` |

#### MUST NOT

| ID | Promessa |
|----|----------|
| **SYS-MAILBOX-051** | UPDATE archivio destinatario per mostrare spunte al mittente |
| **SYS-MAILBOX-052** | Enum `message_delivery_status` su `messages` target |
| **SYS-MAILBOX-053** | Tabella `message_read_receipts` |
| **SYS-MAILBOX-054** | Regressione spunte: se `read_at` già set, ignorare segnale `delivered_at` tardivo |
| **SYS-MAILBOX-055** | Semantica «consegnato» = device P2P peer |

---

## 3. Identificatori e date spunta (contratto)

| Id | Scope | Ruolo |
|----|-------|-------|
| `id` | Per owner | PK riga archivio locale |
| `client_message_id` | Copia mittente | Idempotenza invio client |
| `logical_message_id` | Piattaforma | Correlazione copie + spunte |
| `external_id` | Federato futuro | Bridge (fase B) |

| Copia | Campi | Semantica |
|-------|-------|-----------|
| Mittente (uscita) | `delivered_at`, `read_at` | null = non ancora; valorizzate da pipeline / segnali |
| Destinatario (entrata) | `read_at` | Lettura locale; alimenta `mark_peer_read` |

Regola: se `read_at` valorizzata su copia mittente, `delivered_at` tardivo non la azzera.

---

## 5. Implementazione contratto

| Elemento | Documento / codice |
|----------|-------------------|
| Schema `messages`, `outbox`, RLS, bucket `chat-media` | [contracts/schema.md](../../contracts/schema.md) § mailbox |
| RPC `send_message_to_profile`, `list_inbox`, `list_peer_messages`, `mark_peer_read`, `find_profile_by_username` | [contracts/rpc.md](../../contracts/rpc.md) § mailbox |
| Migrazioni mailbox | `supabase/migrations/*mailbox*` |
| Pipeline invio / worker delivery | `alfred_delivery.process_outbox` in migrazione `*account_boundary_delivery*` |
| Smoke SQL | `supabase/tests/mailbox_*.sql`, `reception_allowlist_gate_smoke.sql`, `delivery_ticks_smoke.sql` |
| Client RPC / servizi | `message_service.dart`, `inbox_service.dart` |

### Flusso internal (transazione RPC + worker)

```
send_message_to_profile (solo confine mittente)
  → INSERT messages (owner=mittente, author=mittente, λ, peer=dest)     ← livello ✓
  → INSERT outbox (event_kind=deliver, queued)
  → alfred_delivery.process_outbox
       → gate reception_allowlist (destinatario)
       → SE allowed:
            INSERT messages (owner=destinatario, …)
            UPDATE messages SET delivered_at=now() WHERE owner=mittente AND λ  ← livello ✓✓
          ALTRIMENTI:
            delivered_at resta null (✓ senza ✓✓)
  → outbox completed
  → RETURN riga mittente
```

### RPC `mark_peer_read`

```sql
mark_peer_read(p_peer_profile_id uuid) → void
```

1. UPDATE `messages` SET `read_at = now()` WHERE `owner_id = auth.uid()` AND `peer_profile_id = p_peer` AND `author_id = p_peer` AND `read_at IS NULL` AND contenuto leggibile
2. Per ogni λ: outbox `read_receipt` → worker aggiorna copia mittente (vedi [SYS-DELIVERY](./SYS-DELIVERY.md))

---

## 7. Tracciabilità

| SYS-ID | Verifica |
|--------|----------|
| SYS-MAILBOX-001, 002, 006, 012, 014 | `supabase/tests/mailbox_schema_smoke.sql` |
| SYS-MAILBOX-004, 005, 021 | `supabase/tests/mailbox_idempotency_smoke.sql` |
| SYS-MAILBOX-008 | migrazione `supabase/migrations/*mailbox*` |
| SYS-MAILBOX-009, 022 | `supabase/tests/mailbox_send_media_smoke.sql` |
| SYS-MAILBOX-017 | `schema_smoke.sql` + `mailbox_send_smoke.sql` |
| SYS-MAILBOX-019, 020 | `mailbox_delivery_smoke.sql`, `reception_allowlist_gate_smoke.sql`, `delivery_ticks_smoke.sql` |
| SYS-MAILBOX-018–020 | `delivery_ticks_smoke.sql`, `bash scripts/test.sh integration-ticks` |
| SYS-MAILBOX-028 | assenza trigger `on_message_inserted` legacy internal delivered |
| SYS-MAILBOX-030 | `ComposeService` → errore esterno |
| SYS-MAILBOX-033, 034, 036, 037, 050 | `supabase/tests/mailbox_inbox_smoke.sql` |
| SYS-MAILBOX-038 | smoke unread dopo messaggio in entrata non letto |
| SYS-MAILBOX-041 | `mailbox_schema_smoke.sql` |
| SYS-MAILBOX-046 | `mailbox_delivery_smoke.sql` |
| SYS-MAILBOX-047–049 | `supabase/tests/mailbox_read_smoke.sql` |
| SYS-MAILBOX-054 | `client/test/unit/models_and_utils_test.dart` |
| SYS-MAILBOX-017–025 | `bash scripts/test.sh integration` |
| PROM-OUTBOUND-SEND | `messages_controller_multi_account_test.dart`, `multi_account_scope_test.dart` |
| PROM-REALTIME-OWNER-001 | `inbox_provider_listen_test.dart`, `inbox_realtime_owner_filter_test.dart` |
| PROM-REALTIME-OWNER-007 | `multi_account_chat_scenario_test.dart` |
| PROM-LIST-FILTER, SURF-INBOX | `inbox_controller.dart` `filteredPeers` |
| PROM-MESSAGE-STATUS | `message_bubble_test.dart`, `models_and_utils_test.dart` |
| PROM-REALTIME-OWNER-005 | `messages_controller_multi_account_test.dart` |
| SYS-MAILBOX-017–050 | `bash scripts/test.sh e2e-multi` |

**Gate**: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh` + `integration` + `e2e-multi`

---

## 8. Fuori scope

- Delete chat / messaggio singolo
- Gruppi (MUC) — vedi [SYS-GROUP](./SYS-GROUP.md)
- GC refcount continuo (solo purge orfani a migrazione + policy futura)
- Preservazione dati produzione (prototipo dev only)
- Bridge consumer (fase B post-mailbox)

---

## 9. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [contracts/schema.md](../../contracts/schema.md) | Dettaglio schema mailbox |
| [contracts/rpc.md](../../contracts/rpc.md) | Dettaglio RPC mailbox |
| [SYS-RECEPTION](./SYS-RECEPTION.md) | Gate recapito destinatario |
| [mailbox-inbox-outbox-spec.md](../../../architecture/mailbox-inbox-outbox-spec.md) | Principi architetturali |
