# Glossario — contesto navigation

**Bounded context:** `navigation`  
**Ultima revisione:** 2026-07-27  
**Promesse SDD:** [PROM-SHAREABLE-LINK](../../specs/promises/product/PROM-SHAREABLE-LINK.md), [PROM-MULTI-ACCOUNT](../../specs/promises/product/PROM-MULTI-ACCOUNT.md), [PROM-CONVERSATION-SCOPE](../../specs/promises/product/PROM-CONVERSATION-SCOPE.md)

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Shell** | Layout principale: sidebar + inbox + chat (sempre visibile). |
| **InboxVisible** | Area inbox mostrata (mobile o desktop) per account utente. |
| **ChatOpen** | Conversazione 1:1 aperta per account utente in focus (`NavigationShellState.chatOpen`). |
| **GroupShell** | Account gruppo in focus — home gruppo al posto dell'inbox classica. |
| **GroupHomeVisible** | Home gruppo (`GroupShell`, `groupChatOpen = false`). |
| **GroupConversationVisible** | Chat gruppo aperta (`GroupShell`, `groupChatOpen = true`). |
| **ConversationScope** | Ambito atomico commesso `(owner_user_id, peer_profile_id, session_epoch)` — unica autorità per messaging. |
| **CommitConversationScope** | Registra scope dopo apertura validata (account + peer + sessione viva). |
| **InvalidateConversationScope** | Azzera scope (chiusura chat, switch account, apertura verso altro peer). |
| **OpenConversation** | Transazione unica: invalida → focus (se serve) → **consolida sessione** → risolvi peer → commit scope. Sorgenti: inbox, push, link, compose. |
| **ConsolidateSession** | All'ingresso chat: vedi [invariants.md](invariants.md) § Session identity |
| **Profile fallback** | Se peer non in inbox, lookup profilo — link/compose sempre; push dopo retry inbox esteso. |
| **CloseConversation** | Chiude chat; invalida scope; torna a inbox (utente) o home gruppo (gruppo). |
| **Account view state** | Stato UI per account (`activePeer`, `showInboxOnMobile`, `groupChatOpen`) — proiezione, non autorità messaging. |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **multi-account** | `FocusAccount` = solo I/O sessione. `SwitchToAccount` (navigation) invalida scope e mostra inbox/home gruppo — **non** ripristina chat da view-state. |
| **notifications** | Tap notifica → adapter `openFromPushTap` → `OpenConversation(source=push)`. |
| **shareable-link** | Fragment `#…/chat` → adapter `openFromShareableLink` → `OpenConversation(source=shareableLink)`. |
| **contacts** | Compose da rubrica → adapter `openFromCompose` → `OpenConversation(source=compose)`. |

---

## Invarianti

Vedi [invariants.md](invariants.md) — implementazione in `client/lib/utils/conversation_session_access.dart`.

1. Un solo ingresso navigazione: `NavigationMachine`.
2. Push e link **non** bypassano multi-account.
3. Tap inbox su account già in focus: `OpenPeerOnFocusedAccount` (no switch account).
