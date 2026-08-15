# Invarianti — navigation (sessione conversazione)

**Bounded context:** `navigation`  
**Implementazione:** `client/lib/utils/conversation_session_access.dart`  
**Enforcement identità:** [multi-account/session-authority.md](../multi-account/session-authority.md) (`ensureFocusReady` prima di fetch/send/upload)  
**Confine prodotto:** [PROM-CONVERSATION-SCOPE](../../specs/promises/product/PROM-CONVERSATION-SCOPE.md) (promessa **PROM-CONVERSATION-SCOPE-008**)

---

## Session identity (messaggistica 1:1)

Per una conversazione commessa con archive_user `O` e peer `P`:

1. JWT GoTrue presente sul client dell'account `O`
2. `auth.uid() == O`
3. `P != auth.uid()`

Vale **prima di fetch/send/upload** su conversazione commessa. L'ingresso UI può precedere consolidate; i messaggi compaiono solo dopo `SessionAuthority.ensureFocusReady` riuscito e `LoadMessages`.

UML: [seq-run-as-focus.puml](../../model/uml/multi-account/seq-run-as-focus.puml) (target `runAsFocus`; oggi `ensureFocusReady`).

Se l'invariante fallisce: nessuna RPC/upload; l'utente vede «Sessione scaduta — accedi di nuovo» (mai errore RPC grezzo).

---

## Account session (senza peer)

Per operazioni sull'account `O` senza peer (inbox, focus, consolidate):

1. JWT presente
2. `auth.uid() == O`

Sottoinsieme di session identity — senza il vincolo su `P`.

---

## No stale chat

`OpenConversation` (inbox via `OpenPeerOnFocusedAccount`, push, link, compose via `OpenConversationOnAccount`) **sostituisce** la chat precedente:

1. Se il peer richiesto ≠ peer in view-state, la chat stale non resta commessa (`ConversationScopeInvalidated`).
2. Peer irrisolvibile → inbox/home (`NavigationFailed`), scope non commesso.
3. `SwitchToAccount` (`ShowInbox` / `EnterGroupShell`) senza `OpenConversation` → view-state può conservare `activePeer` ma **scope non commesso** (nessun fetch/send).

---

## Scope e shell

1. Solo `NavigationMachine.commitScope` registra `ConversationScope`; `invalidateCommittedScope` lo azzera.
2. `ChatOpen` implica shell conversazione 1:1 visibile; `committedScope` può essere `null` durante ingresso (fase A) finché consolidate non commette scope. `InboxVisible` e `GroupShell` implicano scope `null`.
3. Chat gruppo: shell `GroupShell` con `groupChatOpen` in view-state — nessun `ConversationScope` 1:1.
