# Archivio messaggi conversazione — design

**Stato:** `implemented`  
**Ultima revisione:** 2026-07-27  
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

## Ingresso chat — consolidamento sessione (SCOPE-008)

All'ingresso (`OpenConversation` / `OpenPeerOnFocusedAccount`), **prima** di `commitScope` e fetch:

1. Account UI = fonte di verità (non fidarsi di «sessione già in RAM»).
2. Rimuovere sessioni spurie in RAM (altri account).
3. Se JWT assente o `auth.uid` ≠ account UI → `restore` GoTrue da storage.
4. Solo sessione pronta → `commitScope` → fetch `list_peer_messages`.

UML: `docs/model/uml/navigation/seq-open-conversation-unified.puml`

Test hub: `client/test/unit/conversation_open_session_test.dart`

## Invalidazione forte (`loadSeq++`)

Switch account, cambio peer, chiusura chat, epoch sessione ricreata.

## Fuori scope v1

Gruppi (`GroupMessagesController`).
