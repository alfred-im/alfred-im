# Comandi ed eventi — contesto multi-account

**Ultima revisione:** 2026-07-19  
**UML:** [docs/model/uml/multi-account/](../../model/uml/multi-account/)

---

## Comandi (intento)

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `InitializeManifest` | Policy (avvio app) | Carica manifest account aperti e ripristina focus. |
| `FocusAccount` | Utente / Policy (push, link) | Imposta account attivo in UI e ripristina sessione. |
| `OpenAccountWithPassword` | Utente | Apre account con login password e imposta focus. |
| `OpenAccountWithSignUp` | Utente | Apre account con registrazione e imposta focus. |
| `CloseAccount` | Utente | Rimuove account dal manifest. |
| `ReconnectFocusedSession` | Policy (focus senza sessione) | Ritenta ripristino sessione per account in focus. |

---

## Eventi di dominio

| Evento | Dopo | Descrizione |
|--------|------|-------------|
| `ManifestLoaded` | `InitializeManifest` | Account aperti letti da persistenza locale. |
| `NoOpenAccounts` | manifest vuoto | Nessun account aperto; overlay auth obbligatorio. |
| `AccountOpened` | login/signup ok | Nuova voce nel manifest (o primo account). |
| `AccountClosed` | `CloseAccount` ok | Rimosso dal manifest; `wasLastAccount` se era l'ultimo. |
| `FocusSwitchStarted` | `FocusAccount` su account diverso | Dispose sessione precedente in corso. |
| `AccountFocused` | restore sessione ok | Focus persistito + sessione attiva in RAM. |
| `SessionRestoreFailed` | restore fallito (non permanente) | Focus può restare; sessione assente fino a reconnect. |

---

## Policy

| Policy | Trigger | Azione |
|--------|---------|--------|
| **Una sessione RAM** | `FocusAccount` | Dispose sessione precedente prima del restore. |
| **Focus serializzato** | Più `FocusAccount` rapidi | Operazioni focus in coda. |
| **Auth permanente fallita** | Refresh token invalido | Rimuovi account da manifest; prova focus successivo. |
| **Overlay obbligatorio** | `NoOpenAccounts` | Overlay auth non dismissibile. |
| **Reconnect passivo** | Manifest + focus senza sessione | `ReconnectFocusedSession` |

---

## Sistemi esterni

| Sistema | Ruolo |
|---------|------|
| **Persistenza locale** | Manifest account aperti e focus persistito. |
| **Supabase GoTrue** | Sign-in/sign-up, refresh token, ripristino sessione per account. |
| **navigation** | Delega `FocusAccount` per tap push / link condiviso. |

Transizioni stato client: [multi-account-state.puml](../../model/uml/multi-account/multi-account-state.puml).

---

## Tracciabilità SDD

| Elemento | Promessa |
|----------|----------|
| Manifest / focus | PROM-MULTI-ACCOUNT-001–005 |
| Una sessione RAM | PROM-MULTI-ACCOUNT-006 |
| Overlay auth | PROM-MULTI-ACCOUNT-012–014 |
| AccountViewState | PROM-MULTI-ACCOUNT-010 |
| Reconnect sessione | PROM-MULTI-ACCOUNT-006 |
