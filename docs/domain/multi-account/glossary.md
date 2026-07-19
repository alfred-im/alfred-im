# Glossario — contesto multi-account

**Bounded context:** `multi-account`  
**Ultima revisione:** 2026-07-19  
**Promesse SDD:** [PROM-MULTI-ACCOUNT](../../specs/promises/product/PROM-MULTI-ACCOUNT.md), [SURF-AUTH](../../specs/surfaces/SURF-AUTH.md)

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Manifest** | Lista persistita account **aperti**, non bookmark. |
| **Focus** | Account attivo in UI — quale inbox/chat è visibile. |
| **Account aperto** | Voce nel manifest con refresh token valido. |
| **Account session** | Connessione auth + servizi in RAM; **al massimo una** attiva. |
| **Switch focus** | Cambio account UI: dispose sessione corrente, restore nuova da manifest. |
| **Account view state** | Stato UI per account (chat aperta, inbox mobile) — persiste al cambio focus. |
| **Auth overlay** | Login/registrazione sopra shell, non full-screen. |
| **Sessione mancante** | Manifest + focus impostati ma sessione assente (ripristino in corso o fallito). |
| **HasOpenAccounts** | Manifest non vuoto, sessione focus non ancora attiva. |
| **FocusSwitching** | Stato transitorio: dispose sessione precedente + restore nuovo focus. |
| **FocusedWithSession** | Focus persistito + sessione attiva in RAM. |
| **FocusedAwaitingSession** | Focus persistito ma restore sessione non riuscito (ritentabile con reconnect). |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **auth** | Login/signup crea account nel manifest. |
| **navigation** | Usa focus + sessione per inbox/chat. |
| **notifications** | Richiede account aperto + focus per tap push. |

---

## Invarianti

1. Una sola sessione auth attiva in RAM.
2. Account in sidebar = account nel manifest.
3. Cambio focus: dispose + restore — non scambio sessione in RAM tra account già aperti.
4. Storage auth dedicato per ogni account.
