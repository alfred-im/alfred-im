# Contesto: multi-account

**Stato modellazione:** `verified`

**Invarianti:** [invariants.md](invariants.md)

## Mapping dominio → implementazione

### Comandi

| Dominio | Statechart | Codice |
|---------|------------|--------|
| `FocusAccount` | `FocusAccount` | `MultiAccountAdapters.focusAccount` ← `NavigationMachine.SwitchToAccount` |
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

Statechart: `client/lib/machines/multi-account/` · Effetti: `AccountManager` · Facade: `AuthController`
