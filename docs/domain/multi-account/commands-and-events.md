# Comandi ed eventi — contesto multi-account

**Ultima revisione:** 2026-07-27  
**UML:** [docs/model/uml/multi-account/](../../model/uml/multi-account/)

---

## Comandi

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `FocusAccount` | Utente / Policy | Solo I/O focus GoTrue. Scope e shell: `NavigationMachine.SwitchToAccount`. |
| `OpenAccount` | Utente | Aggiunge account al manifest (login o registrazione). |
| `CloseAccount` | Utente | Rimuove account dal manifest. |
| `ReconnectFocusedSession` | Utente / Policy | Ritenta restore sessione per l'account in focus (stato `FocusedAwaitingSession`). |

Varianti statechart per `OpenAccount`: `OpenAccountWithPassword`, `OpenAccountWithSignUp`.

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `AccountFocused` | Account in focus con sessione GoTrue utilizzabile. |
| `AccountOpened` | Nuovo account nel manifest (con o senza sessione pronta). |
| `AccountClosed` | Account rimosso dal manifest (`wasLastAccount` se era l'ultimo). |
| `SessionRestoreFailed` | Focus impostato ma restore sessione non riuscito → stato `FocusedAwaitingSession`. |

---

## Eventi bootstrap (statechart)

Ingresso macchina dopo lettura storage; non sono comandi utente.

| Evento | Descrizione |
|--------|-------------|
| `ManifestLoaded` | Manifest letto; la macchina risolve `focusUserId` → `HasOpenAccounts` o `NoOpenAccounts`. |
| `FocusActivationCompleted` | Esito attivazione sessione sul focus risolto → `FocusedWithSession` o `FocusedAwaitingSession`. Usato in test/seed; in produzione il bootstrap dopo `ManifestLoaded` passa da `FocusAccount` (via `NavigationCoordinator.switchToAccount`). |

---

## Stati focus (non eventi)

| Stato | Descrizione |
|-------|-------------|
| `NoOpenAccounts` | Manifest vuoto. |
| `HasOpenAccounts` | Manifest non vuoto; sessione focus non ancora attiva. |
| `FocusSwitching` | Transitorio: dispose sessione precedente + restore nuovo focus. |
| `FocusedWithSession` | Focus persistito + sessione attiva in RAM. |
| `FocusedAwaitingSession` | Focus persistito; restore sessione in corso o fallito (ritentabile). |

Vedi [glossary.md](glossary.md).

---

## Policy

| Policy | Descrizione |
|--------|-------------|
| **Una sessione attiva** | Solo un account ha sessione in memoria alla volta. |
| **Focus persistito** | L'account in focus sopravvive al riavvio app. |
| **Reconnect automatico** | Sessione assente viene ritentata in background. |

---

## Sistemi esterni

| Sistema | Ruolo |
|---------|--------|
| **Persistenza locale** | Manifest account e focus. |
| **Supabase GoTrue** | Autenticazione e refresh sessione. |
