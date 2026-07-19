# Contesto: auth

**Stato modellazione:** `verified`

## Mapping dominio → implementazione

### Comandi ed eventi

| Dominio | Statechart | Codice |
|---------|------------|--------|
| `SignIn` | `SignInRequested` | `AuthMachine` + `OpenAccountWithPassword` |
| `SignUp` | `SignUpRequested` | `AuthMachine` + `OpenAccountWithSignUp` |
| `RequestPasswordReset` | `ResetPasswordRequested` | GoTrue reset |
| `ShowCredentialOverlay` | `OverlayOpenRequested` | overlay auth |
| `DismissCredentialOverlay` | `OverlayCloseRequested` | chiusura se ≥1 account |
| `SessionEstablished` | `AuthOperationCompleted(success)` | focus + overlay chiuso |

### Stati UI (UML ↔ `AuthUiState`)

| UML / glossario | `AuthUiState` |
|-----------------|---------------|
| `Bootstrapping` | `bootstrapping` |
| `NoSession` | `noSession` |
| `SessionActive` | `sessionActive` |
| `OverlayVisible` | `overlayVisible` |
| `AuthOperationInProgress` | `authOperationInProgress` |

Statechart: `client/lib/machines/auth/` · Facade: `AuthController`
