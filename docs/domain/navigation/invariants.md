# Invarianti — navigation (sessione conversazione)

**Bounded context:** `navigation`  
**Implementazione:** `client/lib/utils/conversation_session_access.dart`  
**Confine prodotto:** [PROM-CONVERSATION-SCOPE-008](../../specs/promises/product/PROM-CONVERSATION-SCOPE.md)

---

## Session identity (messaggistica 1:1)

Per una conversazione commessa con owner `O` e peer `P`:

1. JWT GoTrue presente sul client dell'account `O`
2. `auth.uid() == O`
3. `P != auth.uid()`

Vale **all'ingresso** (`OpenConversation` / consolidate) e **per tutta la durata** dello scope commesso (UI chat, fetch, invio, upload).

Se l'invariante fallisce: nessuna RPC/upload; l'utente vede «Sessione scaduta — accedi di nuovo» (mai errore RPC grezzo).

---

## Account session (senza peer)

Per operazioni sull'account `O` senza peer (inbox, focus, consolidate):

1. JWT presente
2. `auth.uid() == O`

Sottoinsieme di session identity — senza il vincolo su `P`.

---

## No stale chat

`OpenConversation` (inbox, push, link, compose) **sostituisce** la chat precedente:

1. Se il peer richiesto ≠ peer in view-state, la chat stale non resta commessa.
2. Peer irrisolvibile → inbox/home, scope non commesso.
3. Switch account senza `OpenConversation` → view-state può conservare `activePeer` ma **scope non commesso** (nessun fetch/send).
