# Glossario — contesto multi-account

**Bounded context:** `multi-account`  
**Ultima revisione:** 2026-07-18  
**Promesse SDD:** [PROM-MULTI-ACCOUNT](../../specs/promises/product/PROM-MULTI-ACCOUNT.md), [SURF-AUTH](../../specs/surfaces/SURF-AUTH.md)

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Manifest** | Lista persistita `alfred_saved_accounts` — account **aperti**, non bookmark. |
| **Focus** | `alfred_focus_user_id` — quale account mostra inbox/chat in UI. |
| **Account aperto** | Voce nel manifest con refresh token valido. |
| **AccountSession** | Connessione GoTrue + servizi in RAM; **al massimo una** attiva. |
| **Switch focus** | Cambio account UI: dispose sessione corrente, restore nuova da manifest. |
| **AccountViewState** | Stato UI per `userId` (chat aperta, inbox mobile) — persiste al cambio focus. |
| **Auth overlay** | Login/registrazione sopra `HomeScreen`, non full-screen. |
| **Sessione mancante** | Manifest + focus impostati ma `focusedSession == null` (ripristino in corso o fallito). |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **auth** | Login/signup crea account nel manifest. |
| **navigation** | Usa focus + sessione per inbox/chat. |
| **notifications** | Richiede account aperto + focus per tap push. |

---

## Invarianti

1. Una sola `AccountSession` GoTrue attiva in RAM.
2. Account in sidebar = account nel manifest.
3. `setFocus` non usa `setSession` tra account già in RAM — dispose + restore.
4. Storage auth per account: `alfred_auth_{userId}`.
