# Glossario — contesto auth

**Bounded context:** `auth`  
**Ultima revisione:** 2026-07-19  
**Promesse SDD:** [SURF-AUTH](../../specs/surfaces/SURF-AUTH.md), [PROM-MULTI-ACCOUNT](../../specs/promises/product/PROM-MULTI-ACCOUNT.md)

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Auth overlay** | Strato credenziali sopra la shell — mai sostituisce la shell. |
| **Bootstrapping** | Fase avvio app: caricamento manifest e ripristino focus prima di `sessionReady`. |
| **Session restore** | Ripristino sessione GoTrue per account da persistenza locale o refresh token. |
| **Ephemeral bootstrap** | Client auth effimero per login/sign-up/reset — nessuna persistenza sessione sul client bootstrap. |
| **Session adoption** | Trasferimento sessione dal client bootstrap al client dedicato dell'account. |
| **NoSession** | Zero account nel manifest: overlay obbligatorio e non dismissibile ([SURF-AUTH-002]). |
| **SessionActive** | Almeno un account aperto e overlay nascosto — shell utilizzabile. |
| **OverlayVisible** | Overlay mostrato con account già aperti (es. aggiungi account), dismissibile ([SURF-AUTH-003]). |
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

1. La shell resta sempre montata — overlay è uno strato, non una route ([SURF-AUTH-001]).
2. Con 0 account l'overlay **non** è dismissibile ([SURF-AUTH-002], [SURF-AUTH-011]).
3. Dopo session adoption **non** revocare il refresh token appena adottato.
4. Ogni account persistito usa storage auth dedicato per account.
5. Validazione client-side (email, username, display name) prima di chiamate rete.
