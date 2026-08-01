# Archivio messaggi conversazione — design

**Stato:** `implemented`  
**Ultima revisione:** 2026-08-01  
**Promessa:** [PROM-CONVERSATION-SCOPE](../../specs/promises/product/PROM-CONVERSATION-SCOPE.md)

## Scopo

Refactoring del layer lista messaggi chat 1:1: **un modulo**, **un'identità** (`ConversationScope` + `loadSeq`), ciclo di vita esplicito.

## Componenti

| Nome | File | Ruolo |
|------|------|--------|
| **Archivio messaggi** | `client/lib/machines/messaging/conversation_message_store.dart` | Unica mutazione lista DM |
| **Chiave conversazione** | `client/lib/models/conversation_scope.dart` | `ownerUserId`, `peerProfileId`, `sessionEpoch`, `loadSeq` |
| **Navigazione** | `navigation_machine.dart` | `commitScope` / `invalidateCommittedScope` / `reconcileSessionEpoch` |
| **Consolidamento sessione** | `account_manager.dart` | `consolidateSessionForAccount` — GoTrue allineato all'account UI |

## Regole

- **R1–R6:** test `conversation_message_store_test.dart`, `multi_account_message_store_test.dart` (INV-R4 `prova-out`).
- Lista vuota in `Loading`; apply/merge solo se scope commesso coincide.
- `isConversationReady` senza side-effect; epoch via `reconcileSessionEpoch`.
- Nessun `isScopeCommitted ?? true`.

## Ingresso chat — due fasi (SCOPE-008 / PROM-CONVERSATION-SCOPE-009)

### Fase A — ingresso UI (sincrona)

1. `OpenChat` in view-state + shell `ChatOpen`.
2. `CommitConversationScope` se sessione in RAM coerente.
3. Notify UI → header peer + spinner nel pannello chat.

### Fase B — piano dati (asincrona, abortibile)

1. `ConsolidateSession` se necessario (JWT + `auth.uid`).
2. Re-commit scope se epoch cambia; abort se `loadSeq` incrementato o peer diverso.
3. `LoadMessages` (messaging) — già con generation guard.
4. `refreshFocusedInbox(silent)` — **non** blocca navigazione, **non** `isLoading` inbox.

Consolidamento **obbligatorio prima di fetch/send**, non prima della shell chat.

UML: `docs/model/uml/navigation/seq-open-conversation-unified.puml`

Test hub: `client/test/unit/conversation_open_session_test.dart`; `client/test/wiring/navigation_open_ingress_test.dart`; `client/test/widget/conversation_scope_ingress_test.dart`

## Invalidazione forte (`loadSeq++`)

Switch account, cambio peer, chiusura chat, epoch sessione ricreata.

## Fuori scope v1

Gruppi (`GroupMessagesController`).
