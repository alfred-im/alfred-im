# Comandi ed eventi — contesto navigation

**Ultima revisione:** 2026-07-18  
**UML:** [docs/model/uml/navigation/](../../model/uml/navigation/)

---

## Comandi

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `SwitchToAccount` | Sidebar | Solo focus + inbox (no chat). |
| `OpenPeerOnFocusedAccount` | Tap riga inbox / contatto | Chat su account già in focus. |
| `OpenConversationOnAccount` | Push, link, compose | Focus + resolve peer + open chat. |
| `OpenFromPushTap` | Adapter notifications | `openConversationFromPushTap`: clear stale, focus, retry inbox, fallback profilo. |
| `OpenFromShareableLink` | Adapter shareable-link | `OpenConversationOnAccount`, fallback consentito. |
| `CloseConversation` | Back mobile / chiudi chat | Torna a inbox (AccountViewState). |

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `NavigationIdle` | Inbox visibile, nessuna chat. |
| `ConversationOpened` | Chat aperta con peer risolto. |
| `NavigationRejected` | Peer non trovato, self-peer, account non aperto. |
| `AccountFocusRequired` | Delega `FocusAccount` a multi-account. |

---

## Tracciabilità SDD

| Elemento | Promessa |
|----------|----------|
| Shell sempre visibile | PROM-MULTI-ACCOUNT-001 |
| `OpenFromPushTap` | PROM-PUSH-NOTIFY-030/036, seq-notification-click |
| Link fragment | PROM-SHAREABLE-LINK |
