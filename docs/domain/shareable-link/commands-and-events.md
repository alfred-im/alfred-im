# Comandi ed eventi — contesto shareable-link

**Ultima revisione:** 2026-07-27  
**UML:** [docs/model/uml/shareable-link/](../../model/uml/shareable-link/)

---

## Comandi

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `ResolveSharedLink` | Policy (URL / fragment) | Legge e normalizza il fragment; ignora fragment riservati push. |
| `HandleSharedLinkTarget` | Policy (sessione pronta) | Risolve il target in coda e delega apertura profilo o chat. |
| `OpenSharedChat` | ShareableLinkMachine | Apre chat da link condiviso — delega a navigation (`OpenFromShareableLink`). |
| `OpenSharedProfile` | ShareableLinkMachine | Mostra scheda profilo peer da link condiviso. |
| `DismissSharedLinkNotFound` | Utente | Chiude schermata risorsa non trovata e ripulisce il fragment. |

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `SharedLinkPending` | Target in attesa di sessione o account. |
| `SharedLinkInvalid` | Indirizzo non riconoscibile dopo lookup o profilo assente. |
| `SharedChatOpened` | Chat aperta da link. |
| `SharedProfileShown` | Profilo mostrato da link. |

---

## Policy

| Policy | Descrizione |
|--------|-------------|
| **Attendi autenticazione** | Senza account o sessione non pronta, target resta in coda (`SharedLinkPending`). |
| **Nessuna chat stale** | Link chat chiude conversazione su altro peer (navigation). |
| **Self ignorato** | Link al proprio profilo non apre chat con sé stessi — torna a `Idle` senza errore. |
| **Fragment non valido** | Sintassi non parsabile o riservata (es. `push-chat/`) → `Idle`, nessuna UI errore. |
