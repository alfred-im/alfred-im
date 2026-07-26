# Comandi ed eventi — contesto contacts

**Ultima revisione:** 2026-07-27  
**UML:** [docs/model/uml/contacts/](../../model/uml/contacts/)

---

## Comandi

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `AddContact` | Utente | Aggiunge persona alla rubrica (interna o esterna). |
| `RemoveContact` | Utente | Rimuove contatto dalla rubrica. |
| `SearchPeople` | Utente | Cerca profili o contatti da aggiungere. |
| `StartChatFromContact` | Utente | Apre conversazione da un contatto interno. |

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `ContactListReady` | Rubrica dell'account in focus disponibile. |
| `ContactAdded` | Persona aggiunta alla rubrica. |
| `ContactRemoved` | Persona rimossa dalla rubrica. |
| `ChatFromContactStarted` | Conversazione avviata da rubrica. |
| `ChatFromContactRejected` | Contatto non idoneo per chat diretta. |

---

## Policy

| Policy | Descrizione |
|--------|-------------|
| **Rubrica isolata dall'inbox** | Contatti non implicano messaggi ricevuti. |
| **Chat solo da contatto interno** | Contatti esterni non avviano conversazione Alfred. |
| **Scope per account** | Rubrica dell'account in focus. |
| **Reload dopo CRUD** | `ContactAdded` / `ContactRemoved` non sono eventi espliciti dello statechart — `Add*` / `Remove*` innescano `LoadContacts` → `ContactsLoaded`. |
| **Compose fuori ContactsMachine** | `StartChatFromContact` e gli esiti `ChatFromContactStarted` / `ChatFromContactRejected` sono gestiti in UI + navigation, non in [ContactsMachine]. |
