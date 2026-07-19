# Comandi ed eventi — contesto navigation

**Ultima revisione:** 2026-07-19  
**UML:** [docs/model/uml/navigation/](../../model/uml/navigation/)

---

## Comandi (intento)

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `SwitchToAccount` | Utente | Cambia account in focus (solo inbox, senza aprire chat). |
| `OpenPeerOnFocusedAccount` | Utente | Apre chat con peer su account già in focus. |
| `OpenConversationOnAccount` | Utente | Focus account + risolve peer + apre chat. |
| `OpenFromPushTap` | Policy (tap notifica) | Apre chat da push: clear stale, focus, retry inbox, fallback profilo. |
| `OpenFromShareableLink` | Policy (link condiviso) | Apre chat da fragment URL con clear stale e fallback profilo. |
| `OpenFromCompose` | Utente | Apre chat da compose (contatti, ricerca). |
| `CloseConversation` | Utente | Chiude chat aperta; torna a inbox o home gruppo. |
| `OpenGroupChat` | Utente | Apre conversazione gruppo (resta in shell gruppo). |
| `BackToGroupHome` | Utente | Torna al pannello home gruppo da chat gruppo. |

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `NavigationIdle` | Inbox visibile, nessuna chat aperta. |
| `ConversationOpened` | Chat 1:1 aperta con peer risolto. |
| `GroupShellEntered` | Account gruppo in focus — home gruppo visibile. |
| `GroupChatOpened` | Chat gruppo aperta dentro shell gruppo. |
| `NavigationRejected` | Peer non trovato, self-peer, account non aperto. |
| `AccountFocusRequired` | Delega `FocusAccount` a multi-account. |

---

## Policy

| Policy | Trigger | Azione |
|--------|---------|--------|
| **Un solo orchestratore** | Qualsiasi ingresso navigazione | Tutti i percorsi passano da `NavigationMachine`. |
| **Push/link non bypassano multi-account** | `OpenFromPushTap` / `OpenFromShareableLink` | `FocusAccount` se account destinatario ≠ focus. |
| **Clear stale chat** | Push/link con peer diverso da chat aperta | Chiude chat stale prima di aprire target. |
| **Fallback profilo** | Peer assente da inbox | Lookup profilo + apertura conversazione. |
| **Tap inbox su focus corrente** | `OpenPeerOnFocusedAccount` | Nessun switch account. |
| **Account gruppo** | `SwitchToAccount` su gruppo | Entra in `GroupShell` senza inbox classica. |

Transizioni shell: [navigation-shell-state.puml](../../model/uml/navigation/navigation-shell-state.puml).

---

## Tracciabilità SDD

| Elemento | Promessa |
|----------|----------|
| Shell sempre visibile | PROM-MULTI-ACCOUNT-001 |
| `OpenFromPushTap` | PROM-PUSH-NOTIFY-030/036 |
| `OpenFromShareableLink` | PROM-SHAREABLE-LINK-004 |
| `CloseConversation` | PROM-MULTI-ACCOUNT-010 (AccountViewState) |
| `GroupShell` | SURF-GROUP-SHELL |
