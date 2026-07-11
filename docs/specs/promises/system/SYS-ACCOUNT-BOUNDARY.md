# SYS-ACCOUNT-BOUNDARY — Legge madre del confine account

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `SYS-ACCOUNT-BOUNDARY` |
| **Classe** | SYSTEM |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-11 |
| **ADR** | [multi-account-parallel-sessions.md](../../../decisions/multi-account-parallel-sessions.md) |
| **PR origine** | #179 |

Promessa SYSTEM fondamentale: **nessun account** (sessione GoTrue / `auth.uid()`) può leggere o scrivere dati nel confine di un altro account. L'unica eccezione è l'infrastruttura di recapito [SYS-DELIVERY](./SYS-DELIVERY.md), che **non è** un account.

**Dettaglio canonico**: [contracts/schema.md](../../contracts/schema.md) · [contracts/rpc.md](../../contracts/rpc.md)

---

## 1. Problema / obiettivo

Con multi-account, ogni utente ha un archivio isolato (`owner_id`). RPC e query client devono rispettare il confine: un account non può materializzare messaggi nell'archivio altrui, aggiornare `delivered_at`/`read_at` altrui, né leggere allow list o inbox di un peer per decidere azioni cross-account.

Violazioni note (debito risolto da SYS-DELIVERY): `send_message_to_profile` che INSERT nella mailbox destinatario; `mark_peer_read` che UPDATE sulla copia mittente; `erogate_group_message` invocata dal contesto mittente; gate reception letto dal lato mittente dentro RPC account.

---

## 2. Promesse

### MUST

| ID | Promessa |
|----|----------|
| **SYS-ACCOUNT-BOUNDARY-001** | Confine account = tutte le righe/tabelle dove `owner_id` identifica l'archivio dell'account (es. `messages`, `reception_allowlist`, `contacts`) |
| **SYS-ACCOUNT-BOUNDARY-002** | RPC account (`GRANT` a `authenticated`): **solo** SELECT/INSERT/UPDATE/DELETE con `owner_id = auth.uid()` (o equivalente RLS) |
| **SYS-ACCOUNT-BOUNDARY-003** | Nessuna RPC account scrive righe `messages` con `owner_id <> auth.uid()` |
| **SYS-ACCOUNT-BOUNDARY-004** | Nessuna RPC account aggiorna `delivered_at` o `read_at` su righe con `owner_id <> auth.uid()` |
| **SYS-ACCOUNT-BOUNDARY-005** | Gate reception (allow list del destinatario) valutato **solo** nell'infrastruttura [SYS-DELIVERY](./SYS-DELIVERY.md), non in RPC account |
| **SYS-ACCOUNT-BOUNDARY-006** | Erogazione gruppo verso partecipanti eseguita **solo** da [SYS-DELIVERY](./SYS-DELIVERY.md) |
| **SYS-ACCOUNT-BOUNDARY-007** | Helper `SECURITY DEFINER` cross-boundary **MUST NOT** essere `GRANT EXECUTE` a `authenticated` |

### MUST NOT

| ID | Promessa |
|----|----------|
| **SYS-ACCOUNT-BOUNDARY-008** | Eccezioni «solo per internal» o «solo per gruppi» al confine |
| **SYS-ACCOUNT-BOUNDARY-009** | Client che aggira il confine con query dirette su archivi altrui |
| **SYS-ACCOUNT-BOUNDARY-010** | Trattare l'infrastruttura delivery come «super-account» con sessione GoTrue |

---

## 3. Implementazione contratto

| Elemento | Documento / codice |
|----------|-------------------|
| Schema `alfred_delivery` | `supabase/migrations/*account_boundary*` |
| RPC account refactored | `send_message_to_profile`, `mark_peer_read`, `broadcast_message_to_allowlist` |
| Worker sincrono internal | `alfred_delivery.process_outbox` |
| Revoke helper da client | `20260707190000_revoke_helper_rpc_from_authenticated.sql` |

---

## 4. Tracciabilità

| SYS-ID | Verifica |
|--------|----------|
| SYS-ACCOUNT-BOUNDARY-002–004 | `supabase/tests/mailbox_delivery_smoke.sql`, `mailbox_read_smoke.sql` |
| SYS-ACCOUNT-BOUNDARY-005 | `reception_allowlist_gate_smoke.sql` |
| SYS-ACCOUNT-BOUNDARY-006 | `group_delivery_smoke.sql`, `group_broadcast_smoke.sql` |
| SYS-ACCOUNT-BOUNDARY-007 | `rpc_helper_security_smoke.sql` |

**Gate**: `bash scripts/check-spec-sync.sh` + smoke SQL + `bash scripts/test.sh integration`

---

## 5. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [SYS-DELIVERY](./SYS-DELIVERY.md) | Piano recapito che attraversa i confini |
| [SYS-MAILBOX](./SYS-MAILBOX.md) | Archivio per owner |
| [SYS-RECEPTION](./SYS-RECEPTION.md) | Allow list (solo confine owner) |
