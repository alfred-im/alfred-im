# Invarianti — reception

**Bounded context:** `reception`  
**Implementazione:** `reception_allowlist` (Postgres), `ReceptionMachine`, worker `alfred_delivery`  
**Confine prodotto:** [SYS-RECEPTION](../../specs/promises/system/SYS-RECEPTION.md), [PROM-RECEPTION-FILTER](../../specs/promises/product/PROM-RECEPTION-FILTER.md)

---

## Allow list

1. `reception_allowlist` **≠** rubrica `contacts` — CRUD lista non implica recapito né viceversa.
2. Lista vuota → nessun recapito inbound; nessun retro-delivery su add ([SYS-RECEPTION-007](../../specs/promises/system/SYS-RECEPTION.md), SYS-RECEPTION-012).
3. Rimozione da lista: messaggi già in archivio destinatario restano; solo messaggi nuovi rifiutati (SYS-RECEPTION-011).

## Gate recapito

1. **Outbound** (RPC `send_message_to_profile`): destinatario deve essere in allow list del mittente — altrimenti eccezione, nessuna copia mittente (SYS-RECEPTION-029–031).
2. **Inbound** (worker): mittente deve essere in allow list del destinatario — altrimenti rifiuto silenzioso, ✓ senza ✓✓ (SYS-RECEPTION-005–010).
3. Rifiuto inbound: RPC ritorna copia mittente senza errore client; `delivered_at` resta null.

## UI client

1. Toggle allow list da scheda profilo peer e da «Persone consentite» — stessa tabella server ([SURF-ALLOWLIST](../../specs/surfaces/SURF-ALLOWLIST.md), [SURF-PEER-PROFILE](../../specs/surfaces/SURF-PEER-PROFILE.md)).
