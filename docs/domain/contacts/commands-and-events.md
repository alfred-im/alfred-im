# Comandi ed eventi — contesto contacts

**Ultima revisione:** 2026-07-19  
**UML:** [docs/model/uml/contacts/](../../model/uml/contacts/)

---

## Comandi (intento)

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `LoadContacts` | Policy (init / post-modifica) | Carica rubrica dell'account in focus. |
| `SetSearchQuery` | Utente | Filtra la rubrica per nome visualizzato (locale). |
| `SearchProfiles` | Utente | Cerca profili Alfred per aggiunta contatto internal. |
| `AddInternalContact` | Utente | Aggiunge profilo Alfred alla rubrica. |
| `AddExternalContact` | Utente | Aggiunge contatto esterno (xmpp/matrix) alla rubrica. |
| `RemoveInternalContact` | Utente | Rimuove contatto internal dalla rubrica. |
| `ComposeFromContact` | Utente | Avvia conversazione da contatto internal. |

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `ContactsLoaded` | Rubrica disponibile. |
| `ContactsLoadFailed` | Caricamento fallito; errore esposto. |
| `ContactAdded` | Contatto inserito; rubrica aggiornata. |
| `ContactRemoved` | Contatto eliminato; rubrica aggiornata. |
| `ProfileSearchResults` | Risultati ricerca profili disponibili per aggiunta. |
| `ComposePeerResolved` | Peer conversazione risolto da contatto internal. |
| `ComposeRejected` | Contatto esterno o internal invalido — nessuna conversazione avviata. |

---

## Policy

| Policy | Trigger | Azione |
|--------|---------|--------|
| **Reload post-CRUD** | `ContactAdded` / `ContactRemoved` | `LoadContacts` |
| **Ricerca minima** | `SearchProfiles` con query corta | Nessuna chiamata server |
| **Compose solo internal** | `ComposeFromContact` su esterno | `ComposeRejected` |
| **Scope per focus** | Cambio account | Rubrica ricaricata per nuovo owner |

---

## Tracciabilità SDD

| Elemento | Promessa |
|----------|----------|
| Isolamento rubrica / inbox | PROM-PERSONAL-CONTACTS-001–005 |
| Compose internal / reject external | PROM-PERSONAL-CONTACTS-006, 021 |
| Rubrica per account in focus | PROM-PERSONAL-CONTACTS-007 |
| Filtro lista | PROM-PERSONAL-CONTACTS-008 |
| Reload post-add | PROM-PERSONAL-CONTACTS-011 |
| Azione rubrica da overlay peer | PROM-PEER-PROFILE-006 |
