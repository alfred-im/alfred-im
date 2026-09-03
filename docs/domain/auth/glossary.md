# Glossario — contesto auth

**Bounded context:** `auth`  
**Ultima revisione:** 2026-07-27  
**Promesse SDD:** [SURF-AUTH](../../specs/surfaces/SURF-AUTH.md), [PROM-MULTI-ACCOUNT](../../specs/promises/product/PROM-MULTI-ACCOUNT.md)

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Auth overlay** | Strato credenziali sopra la shell — mai sostituisce la shell. |
| **Bootstrapping** | Fase avvio app: caricamento manifest, ripristino focus, `sessionReady`; inbox carica in background dopo `sessionReady` (non blocca la shell). |
| **Session restore** | Ripristino sessione GoTrue per account da persistenza locale o refresh token. |
| **Ephemeral bootstrap** | Client auth effimero per login/sign-up/reset — nessuna persistenza sessione sul client bootstrap. |
| **Session adoption** | Trasferimento sessione dal client bootstrap al client dedicato dell'account. |
| **NoSession** | Zero account nel manifest: overlay obbligatorio e non dismissibile ([SURF-AUTH-002]). |
| **SessionActive** | Almeno un account aperto e overlay nascosto — shell utilizzabile. |
| **OverlayVisible** | Overlay mostrato con account già aperti (es. aggiungi account), dismissibile ([SURF-AUTH-003]). |
| **AuthOperationInProgress** | Login o sign-up in corso verso il server — overlay in loading. |
| **Auth operation** | Login, registrazione o reset password in corso. |
| **Auth redirect URL** | URL redirect per conferma email e reset password. |
| **Friendly auth error** | Messaggio utente derivato da errore auth (credenziali, sessione scaduta, username occupato, …). |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **multi-account** | Login/sign-up crea voce manifest; chiusura ultimo account → `NoSession`. |
| **navigation** | Shell sempre visibile sotto overlay — nessun routing auth full-screen. |
| **shareable-link** | Con 0 account: overlay obbligatorio; dopo primo login si apre risorsa linkata. |
| **notifications** | Sync subscription dopo bootstrap e login/sign-up riusciti. |

---

## Invarianti

Vedi [invariants.md](invariants.md). Overlay e shell: [SURF-AUTH-001], [SURF-AUTH-002].
