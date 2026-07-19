# Comandi ed eventi — contesto reception

**Ultima revisione:** 2026-07-19  
**UML:** [docs/model/uml/reception/](../../model/uml/reception/)

---

## Comandi — gestione allow list (client)

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `LoadAllowlist` | Policy (init / post-modifica) | Carica persone consentite a consegnare messaggi. |
| `SetSearchQuery` | Utente | Filtra la lista per nome visualizzato. |
| `SearchProfiles` | Utente | Cerca profili da aggiungere all'allow list. |
| `AddAllowedProfile` | Utente | Consente recapito da un profilo. |
| `RemoveAllowedPerson` | Utente | Revoca consenso recapito da un profilo. |

---

## Comandi — gate recapito (server)

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `DeliverInternal` | Worker delivery | Valuta gate prima di materializzare copia destinatario. |
| `CheckSenderAllowed` | Policy (gate) | Verifica che il mittente sia nell'allow list del destinatario. |
| `MaterializeRecipientCopy` | Policy (gate pass) | Crea copia destinatario e aggiorna spunte mittente. |
| `SkipRecipientCopy` | Policy (gate fail) | Nessuna copia destinatario; nessun errore al mittente. |

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `AllowlistLoaded` | Allow list disponibile. |
| `AllowlistLoadFailed` | Caricamento fallito. |
| `ProfileAllowed` | Profilo aggiunto all'allow list. |
| `ProfileDisallowed` | Profilo rimosso dall'allow list. |
| `AddSkipped` | Self o duplicato — nessuna modifica. |
| `DeliveryAccepted` | Gate superato — mittente riceve spunta doppia. |
| `DeliverySilentlyRejected` | Gate fallito — mittente resta con spunta singola; destinatario ignora. |

---

## Policy

| Policy | Trigger | Azione |
|--------|---------|--------|
| **Filtro sempre attivo** | Qualsiasi recapito | Gate obbligatorio — nessun toggle globale off. |
| **Lista vuota** | Allow list senza voci | Nessun mittente passa il gate. |
| **No retro-delivery** | `ProfileAllowed` tardivo | Solo messaggi nuovi recapitati. |
| **Retention archivio** | `ProfileDisallowed` | Messaggi già in inbox destinatario restano. |
| **Skip self** | `AddAllowedProfile` su profilo proprio | `AddSkipped` |

---

## Semantica recapito (osservabile)

| Ruolo | Gate fail |
|-------|-----------|
| Mittente | Invio accettato; spunta singola permanente |
| Destinatario | Messaggio assente da inbox |
| Dopo rimozione da lista | Solo messaggi **nuovi** rifiutati |
| Dopo aggiunta a lista | Nessuna retro-consegna |

---

## Tracciabilità SDD

| Elemento | Promessa |
|----------|----------|
| Filtro sempre attivo | PROM-RECEPTION-FILTER-001 |
| Lista vuota default | PROM-RECEPTION-FILTER-002, 003 |
| Rifiuto silenzioso | PROM-RECEPTION-FILTER-005, 006 |
| Isolamento rubrica | PROM-RECEPTION-FILTER-010 |
| Gate server | SYS-RECEPTION-005–010 |
| Toggle overlay peer | PROM-PEER-PROFILE-005 |
