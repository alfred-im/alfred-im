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
| **OpenConversationOnAccount** | Focus account + risolvi peer in inbox + apri chat. |
| **Profile fallback** | Se peer non in inbox, lookup profilo — link/compose sempre; tap push solo dopo recapito server. |
| **OpenFromPushTap** | Tap notifica: azzera chat stale sull'account destinatario, retry inbox, poi fallback profilo se necessario. |
| **CloseConversation** | Chiude chat; torna a inbox o home gruppo. |
| **GroupShell** | Account gruppo in focus — home gruppo al posto dell'inbox classica. |
| **Account view state** | Stato UI per account (chat aperta, inbox mobile) — persiste al cambio focus. |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **multi-account** | `FocusAccount` prima di aprire chat su altro account. |
| **notifications** | `OpenFromPushTap` — percorso dedicato con clear stale + retry + fallback profilo. |
| **shareable-link** | `OpenFromShareableLink` — clear stale se peer diverso, fallback profilo. |

---

## Invarianti

1. Un solo ingresso navigazione: `NavigationMachine`.
2. Push e link **non** bypassano multi-account.
3. Tap inbox su account già in focus: `OpenPeerOnFocusedAccount` (no switch account).
