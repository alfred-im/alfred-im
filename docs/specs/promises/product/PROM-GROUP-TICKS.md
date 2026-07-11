# PROM-GROUP-TICKS — Spunte limitate al rapporto con il gruppo

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-GROUP-TICKS` |
| **Classe** | PRODUCT |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-11 |
| **PR origine** | #162, #179 |

Promessa di prodotto: spunte del messaggio umano→gruppo riflettono solo recapito al **gruppo**; erogazione verso terzi non modifica le spunte originali; nessuna visibilità al mittente su chi ha ricevuto l'erogazione.

Semantica base spunte: [PROM-MESSAGE-STATUS](./PROM-MESSAGE-STATUS.md).

---

## 1. Problema / obiettivo

Quando un utente invia a un gruppo, le spunte sulla **propria** copia indicano se il gruppo ha ricevuto il messaggio — non se ogni membro ha ricevuto l'erogazione. I messaggi erogati su archivi persona seguono la semantica 1:1 tra persona e peer gruppo.

---

## 2. Promesse

### MUST — messaggio originale (umano → gruppo)

| ID | Promessa |
|----|----------|
| **PROM-GROUP-TICKS-001** | Spunte messaggio originale: solo ✓ accettato e ✓✓ **recapitato al gruppo** (`delivered_at` = gruppo ha ricevuto) |
| **PROM-GROUP-TICKS-002** | Erogazione automatica verso partecipanti **non** modifica `delivered_at` / `read_at` della copia del mittente originale |
| **PROM-GROUP-TICKS-003** | Erogazione verso persona che non passa il gate: skip silenzioso — **non** aggiorna spunte del messaggio originale |

### MUST — messaggio erogato (su archivio persona)

| ID | Promessa |
|----|----------|
| **PROM-GROUP-TICKS-004** | Spunte messaggio erogato: semantica [PROM-MESSAGE-STATUS](./PROM-MESSAGE-STATUS.md) tra persona e peer **gruppo** — indipendenti dal mittente umano originale |
| **PROM-GROUP-TICKS-005** | Lettura chat persona↔gruppo: `mark_peer_read(gruppo)` — non propaga al mittente umano originale |

### MUST NOT

| ID | Promessa |
|----|----------|
| **PROM-GROUP-TICKS-010** | Aggiornare `delivered_at` del mittente umano originale quando erogazione verso **terzi** riesce o fallisce |
| **PROM-GROUP-TICKS-011** | Esporre al mittente umano quali partecipanti hanno ricevuto l'erogazione |
| **PROM-GROUP-TICKS-012** | Spunte aggregate «letto da tutti i membri» per il mittente originale |

---

## 4. Contratto implementativo

| Elemento | Responsabilità |
|----------|----------------|
| `send_message_to_profile` (dest = group) | INSERT copia mittente + outbox; worker `deliver` valorizza `delivered_at` se storico gruppo INSERT |
| `alfred_delivery.erogate_group_message` | Loop allow list — skip silenzioso; no touch copia U |
| `MessageBubble` | Checkmarks da [PROM-MESSAGE-STATUS](./PROM-MESSAGE-STATUS.md) |
| UI mittente umano | Mai lista destinatari erogazione |

### Tabella spunte (v1)

| Copia | `delivered_at` significa |
|-------|-------------------------|
| Umano → gruppo | Recapitato al **gruppo** |
| Erogazione su persona | Non tocca copia umano originale |
| Persona legge chat con gruppo | `mark_peer_read(gruppo)` — spunte indipendenti |

---

## 5. Superfici conformi

| Superficie | Stato | File |
|------------|-------|------|
| Chat umano→gruppo | `implemented` | `message_bubble.dart` |
| Chat persona (erogati) | `implemented` | `messages_controller.dart` |
| Chat account gruppo | `implemented` | `group_messages_controller.dart` |

---

## 6. Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| PROM-GROUP-TICKS-001–003 | `supabase/tests/group_delivery_smoke.sql` |
| PROM-GROUP-TICKS-002, 010 | `group_delivery_smoke.sql` — delivered_at invariato su erogazione terzi |
| PROM-GROUP-TICKS-004, 005 | `mailbox_read_smoke.sql`; `message_bubble_test.dart` |
| PROM-GROUP-TICKS-011 | Nessuna API/UI «read by members» per mittente originale |


Gate: `bash scripts/check-spec-sync.sh` + `verify.sh` + smoke SQL + `integration`

---

## 7. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [registry.md](../../registry.md) | Indice promesse |
| [SYS-GROUP](../system/SYS-GROUP.md) | Pipeline erogazione |
| [PROM-MESSAGE-STATUS](./PROM-MESSAGE-STATUS.md) | Mapping date → spunte |
| [PROM-RECEPTION-FILTER](./PROM-RECEPTION-FILTER.md) | Gate erogazione |
