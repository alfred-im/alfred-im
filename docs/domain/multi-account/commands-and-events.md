# Comandi ed eventi — contesto multi-account

**Ultima revisione:** 2026-08-02  
**UML:** [docs/model/uml/multi-account/](../../model/uml/multi-account/)  
**Enforcement identità:** [session-authority.md](session-authority.md)

---

## Comandi

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `FocusAccount` | Utente / Policy | Intent focus UI → delega `RequestFocusSwitch` a [SessionAuthority](session-authority.md). Scope e shell: `NavigationMachine.SwitchToAccount`. |
| `OpenAccount` | Utente | Aggiunge account al manifest (login o registrazione). |
| `CloseAccount` | Utente | Rimuove account dal manifest. |
| `ReconnectFocusedSession` | Utente / Policy | Ritenta restore sessione per l'account in focus → `SessionAuthority.reconnectActiveFocus`. |

Varianti statechart per `OpenAccount`: `OpenAccountWithPassword`, `OpenAccountWithSignUp`.

### Comandi SessionAuthority (enforcement)

Servizio di dominio — vedi [session-authority.md](session-authority.md).

| Comando | Emesso da | Codice Dart |
|---------|-----------|-------------|
| `RequestFocusSwitch` | `FocusAccount` / navigation | `requestFocusSwitch` |
| `EnsureFocusReady` | navigation (ingresso chat) | `ensureFocusReady` |
| `RunAsFocus` | *(previsto)* | `runAsFocus` |
| `AcquireIdentityLease` / `ReleaseIdentityLease` | media | `runWithLease` / `acquireLease` |
| `AuthorizePushSync` | notifications | `authorizePushSync` |
| `ReconnectActiveArchiveUser` | `ReconnectFocusedSession` | `reconnectActiveFocus` |

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `AccountFocused` | Account in focus con sessione GoTrue utilizzabile. |
| `AccountOpened` | Nuovo account nel manifest (con o senza sessione pronta). |
| `AccountClosed` | Account rimosso dal manifest (`wasLastAccount` se era l'ultimo). |
| `SessionRestoreFailed` | Focus impostato ma restore sessione non riuscito → stato `FocusedAwaitingSession`. |
| `IdentityActivated` | SessionAuthority: JWT valido per `focusUserId`; `identityGeneration` incrementato. |
| `IdentitySwitchDeferred` | Switch richiesto ma bloccato da lease attivo. |
| `IdentityLeaseAcquired` / `IdentityLeaseReleased` | Lease media/upload — vedi [session-authority.md](session-authority.md). |

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
| **Una sessione attiva** | Solo un account ha sessione in memoria alla volta — enforcement: [SessionAuthority](session-authority.md). |
| **Focus persistito** | L'account in focus sopravvive al riavvio app. |
| **Reconnect automatico** | Sessione assente viene ritentata in background. |
| **Lease identità** | Upload/picker bloccano switch e push sync al resume — `AcquireIdentityLease` / `AuthorizePushSync`. |

---

## Sistemi esterni

| Sistema | Ruolo |
|---------|--------|
| **Persistenza locale** | Manifest account e focus. |
| **Supabase GoTrue** | Autenticazione e refresh sessione. |
