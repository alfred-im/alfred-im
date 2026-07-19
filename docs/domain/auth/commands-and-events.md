# Comandi ed eventi — contesto auth

**Ultima revisione:** 2026-07-19  
**UML:** [docs/model/uml/auth/](../../model/uml/auth/)

---

## Comandi (intento)

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `BootstrapStarted` | Policy (avvio app) | Inizia caricamento manifest e ripristino focus. |
| `BootstrapCompleted` | Policy (fine bootstrap) | Determina se esiste almeno un account aperto. |
| `OverlayOpenRequested` | Utente / Policy | Mostra overlay credenziali (aggiungi account o primo accesso). |
| `OverlayCloseRequested` | Utente | Chiude overlay quando consentito. |
| `SignInRequested` | Utente | Accesso con email e password. |
| `SignUpRequested` | Utente | Registrazione nuovo account. |
| `ResetPasswordRequested` | Utente | Richiesta recupero password. |
| `LastAccountRemoved` | Policy (ultimo account chiuso) | Nessun account aperto — overlay obbligatorio. |

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `BootstrapReady` | App pronta; sessione utilizzabile o overlay impostato. |
| `OverlayMandatoryShown` | Zero account — overlay non dismissibile. |
| `OverlayDismissibleShown` | Aggiunta account — overlay chiudibile. |
| `OverlayClosed` | Overlay nascosto; shell invariata. |
| `OverlayCloseBlocked` | Tentativo chiusura con zero account — ignorato. |
| `AuthOperationStarted` | Operazione credenziali in corso. |
| `AuthOperationCompleted` | Operazione riuscita. |
| `AuthOperationFailed` | Operazione fallita; errore user-friendly. |
| `SessionEstablished` | Account nel manifest con focus; overlay chiuso dopo login/sign-up. |
| `ValidationRejected` | Dati non validi — nessuna chiamata rete. |

---

## Policy

| Policy | Trigger | Azione |
|--------|---------|--------|
| **Overlay obbligatorio** | Zero account | Overlay non dismissibile ([SURF-AUTH-002]). |
| **Overlay dismissibile** | ≥1 account, aggiunta account | Overlay chiudibile ([SURF-AUTH-003]). |
| **Shell sempre visibile** | Qualsiasi stato auth | Nessuna route full-screen auth ([SURF-AUTH-001]). |
| **Validazione pre-rete** | `SignIn*` / `SignUp*` | `ValidationRejected` se dati invalidi. |
| **Chiusura post successo** | Login/sign-up ok | Overlay chiuso ([SURF-AUTH-007]). |

---

## Tracciabilità SDD

| Elemento | Promessa |
|----------|----------|
| Overlay obbligatorio 0 account | SURF-AUTH-002 |
| Overlay dismissibile add-account | SURF-AUTH-003 |
| Card login + registrazione | SURF-AUTH-004 |
| Chiusura post login/sign-up | SURF-AUTH-007 |
| Redirect email/reset | SURF-AUTH-008 |
| Ultimo account rimosso | SURF-AUTH-005 |
| Tipo account user/group | SURF-AUTH-006 |
