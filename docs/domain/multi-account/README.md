# Contesto: multi-account

**Stato modellazione:** `verified`

**Invarianti:** [invariants.md](invariants.md)  
**Enforcement identità (target):** [session-authority.md](session-authority.md)

## Mapping dominio → implementazione

### Comandi

| Dominio | Statechart | Codice |
|---------|------------|--------|
| `FocusAccount` | `FocusAccount` | `MultiAccountAdapters.focusAccount` → `RequestFocusSwitch` (target: `SessionAuthority`) |
| `RunAsOwner` | — | Target: `SessionAuthority.runAsOwner` ← navigation, messaging, notifications |
| `AcquireIdentityLease` | — | Target: `SessionAuthority.acquireLease` ← messaging/media |
| `AuthorizePushSync` | — | Target: `SessionAuthority.authorizePushSync` ← notifications |
| `OpenAccount` | `OpenAccountWithPassword` / `OpenAccountWithSignUp` | `MultiAccountAdapters` → `AccountManager` |
| `CloseAccount` | `CloseAccount` | `MultiAccountAdapters.closeAccount` → `AccountManager.removeAccount` |
| `ReconnectFocusedSession` | `ReconnectFocusedSession` | `MultiAccountAdapters.reconnectFocusedSession` |

### Eventi

| Dominio | Statechart | Codice |
|---------|------------|--------|
| `AccountFocused` | `AccountFocused` | dopo `executeFocus` con sessione |
| `AccountOpened` | `AccountOpened` | dopo login/signup su manifest |
| `AccountClosed` | `AccountClosed` | dopo `removeAccount` |
| `SessionRestoreFailed` | `SessionRestoreFailed` | focus senza sessione utilizzabile |

### Eventi bootstrap (statechart)

| Statechart | Codice |
|------------|--------|
| `ManifestLoaded` | `MultiAccountAdapters.bootstrapManifest` |
| `FocusActivationCompleted` | test/seed (`seed_multi_account_machine.dart`); produzione: `FocusAccount` post-bootstrap |

### Stati focus (UML ↔ `MultiAccountFocusState`)

| UML / glossario | `MultiAccountFocusState` |
|-----------------|--------------------------|
| `NoOpenAccounts` | `noOpenAccounts` |
| `HasOpenAccounts` | `hasOpenAccounts` |
| `FocusSwitching` | `focusSwitching` |
| `FocusedWithSession` | `focusedWithSession` |
| `FocusedAwaitingSession` | `focusedAwaitingSession` |

Statechart: `client/lib/machines/multi-account/` · Effetti oggi: `AccountManager` · **Target enforcement:** `SessionAuthority` (facade su AccountManager in migrazione) · Facade UI: `AuthController`

**UML SessionAuthority:** [session-authority-state.puml](../../model/uml/multi-account/session-authority-state.puml) · [seq-run-as-owner.puml](../../model/uml/multi-account/seq-run-as-owner.puml) · [seq-identity-lease-media.puml](../../model/uml/multi-account/seq-identity-lease-media.puml)
