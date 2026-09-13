# Comandi ed eventi — contesto contacts

**Ultima revisione:** 2026-09-13  
**UML:** [docs/model/uml/contacts/](../../model/uml/contacts/)  
**Amend:** rubrica solo `address` — distillazione TEMP §7

---

## Comandi

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `AddContact` | Utente | Aggiunge indirizzo (`address` lowercase) alla rubrica. |
| `RemoveContact` | Utente | Rimuove contatto dalla rubrica per `address`. |
| `SearchPeople` | Utente | Cerca profili da aggiungere (`search_profiles`). |
| `StartChatFromContact` | Utente | Apre conversazione con `peer_address` del contatto. |

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `ContactListReady` | Rubrica dell'account in focus disponibile. |
| `ContactAdded` | Indirizzo aggiunto alla rubrica. |
| `ContactRemoved` | Indirizzo rimosso dalla rubrica. |
| `ChatFromContactStarted` | Conversazione avviata da rubrica con `peer_address`. |
| `ChatFromContactRejected` | Contatto non idoneo per chat diretta (solo casi di validazione indirizzo). |

---

## Policy

| Policy | Descrizione |
|--------|-------------|
| **Rubrica isolata dall'inbox** | Contatti non implicano messaggi ricevuti. |
| **Chat da qualsiasi contatto** | Compose da rubrica con `peer_address` — locale e federato, stessa UI. |
| **Scope per account** | Rubrica dell'account in focus. |
| **Reload dopo CRUD** | `ContactAdded` / `ContactRemoved` non sono eventi espliciti dello statechart — `Add*` / `Remove*` innescano `LoadContacts` → `ContactsLoaded`. |
| **Compose fuori ContactsMachine** | `StartChatFromContact` e gli esiti `ChatFromContactStarted` / `ChatFromContactRejected` sono gestiti in UI + navigation, non in [ContactsMachine]. |
| **Vincoli CRUD a valle** | `ContactsMachine` non replica guardie reception (self-add, duplicati): vincoli su DB (`contacts` unique su `address`) e UI. |
| **Presentazione separata** | Nome/avatar via `get_profiles` — rubrica **non** è cache profilo. |
