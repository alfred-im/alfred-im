# Bridge stateless — stato solo in piattaforma

**Data**: 2026-06-24  
**Status**: ✅ Accettata — **regola vincolante**  
**Categoria**: Architettura bridge  
**Correlata**: [full-stack.md](../architecture/full-stack.md)

---

## Decisione

I bridge Python (**XMPP** e **Matrix**) sono **sempre stateless** rispetto allo stato di business.

**Tutto lo stato duraturo vive nella piattaforma (Supabase)** — non nei processi bridge.

---

## Cosa significa

### ✅ Stato in piattaforma (fonte di verità)

- Token di sync (MAM/RSM, Matrix sync token)
- Watermark / cursori per conversazione
- Outbox messaggi in uscita
- Mapping identità Alfred ↔ JID/Matrix ID
- Metadati federazione e routing per contatto
- Lock/idempotency per job già processati

### ✅ Bridge: cosa possono fare

- Ricevere **job/eventi** dalla piattaforma (o poll/coda)
- Aprire connessioni **effimere** verso XMPP/Matrix per eseguire il job
- Esporre la **facciata federata** verso l’esterno (principio cardine)
- Scrivere **risultati** sulla piattaforma
- Tenere solo **cache volatile** rigenerabile (nessuna perdita dati se il processo muore)

### ❌ Bridge: cosa non devono fare

- Conservare stato autorevole in memoria locale o su disco
- Assumere di essere l’**unica** istanza (niente “il mio” sync token in RAM)
- Trattare il processo come deposito di messaggi o cursori non replicati altrove

---

## Conseguenze architetturali

### Scalabilità

```
                    Load balancer (opzionale)
                           │
         ┌─────────────────┼─────────────────┐
         ▼                 ▼                 ▼
   bridge-worker-1   bridge-worker-2   bridge-worker-N
         │                 │                 │
         └─────────────────┼─────────────────┘
                           ▼
                    Piattaforma (Supabase)
                           │
                    stato + coda/job
```

- **Più repliche** dello stesso bridge: consentite
- **Autoscaling**: consentito se ogni unità di lavoro è idempotente e lo stato è su piattaforma
- **Riavvio / crash**: un bridge può morire senza perdere dati — un altro riprende da Supabase

### Coerenza con altre regole Alfred

| Regola | Relazione |
|--------|-----------|
| **Principio cardine** | Il bridge resta facciata XMPP/Matrix; la logica e i dati sono in piattaforma |
| **Flutter → solo piattaforma** | Stesso pattern: nessun layer intermedio tiene verità |
| **Piattaforma = fonte di verità** | I bridge non “correggono” dati localmente; stato duraturo solo su Supabase |

### Implementazione (quando si scrive il codice)

Pattern atteso:

1. Piattaforma accoda evento (`send_message`, `sync_conversation`, `federation_handshake`, …)
2. Un bridge worker (qualsiasi replica) prende il job con **lock** su piattaforma
3. Esegue azione protocollo verso l’esterno
4. Persiste esito + aggiorna cursori su piattaforma
5. Termina o rilascia lock — **nessuno stato indispensabile resta nel processo**

Connessioni lunghe XMPP/Matrix sono ammesse solo come **ottimizzazione effimera**; al riavvio si ricostruiscono da Supabase.

---

## Cosa NON cambia

- I bridge restano **servizi dell’istanza** (non per singolo utente login)
- Restano **sempre attivi** come pool di worker (non “accendi/spegni per utente”)
- Il protocollo resta **invisibile in UI**; routing interno per contatto invariato

“Sempre attivi” ≠ “stato in RAM”. Significa: **processi disponibili**, non **deposito dati**.

---

## Alternative scartate

| Alternativa | Perché scartata |
|-------------|-----------------|
| Bridge stateful con sessioni lunghe e sync token solo in memoria | Non scala con LB; crash = perdita/duplicati |
| Un solo bridge per istanza (no replica) | Limite operativo inutile; non serve se stateless |
| Stato in Redis separato senza Supabase | Duplica fonte di verità; Supabase deve restare l’unico store duraturo |

---

## Riferimenti

- `bridge-xmpp/main.py`, `bridge-matrix/main.py` — oggi stub; implementazione futura deve rispettare questa ADR
- `PROJECT_MAP.md` — architettura bridge
