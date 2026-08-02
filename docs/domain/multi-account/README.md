# Contesto: multi-account

**Stato modellazione:** `verified`

**Invarianti:** [invariants.md](invariants.md)  
**Enforcement identità:** [session-authority.md](session-authority.md)

## Mapping dominio → implementazione

### Comandi

| Dominio | Statechart | Codice |
|---------|------------|--------|
| `FocusAccount` | `FocusAccount` | `MultiAccountAdapters` → `SessionAuthority.requestFocusSwitch` |
| `EnsureOwnerReady` | — | `SessionAuthority.ensureOwnerReady` ← navigation ingresso chat |
| `RunAsOwner` | — | `SessionAuthority.runAsOwner` *(API; percorsi futuri)* |
| `AcquireIdentityLease` | — | `SessionAuthority.runWithLease` ← `PushMediaSyncGuard` / media |
| `AuthorizePushSync` | — | `SessionAuthority.authorizePushSync` ← `PushCoordinator` |
| `OpenAccount` | `OpenAccountWithPassword` / `OpenAccountWithSignUp` | `AccountMultiAccountEffects` → `AccountManager` manifest |
| `CloseAccount` | `CloseAccount` | `AccountManager.removeAccount` |
| `ReconnectFocusedSession` | `ReconnectFocusedSession` | `SessionAuthority.reconnectActiveOwner` |

### Eventi

| Dominio | Statechart | Codice |
|---------|------------|--------|
| `AccountFocused` | `AccountFocused` | dopo `requestFocusSwitch` con sessione |
| `AccountOpened` | `AccountOpened` | dopo login/signup su manifest |
| `AccountClosed` | `AccountClosed` | dopo `removeAccount` |
| `SessionRestoreFailed` | `SessionRestoreFailed` | focus senza sessione utilizzabile |

### Stati focus (UML ↔ `MultiAccountFocusState`)

| UML / glossario | `MultiAccountFocusState` |
|-----------------|--------------------------|
| `NoOpenAccounts` | `noOpenAccounts` |
| `HasOpenAccounts` | `hasOpenAccounts` |
| `FocusSwitching` | `focusSwitching` |
| `FocusedWithSession` | `focusedWithSession` |
| `FocusedAwaitingSession` | `focusedAwaitingSession` |

Statechart: `client/lib/machines/multi-account/` · Effetti: `AccountMultiAccountEffects` → `SessionAuthority` + `AccountManager` · Facade UI: `AuthController`

**UML SessionAuthority:** [session-authority-state.puml](../../model/uml/multi-account/session-authority-state.puml) · [seq-run-as-owner.puml](../../model/uml/multi-account/seq-run-as-owner.puml) · [seq-identity-lease-media.puml](../../model/uml/multi-account/seq-identity-lease-media.puml)
