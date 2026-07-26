# Comandi ed eventi — contesto auth

**Ultima revisione:** 2026-07-27  
**UML:** [docs/model/uml/auth/](../../model/uml/auth/)

---

## Comandi

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `SignIn` | Utente | Accede con credenziali esistenti. |
| `SignUp` | Utente | Registra un nuovo account. |
| `RequestPasswordReset` | Utente | Richiede recupero password. |
| `ShowCredentialOverlay` | Policy / Utente | Mostra overlay login o registrazione. |
| `DismissCredentialOverlay` | Utente | Chiude overlay quando consentito. |

---

## Eventi (`AuthMachine`)

Nomi allineati a `client/lib/machines/auth/auth_machine.dart` e ai diagrammi UML.

| Evento | Descrizione |
|--------|-------------|
| `BootstrapStarted` | Avvio bootstrap overlay auth. |
| `BootstrapCompleted` | Manifest caricato; `hasOpenAccounts` → `SessionActive`, altrimenti `NoSession`. |
| `OverlayOpenRequested` | Mostra overlay (`dismissible` → `OverlayVisible`, altrimenti `NoSession`). |
| `OverlayCloseRequested` | Chiude overlay dismissibile → `SessionActive`. |
| `LastAccountRemoved` | Ultimo account chiuso → `NoSession` obbligatorio. |
| `ValidationRejected` | Validazione locale fallita; resta nello stato precedente (non entra in `AuthOperationInProgress`). |
| `AuthOperationStarted` | Login o sign-up avviato → `AuthOperationInProgress`. |
| `AuthOperationCompleted` | Success → `SessionActive`; `success: false` ripristina stato pre-operazione. |
| `AuthOperationFailed` | Errore credenziali, rete o server; ripristina stato pre-operazione. |

`RequestPasswordReset` non emette eventi `AuthMachine` (solo loading ed errore UI).

---

## Policy

| Policy | Descrizione |
|--------|-------------|
| **Shell sempre visibile** | Auth in overlay, mai schermata piena dedicata. |
| **Overlay obbligatorio senza account** | Zero account → overlay non chiudibile. |
| **Validazione prima della rete** | Dati invalidi non partono verso il server. |
