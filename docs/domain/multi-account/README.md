# Contesto: multi-account

**Stato modellazione:** `verified`

**Invarianti:** [invariants.md](invariants.md)

## Mapping dominio → implementazione

| Dominio | Statechart | Codice |
|---------|------------|--------|
| `FocusAccount` | `FocusAccount` | `MultiAccountMachine` |
| `OpenAccount` | `OpenAccountWithPassword` / `OpenAccountWithSignUp` | `AccountManager` |
| `CloseAccount` | `CloseAccount` | manifest |
| `AccountFocused` | `AccountFocused` | sessione attiva |
| `SessionUnavailable` | `SessionRestoreFailed` / `FocusedAwaitingSession` | reconnect |

Statechart: `client/lib/machines/multi-account/` · sync `AuthController`
