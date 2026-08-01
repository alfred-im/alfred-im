# Glossario — contesto reception

**Bounded context:** `reception`  
**Ultima revisione:** 2026-07-27  
**Promesse SDD:** [SYS-RECEPTION](../../specs/promises/system/SYS-RECEPTION.md), [PROM-RECEPTION-FILTER](../../specs/promises/product/PROM-RECEPTION-FILTER.md)

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Reception allowlist** | Elenco profili autorizzati a **consegnare** messaggi al destinatario. |
| **Allowed person** | Voce allow list: identificativo entry + identità profilo consentito. |
| **Owner (destinatario)** | Utente che filtra la ricezione. |
| **Sender gate (inbound)** | Condizione recapito: mittente ∈ allow list del destinatario. |
| **Outbound send gate** | Condizione invio: destinatario ∈ allow list del mittente. |
| **EvaluateInboundDelivery** | Comando worker che valuta il gate prima della materializzazione copia destinatario. |
| **DeliveryPermitted** | Esito gate positivo — copia destinatario materializzata, spunta doppia mittente. |
| **DeliverySilentlyBlocked** | Esito gate negativo — nessuna copia destinatario; mittente resta a ✓ singola. |
| **Silent rejection** | Messaggio accettato lato mittente (✓) ma senza copia destinatario né ✓✓ — nessun errore al mittente. |
| **Empty allowlist** | Lista vuota → nessun mittente passa il gate ([PROM-RECEPTION-FILTER-002](../../specs/promises/product/PROM-RECEPTION-FILTER.md)). |
| **Always-on filter** | Nessun toggle globale on/off — filtro sempre attivo ([SYS-RECEPTION-014](../../specs/promises/system/SYS-RECEPTION.md)). |
| **No retro-delivery** | Aggiunta tardiva non consegna messaggi precedentemente rifiutati. |
| **Archive retention** | Rimozione da lista: messaggi già in archivio destinatario restano. |
| **Consenti messaggi** | Etichetta UI switch overlay peer e gestione lista persone consentite. |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **delivery** | Worker applica gate prima di materializzare copia destinatario. |
| **messaging** | Mittente vede ✓ permanente, mai ✓✓ se rifiutato; destinatario non vede messaggio. |
| **contacts** | Rubrica **non** proxy allow list ([SYS-RECEPTION-022](../../specs/promises/system/SYS-RECEPTION.md)). |
| **profile** | Identità pubblica nelle voci lista; ricerca profili per aggiunta. |
| **multi-account** | Allow list scoped all'account in focus. |

---

## Invarianti

1. Gate server **inbound** prima della materializzazione copia destinatario.
2. Gate server **outbound** prima della materializzazione copia mittente.
3. Rifiuto inbound: nessun errore verso mittente, nessun messaggio «bloccato» al mittente.
4. Rifiuto outbound: errore RPC strutturale; nessuna copia mittente.
5. Non consentire profilo proprio nell'allow list.
6. Unicità coppia (owner, profilo consentito).
5. Toggle allow in overlay: immediato, senza dialog ([PROM-PEER-PROFILE-008](../../specs/promises/product/PROM-PEER-PROFILE.md)); rimozione da screen lista richiede conferma.
