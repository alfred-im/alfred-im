# PROM-CONVERSATION-SCOPE — Ambito unico conversazione attiva

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-CONVERSATION-SCOPE` |
| **Classe** | PRODUCT |
| **Status** | `approved` |
| **Ultima revisione** | 2026-07-21 |

[NavigationMachine](../../client/lib/machines/navigation/navigation_machine.dart) possiede l'unico `ConversationScope` commesso. `activePeer` in view-state è proiezione UI. Messaging legge solo scope commesso.

**UML:** `docs/model/uml/navigation/navigation-shell-state.puml`, `seq-open-conversation-unified.puml`

---

## Promesse

| ID | Promessa |
|----|----------|
| **PROM-CONVERSATION-SCOPE-001** | `ConversationScope` identifica account + peer + generazione sessione GoTrue (cambia su restore/dispose, non su token refresh) |
| **PROM-CONVERSATION-SCOPE-002** | Solo `NavigationMachine.commitScope` registra ambito se la sessione in RAM corrisponde |
| **PROM-CONVERSATION-SCOPE-003** | `InvalidateConversationScope` su chiusura chat, switch account, apertura verso altro peer |
| **PROM-CONVERSATION-SCOPE-004** | Dopo `SwitchToAccount` / bootstrap / reconnect: **inbox** (o home gruppo), scope **non** commesso; nessun restore implicito da `activePeer` |
| **PROM-CONVERSATION-SCOPE-005** | UI chat e `MessagesController` non mostrano messaggi se scope non commesso e coerente |
| **PROM-CONVERSATION-SCOPE-006** | Fetch/realtime ignorano risultati se scope non più attivo (generation guard) |
| **PROM-CONVERSATION-SCOPE-007** | Inbox, push, link, compose usano la stessa transazione `OpenConversation` con `OpenConversationSource` |

---

## Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| PROM-CONVERSATION-SCOPE-001–004 | `client/test/unit/conversation_scope_test.dart` |
| PROM-CONVERSATION-SCOPE-005–006 | `client/test/widget/push_notification_listener_test.dart`; `client/test/composition/messaging_session_scope_test.dart`; `client/test/unit/messages_controller_scope_guard_test.dart`; `client/test/widget/push_tap_message_contract_test.dart`; `client/e2e/inbox-open-chat.spec.ts`; `client/e2e/manual-push-poison-repro.spec.ts` |
| PROM-CONVERSATION-SCOPE-007 | `client/test/unit/navigation_machine_test.dart` |

Gate: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh`
