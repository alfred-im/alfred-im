# Glossario — contesto multi-account

**Bounded context:** `multi-account`  
**Ultima revisione:** 2026-08-02  
**Promesse SDD:** [PROM-MULTI-ACCOUNT](../../specs/promises/product/PROM-MULTI-ACCOUNT.md), [SURF-AUTH](../../specs/surfaces/SURF-AUTH.md)

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Manifest** | Lista persistita account **aperti**, non bookmark. |
| **Focus** | Account attivo in UI — quale inbox/chat è visibile. |
| **Account aperto** | Voce nel manifest; sessione attiva solo con refresh token valido. |
| **Account session** | Connessione auth + servizi in RAM; **al massimo una** attiva. |
| **Switch focus** | Cambio account UI: dispose sessione corrente, restore nuova da manifest. |
| **Account view state** | Stato UI per account (chat aperta, inbox mobile) — persiste al cambio focus. |
| **Auth overlay** | Login/registrazione sopra shell, non full-screen. |
| **NoOpenAccounts** | Manifest vuoto; nessun account aperto. |
| **HasOpenAccounts** | Manifest non vuoto; sessione focus non ancora attiva. |
| **FocusSwitching** | Stato transitorio: dispose sessione precedente + restore nuovo focus. |
| **FocusedWithSession** | Focus persistito + sessione attiva in RAM. |
| **FocusedAwaitingSession** | Focus persistito ma restore sessione non riuscito (ritentabile con reconnect). |
| **SessionRestoreFailed** | Evento: restore sessione fallito dopo focus o switch. |
| **SessionAuthority** | Servizio di dominio — unico owner di JWT attivo, generazione identità, lease e coda switch. Vedi [session-authority.md](session-authority.md). |
| **Identity generation** | Contatore monotono emesso da SessionAuthority a ogni `IdentityActivated`; sostituisce concettualmente `sessionEpoch` su scope conversazione. |
| **Identity lease** | Blocco temporaneo allo switch verso altro owner (upload media, picker OS). |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **auth** | Login/signup crea account nel manifest. |
| **navigation** | Usa focus + sessione per inbox/chat. |
| **notifications** | Richiede account aperto + focus per tap push. |

---

## Invarianti

Vedi [invariants.md](invariants.md).

1. Una sola sessione auth attiva in RAM.
2. Account in sidebar = account nel manifest.
3. Cambio focus: dispose + restore.
4. Storage auth dedicato per ogni account.
