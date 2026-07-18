# Comandi ed eventi — contesto multi-account

**Ultima revisione:** 2026-07-18  
**UML:** [docs/model/uml/multi-account/](../../model/uml/multi-account/)

---

## Comandi

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `InitializeManifest` | App bootstrap | Carica manifest + ripristina focus. |
| `FocusAccount` | Sidebar, push, link | Imposta focus e ripristina sessione GoTrue. |
| `OpenAccountWithPassword` | Auth overlay | Login → manifest + focus. |
| `OpenAccountWithSignUp` | Auth overlay | Registrazione → manifest + focus. |
| `CloseAccount` | Sidebar profilo | Rimuove da manifest; cambia focus se necessario. |
| `ReconnectFocusedSession` | Shell (focus senza sessione) | Ritenta `_activateFocusedSession`. |

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `ManifestLoaded` | Account aperti letti da storage. |
| `NoOpenAccounts` | Manifest vuoto. |
| `AccountFocused` | Focus + sessione GoTrue attiva. |
| `FocusSwitchStarted` | Dispose sessione precedente in corso. |
| `SessionRestoreFailed` | Ripristino GoTrue fallito (focus può restare). |
| `AccountOpened` | Nuovo account nel manifest. |
| `AccountClosed` | Rimosso dal manifest. |

---

## Tracciabilità SDD

| Elemento | Promessa |
|----------|----------|
| Manifest / focus | PROM-MULTI-ACCOUNT-001–005 |
| Una sessione RAM | PROM-MULTI-ACCOUNT-006 |
| Overlay auth | PROM-MULTI-ACCOUNT-012–014 |
| AccountViewState | PROM-MULTI-ACCOUNT-010 |
