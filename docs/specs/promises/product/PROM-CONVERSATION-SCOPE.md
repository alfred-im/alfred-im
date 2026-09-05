# PROM-CONVERSATION-SCOPE — Ambito unico conversazione attiva

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-CONVERSATION-SCOPE` |
| **Classe** | PRODUCT |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-08-01 |

[NavigationMachine](../../../../client/lib/machines/navigation/navigation_machine.dart) possiede l'unico `ConversationScope` commesso. `activePeer` in view-state è proiezione UI. Messaging legge solo scope commesso.

**Dominio (invarianti):** [invariants.md](../../../domain/navigation/invariants.md)  
**Implementazione:** [conversation_session_access.dart](../../../../client/lib/utils/conversation_session_access.dart)  
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
| **PROM-CONVERSATION-SCOPE-008** | **Session identity** per conversazione commessa: regole in [invariants.md](../../../domain/navigation/invariants.md); consolidate **prima di fetch/send/upload** (non prima della shell chat); UI/fetch/send/upload bloccati se l'invariante fallisce; messaggio utente «Sessione scaduta — accedi di nuovo» |
| **PROM-CONVERSATION-SCOPE-009** | Su `OpenConversation`, la transizione shell verso chat (`ConversationVisible`: header del peer + indicatore caricamento) avviene **sincronamente** al tap/intento, **prima** di I/O async non necessario alla risoluzione immediata del peer |
| **PROM-CONVERSATION-SCOPE-010** | `OpenConversation` **non** attende `refreshFocusedInbox` né altre operazioni inbox come prerequisito alla navigazione |
| **PROM-CONVERSATION-SCOPE-011** | Consolidazione sessione (se richiesta) e caricamento messaggi avvengono **dopo** l'ingresso UI; risultati ignorati se `loadSeq` cambia o scope invalidato (abort su `CloseConversation` / apertura altro peer) |
| **PROM-CONVERSATION-SCOPE-012** | Durante `OpenConversation` in corso, l'inbox **non** sostituisce il corpo lista con uno spinner globale mentre l'utente è ancora nella shell inbox |

---

## Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| PROM-CONVERSATION-SCOPE-001–004 | `client/test/unit/conversation_scope_test.dart` |
| PROM-CONVERSATION-SCOPE-005–006 | `client/test/widget/push_notification_listener_test.dart`; `client/test/composition/messaging_session_scope_test.dart`; `client/test/unit/messages_controller_scope_guard_test.dart`; `client/test/widget/push_tap_message_contract_test.dart`; `client/test/unit/multi_account_message_store_test.dart` (INV-R4); `client/e2e/release-snake.spec.ts` (`core.chat.*`, `core.push.poison`) |
| PROM-CONVERSATION-SCOPE-007 | `client/test/unit/navigation_machine_test.dart` |
| PROM-CONVERSATION-SCOPE-008 | `client/test/unit/conversation_session_access_test.dart`; `client/test/unit/conversation_open_session_test.dart`; `client/test/wiring/navigation_wiring_test.dart` |
| PROM-CONVERSATION-SCOPE-009–012 | `client/test/wiring/navigation_open_ingress_test.dart`; `client/test/widget/conversation_scope_ingress_test.dart`; `client/test/unit/conversation_open_session_test.dart`; `client/test/widget/inbox_panel_test.dart` |

Gate: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh`
