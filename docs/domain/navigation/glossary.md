# Glossario — contesto navigation

**Bounded context:** `navigation`  
**Ultima revisione:** 2026-07-18  
**Promesse SDD:** [PROM-SHAREABLE-LINK](../../specs/promises/product/PROM-SHAREABLE-LINK.md), [PROM-MULTI-ACCOUNT](../../specs/promises/product/PROM-MULTI-ACCOUNT.md)

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Shell** | `HomeScreen` — sidebar + inbox + chat (sempre visibile). |
| **InboxVisible** | Area inbox mostrata (mobile o desktop). |
| **ChatOpen** | Conversazione 1:1 o gruppo aperta per account in focus. |
| **OpenConversationOnAccount** | Focus account + risolvi peer in inbox + apri chat. |
| **allowProfileFallback** | Se peer non in inbox, lookup profilo — link/compose sempre; tap push solo dopo recapito (`peer_profile_id` server). |
| **OpenFromPushTap** | Tap notifica: azzera chat stale sull'account destinatario, retry inbox, poi fallback profilo se necessario. |
| **Adapter** | Ingresso esterno che traduce in comando navigation (`OpenFromPushTap`, `OpenFromShareableLink`). |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **multi-account** | `FocusAccount` prima di aprire chat su altro account. |
| **notifications** | `OpenFromPushTap` → percorso dedicato `openConversationFromPushTap` (clear stale + retry + fallback profilo). |
| **shareable-link** | `OpenFromShareableLink` → `openConversationOnAccount` (clear stale se peer diverso, fallback profilo). |

---

## Invarianti

1. Un solo ingresso navigazione: `NavigationMachine` (implementazione di `NavigationCoordinator`).
2. Push e link **non** chiamano `AccountManager` direttamente.
3. Tap inbox su account già in focus: `OpenPeerOnFocusedAccount` (no switch account).
