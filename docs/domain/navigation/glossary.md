# Glossario — contesto navigation

**Bounded context:** `navigation`  
**Ultima revisione:** 2026-07-19  
**Promesse SDD:** [PROM-SHAREABLE-LINK](../../specs/promises/product/PROM-SHAREABLE-LINK.md), [PROM-MULTI-ACCOUNT](../../specs/promises/product/PROM-MULTI-ACCOUNT.md)

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Shell** | Layout principale: sidebar + inbox + chat (sempre visibile). |
| **InboxVisible** | Area inbox mostrata (mobile o desktop). |
| **ChatOpen** | Conversazione 1:1 o gruppo aperta per account in focus. |
| **ConversationScope** | Ambito atomico commesso `(owner_user_id, peer_profile_id, session_epoch)` — unica autorità per messaging. |
| **CommitConversationScope** | Registra scope dopo apertura validata (account + peer + sessione viva). |
| **InvalidateConversationScope** | Azzera scope (chiusura chat, switch account, apertura verso altro peer). |
| **OpenConversation** | Transazione unica: invalida → focus (se serve) → risolvi peer → commit scope. Sorgenti: inbox, push, link, compose. |
| **Profile fallback** | Se peer non in inbox, lookup profilo — link/compose sempre; push dopo retry inbox esteso. |
| **CloseConversation** | Chiude chat; invalida scope; torna a inbox o home gruppo. |
| **GroupShell** | Account gruppo in focus — home gruppo al posto dell'inbox classica. |
| **Account view state** | Stato UI per account (chat aperta, inbox mobile) — `activePeer` è proiezione, non autorità messaging. |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **multi-account** | `FocusAccount` = solo I/O sessione. `SwitchToAccount` (navigation) invalida scope e mostra inbox/home gruppo — **non** ripristina chat da view-state. |
| **notifications** | `OpenConversation(source=push)` — stessa transazione, policy push. |
| **shareable-link** | `OpenConversation(source=shareableLink)` — clear stale se peer diverso. |

---

## Invarianti

1. Un solo ingresso navigazione: `NavigationMachine`.
2. Push e link **non** bypassano multi-account.
3. Tap inbox su account già in focus: `OpenPeerOnFocusedAccount` (no switch account).
