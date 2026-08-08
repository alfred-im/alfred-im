# PROM-RECEPTION-FILTER — Filtro ricezione sempre attivo e rifiuto silenzioso

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-RECEPTION-FILTER` |
| **Classe** | PRODUCT |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-08-01 |
| **PR origine** | #161, #179 |

Promessa di prodotto: il destinatario controlla chi può **consegnargli** messaggi; filtro **sempre attivo**; rifiuto **silenzioso** verso il mittente (stile blocco XMPP).

Gate server e schema `reception_allowlist` restano in [SYS-RECEPTION](../system/SYS-RECEPTION.md) e [contracts/schema.md](../../contracts/schema.md).

---

## 1. Problema / obiettivo

L'utente Alfred decide chi può materializzare messaggi nel proprio archivio e con chi accetta di **inviare**. Lista vuota = nessuno può recapitare né ricevere invii verso profili non consentiti. Su rifiuto **inbound** (destinatario non consente): il mittente non riceve errore né etichetta «bloccato» — vede al massimo ✓ (accettato server), mai ✓✓ (consegnato). Su rifiuto **outbound** (mittente non ha consenso proprio verso il destinatario): errore RPC e composer disabilitato.

### Semantica spunte (mittente) — due livelli

1. **✓** — server ha **accettato** il messaggio (copia mittente persistita; RPC ok).
2. **✓✓ grigie** — messaggio **consegnato** al destinatario (copia nel suo archivio; `delivered_at` valorizzato).

Su rifiuto allow list **inbound**: il mittente resta al livello **1** per sempre — come blocco XMPP, senza feedback esplicito.

Su tentativo invio **outbound** senza consenso proprio: errore server strutturale; nessuna copia mittente.

---

## 2. Promesse

### MUST — semantica filtro

| ID | Promessa |
|----|----------|
| **PROM-RECEPTION-FILTER-001** | Filtro **sempre attivo** — nessun toggle on/off globale utente o piattaforma |
| **PROM-RECEPTION-FILTER-002** | Lista vuota → **nessun** mittente può consegnare messaggi nuovi |
| **PROM-RECEPTION-FILTER-003** | Nuovo account: lista vuota di default (nessuno può scrivere finché non si aggiunge qualcuno) |
| **PROM-RECEPTION-FILTER-004** | Condizione recapito: mittente ∈ `reception_allowlist` del destinatario |
| **PROM-RECEPTION-FILTER-005** | Su rifiuto **inbound**: copia mittente esiste (✓); **nessuna** copia destinatario; `delivered_at` null permanente sulla copia mittente |
| **PROM-RECEPTION-FILTER-006** | Su rifiuto **inbound**: RPC ritorna successo al mittente — **nessun** errore, codice o messaggio «bloccato» / «rifiutato» |
| **PROM-RECEPTION-FILTER-007** | Destinatario **non** vede messaggi rifiutati nell'inbox |
| **PROM-RECEPTION-FILTER-008** | Rimozione da lista: messaggi già in archivio **restano**; solo messaggi **nuovi** dopo rimozione rifiutati |
| **PROM-RECEPTION-FILTER-009** | Aggiunta a lista: **nessuna** retro-consegna di messaggi precedentemente rifiutati |

### MUST — isolamento da rubrica

| ID | Promessa |
|----|----------|
| **PROM-RECEPTION-FILTER-010** | Rubrica (`contacts`) **non** implica consenso ricezione — vedi [PROM-PERSONAL-CONTACTS](./PROM-PERSONAL-CONTACTS.md) |

### MUST — gate outbound (mittente)

| ID | Promessa |
|----|----------|
| **PROM-RECEPTION-FILTER-011** | Per inviare a un profilo, il mittente deve averlo nella propria `reception_allowlist` |
| **PROM-RECEPTION-FILTER-012** | Violazione gate outbound: RPC `send_message_to_profile` errore `recipient not in reception allowlist` — **nessuna** copia mittente |
| **PROM-RECEPTION-FILTER-013** | Chat 1:1: `ChatInputBar` disabilitato se peer ∉ allow list propria o lista in caricamento |

### MUST NOT

| ID | Promessa |
|----|----------|
| **PROM-RECEPTION-FILTER-020** | Errore RPC o messaggio «bloccato» verso il mittente su rifiuto **inbound** |
| **PROM-RECEPTION-FILTER-021** | Mostrare al mittente che il destinatario usa un filtro di ricezione |
| **PROM-RECEPTION-FILTER-022** | Toggle globale enable/disable della funzionalità |
| **PROM-RECEPTION-FILTER-023** | Usare rubrica come proxy dell'allow list |
| **PROM-RECEPTION-FILTER-024** | Eliminare dall'archivio messaggi già ricevuti quando si rimuove qualcuno dalla lista |
| **PROM-RECEPTION-FILTER-025** | Retro-consegnare messaggi rifiutati all'aggiunta tardiva |
| **PROM-RECEPTION-FILTER-026** | Inviare (RPC successo o composer attivo) verso peer non in propria allow list |

---


## 3. Modello (riferimento)

| Elemento | Artefatto |
|----------|-----------|
| Glossario / comandi | [docs/domain/reception/](../../../domain/reception/), [docs/domain/delivery/](../../../domain/delivery/) |
| UML | [docs/model/uml/reception/](../../../model/uml/reception/), [docs/model/uml/delivery/seq-reception-gate.puml](../../../model/uml/delivery/seq-reception-gate.puml) |
| Statechart client | [client/lib/machines/reception/](../../../../client/lib/machines/reception/) |
| Gate recapito | `EvaluateInboundDelivery` — [seq-reception-delivery-gate.puml](../../../model/uml/reception/seq-reception-delivery-gate.puml) |

**Implementazione (non vincolante):** [docs/domain/reception/README.md](../../../domain/reception/README.md) · schema: [SYS-RECEPTION](../system/SYS-RECEPTION.md)


## 4. Superfici conformi

| Superficie | Stato | File |
|------------|-------|------|
| SURF-ALLOWLIST | `implemented` | [SURF-ALLOWLIST.md](../../surfaces/SURF-ALLOWLIST.md) |
| Toggle overlay peer | `implemented` | [PROM-PEER-PROFILE](./PROM-PEER-PROFILE.md) |
| Spunte mittente | `implemented` | [PROM-MESSAGE-STATUS](./PROM-MESSAGE-STATUS.md) |
| Composer chat 1:1 | `implemented` | [SURF-CHAT](../../surfaces/SURF-CHAT.md) |

---

## 5. Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| PROM-RECEPTION-FILTER-002, 005–006 | `reception_allowlist_gate_smoke.sql`, `delivery_ticks_smoke.sql` |
| PROM-RECEPTION-FILTER-008–009 | `reception_allowlist_gate_smoke.sql` |
| PROM-RECEPTION-FILTER-011–012 | `reception_outbound_gate_smoke.sql` |
| PROM-RECEPTION-FILTER-013 | `client/test/widget/chat_panel_composer_gate_test.dart` |
| PROM-RECEPTION-FILTER-006 | `bash scripts/test.sh integration` |
| PROM-RECEPTION-FILTER-005, 007 | [SYS-MAILBOX](../system/SYS-MAILBOX.md) — `delivered_at` null = ✓ singola |
| PROM-RECEPTION-FILTER-020, 021 | `reception_allowlist_gate_smoke.sql`; nessun campo client `reception_rejected` |


Gate: `bash scripts/check-spec-sync.sh` + `verify.sh` + smoke SQL + `integration`

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [registry.md](../../registry.md) | Indice promesse |
| [SYS-RECEPTION](../system/SYS-RECEPTION.md) | Gate allow list (semantica) |
| [SYS-DELIVERY](../system/SYS-DELIVERY.md) | Worker recapito e gate |
| [SYS-MAILBOX](../system/SYS-MAILBOX.md) | Pipeline invio condizionata |
| [server-as-reception.md](../../../decisions/server-as-reception.md) | ADR semantica consegna |
