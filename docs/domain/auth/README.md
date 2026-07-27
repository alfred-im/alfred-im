# Contesto: auth

**Stato modellazione:** `verified`

**Invarianti:** [invariants.md](invariants.md)

## Mapping dominio → implementazione

### Comandi utente

| Comando dominio | Eventi `AuthMachine` | Codice |
|-----------------|----------------------|--------|
| `SignIn` | `ValidationRejected` o `AuthOperationStarted` → `AuthOperationCompleted` / `AuthOperationFailed` | `AuthSessionCoordinator.signIn` → `MultiAccountMachine.OpenAccountWithPassword` |
| `SignUp` | come `SignIn` | `AuthSessionCoordinator.signUp` → `OpenAccountWithSignUp` |
| `RequestPasswordReset` | — (nessun evento macchina) | `AuthSessionCoordinator.resetPassword` → `AccountManager.resetPassword` |
| `ShowCredentialOverlay` | `OverlayOpenRequested` | `AuthSessionCoordinator.openAuthOverlay` |
| `DismissCredentialOverlay` | `OverlayCloseRequested` | `AuthSessionCoordinator.closeAuthOverlay` |

### Bootstrap e cross-contesto

| Evento | `AuthMachine` | Codice |
|--------|---------------|--------|
| `BootstrapStarted` | `BootstrapStarted` | `AuthSessionCoordinator.initialize` |
| `BootstrapCompleted` | `BootstrapCompleted` | dopo `MultiAccountAdapters.bootstrapManifest` |
| `NoOpenAccounts` (stato multi-account) | `LastAccountRemoved` | `AuthSessionCoordinator.removeAccount` se manifest vuoto — **non** è evento auth |

### Stati UI (UML ↔ `AuthUiState`)

| UML / glossario | `AuthUiState` |
|-----------------|---------------|
| `Bootstrapping` | `bootstrapping` |
| `NoSession` | `noSession` |
| `SessionActive` | `sessionActive` |
| `OverlayVisible` | `overlayVisible` |
| `AuthOperationInProgress` | `authOperationInProgress` |

Statechart: `client/lib/machines/auth/` · Facade: `AuthController` + `AuthSessionCoordinator`
