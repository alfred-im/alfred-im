# Allineamento erogazione gruppo→membro alla pipeline delivery standard

**Stato:** decisione approvata — implementazione in corso  
**Data:** 2026-09-13  
**Istanza analizzata:** Arkham (`tvwpoxxcqwphryvuyqzu`), gruppo **test5**  
**Correlata:** [SYS-DELIVERY](../specs/promises/system/SYS-DELIVERY.md), [SYS-GROUP](../specs/promises/system/SYS-GROUP.md), [PROM-GROUP-TICKS](../specs/promises/product/PROM-GROUP-TICKS.md), [mailbox-inbox-outbox-spec.md](../architecture/mailbox-inbox-outbox-spec.md)

---

## 1. Obiettivo

Riallineare l'**erogazione gruppo→membro** (gamba 2) al binario standard della piattaforma:

`outbox (deliver)` → `alfred_delivery.process_outbox` → `deliver_internal` → copia destinatario + ack sul mittente **di quella gamba**

Senza cambiare la semantica delle **spunte umane** (gamba 1): ✓✓ = «il gruppo ha ricevuto», non «tutti i membri l'hanno ricevuto».

---

## 2. Contesto e analisi DB (test5, Arkham)

### Gruppo test5

- Unico gruppo su Arkham (`profile_kind = group`)
- 6 membri in allowlist: `test1`–`test4`, `adrien`, `adrien_prinze`
- 37 `logical_message_id` distinti nella conversazione

### Quattro livelli di riga

| Livello | Riga | `delivered_at` | `read_at` |
|---------|------|----------------|-----------|
| **A — umano→gruppo** | `archive_user = mittente`, `author = mittente`, `peer = test5` | 24/26 | 5/26 |
| **B — archivio gruppo (inbound umano)** | `archive_user = test5`, `author = mittente` | 5/6 | 5/6 |
| **C — proxy erogato sul membro** | `archive_user = membro`, `author = test5`, `peer = test5` | 0/105 (inbound) | 79/105 |
| **D — archivio gruppo 1:1** | `archive_user = test5`, `peer = membro` | 0 | 24 |

**Payload:** 36/36 lambda con copie `peer=test5` hanno body/media identici tra chi le ha.

### Anomalie rilevate

**Inviati ✓✓ senza proxy corrispondente** (fanout, gate ok al momento invio):

- **20 righe** con filtro `delivered_at` + allowlist al momento invio
- **17** → `adrien` (manca allowlist inversa: gruppo permette adrien, adrien **non** permette test5)
- **3** → `test4` (luglio, fanout incompleto — buchi reali)

**Ricevuti senza archivio gruppo** (broadcast):

- **18 righe** proxy su 5 lambda; archivio gruppo cancellato

**Allowlist bidirezionale oggi:**

| Membro | Gruppo→membro | Membro→gruppo |
|--------|---------------|---------------|
| test1–4, adrien_prinze | ✓ | ✓ |
| adrien | ✓ | **✗** |

---

## 3. Architettura attuale vs proposta

### Attuale

```
Umano invia → outbox deliver
  → INSERT archivio gruppo
  → delivered_at su copia UMANA          ← gamba 1 chiusa
  → erogate_group_message()              ← shortcut
       → INSERT diretto su membro
       → push ad hoc
       → NO outbox deliver per membro
       → NO copia uscita gruppo→membro (fanout)
       → NO delivered_at su gamba gruppo→membro
```

### Proposta

```
Gamba 1 (invariata):
  Umano → gruppo: deliver_internal → delivered_at su copia umana

Gamba 2 (per ogni membro eleggibile, locale o @server):
  Copia USCITA gruppo (peer = membro, stesso λ) — solo fanout da messaggio umano
  → outbox deliver
  → deliver_internal (driver locale o Gotham)
  → INSERT inbound membro
  → delivered_at su copia USCITA gruppo di quel membro
  → push_notify (se locale)

Broadcast: stessa pipeline dalla riga archivio gruppo (peer NULL), senza copie uscita aggiuntive.
```

`erogate_group_message` diventa **orchestratore** (accoda N `deliver`), non INSERT diretto.

---

## 4. Q&A

| Domanda | Risposta |
|---------|----------|
| Tutte le anomalie sono su test5? | Sì, unico gruppo su Arkham |
| Filtrare solo messaggi con doppia spunta? | Sì per «persi» vs «scartati»; 20 fanout reali (17 adrien = gate, 3 test4 = buchi) |
| `delivered_at` sul proxy inbound? | No — righe inbound; solo `read_at` locale |
| Conflitto di prodotto? | ✓✓ umano = «gruppo ha ricevuto»; adrien senza proxy ma mittente con ✓✓ è **by design** (`PROM-GROUP-TICKS`) |
| Refactor + spunta com'è ora? | **Sì** — gamba 1 e gamba 2 indipendenti |
| Presuppone federazione? | Stesso piano `outbox`/`alfred_delivery`; driver Gotham per gambe `@server` |
| Gotham diceva gruppi fuori scope? | **Errore doc** — corretto su `main` (`a5e0fea`) |
| Cosa cambia nelle ADR? | Nessuna nuova decisione; amend opzionali di chiarimento su `address-based-messaging.md` |

---

## 5. Decisioni

| # | Decisione | Stato |
|---|-----------|-------|
| D1 | Allineare gamba 2 alla pipeline delivery standard | **Approvata** |
| D2 | Mantenere spunte umane (gamba 1) invariate | **Confermata** |
| D3 | Gruppi in scope federazione Gotham | **Fatto** (doc) |
| D4 | Non cambiare skip silenzioso su gate bidirezionale | Implicito |
| D5 | Backfill DB test4 (3 messaggi) | **Fuori scope** |
| D6 | UNIQUE `(archive_user_id, logical_message_id, peer_address)` per copie uscita gruppo | **Necessario** per fanout |

---

## 6. Cosa NON cambia

- `logical_message_id` unico su tutte le copie (stesso λ, `peer_address` distingue righe gruppo)
- `original_author_id` sul proxy inbound
- Spunte **umane**: solo gamba 1
- Skip silenzioso se membro non passa allowlist bidirezionale
- Nessuna visibilità al mittente umano su chi ha ricevuto l'erogazione

---

## 7. Cosa cambia (implementazione)

### SQL / delivery

- Refactor `erogate_group_message`: orchestrazione via `deliver_internal` / outbox `deliver`
- Copia uscita gruppo→membro per fanout da messaggio umano
- `group_erogate` (broadcast): stesso binario dalla riga archivio gruppo
- `deliver_internal`: ramo `group → user` (erogazione) senza richiamare `erogate_group_message`
- Indice unico: `(archive_user_id, logical_message_id, peer_address)` con `NULLS NOT DISTINCT`

### SDD

- `SYS-DELIVERY` — SYS-DELIVERY-013/015
- `SYS-GROUP` — SYS-GROUP-020/021
- `contracts/schema.md`, `contracts/rpc.md`

### Test

- `group_delivery_smoke.sql` — aggiornato per N righe archivio gruppo
- Nuovo smoke gate bidirezionale fallito

### Fuori scope

- Backfill 3 messaggi test4
- Ripristino 18 righe archivio gruppo broadcast
- Amend `PROM-GROUP-TICKS`

---

## 8. Riferimenti

| Risorsa | Path |
|---------|------|
| Delivery worker | `supabase/migrations/20260913100000_peer_address_identity.sql` |
| `erogate_group_message` | ~1298 |
| `deliver_internal` | ~1394 |
| Smoke gruppo | `supabase/tests/group_delivery_smoke.sql` |
