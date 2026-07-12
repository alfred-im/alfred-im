# Multi-account client

**Contratto**: [PROM-MULTI-ACCOUNT](../specs/promises/product/PROM-MULTI-ACCOUNT.md), [SURF-AUTH](../specs/surfaces/SURF-AUTH.md)  
**ADR**: [multi-account-parallel-sessions.md](../decisions/multi-account-parallel-sessions.md)

---

## Runtime

```
AuthController
    └── AccountManager
            ├── _manifestAccounts[]     ← alfred_saved_accounts
            ├── _sessions{}             ← al massimo 1 entry (account in focus)
            │     └── AccountSession
            │           ├── SupabaseClient + alfred_auth_{userId}
            │           └── InboxController  ← realtime solo sul focus
            ├── _viewsByAccount{}         ← AccountViewState per userId
            └── focusUserId
```

Il focus determina quale `AccountSession` è in RAM. Gli altri account compaiono in sidebar da `openAccounts` (manifest).

---

## File principali

| File | Responsabilità |
|------|----------------|
| `services/account_manager.dart` | Manifest, una sessione GoTrue attiva, focus, swap |
| `services/account_session.dart` | Client Supabase, restore, persistenza dichiarativa |
| `services/account_storage_service.dart` | `OpenAccount[]` + `focusUserId` |
| `providers/auth_controller.dart` | Stato UI auth, overlay |
| `widgets/auth_overlay.dart` | Barriera semi-trasparente |
| `screens/home_screen.dart` | Shell + `ListenableBuilder` inbox del focus |
| `screens/app_shell.dart` | `sessionReady` → sempre `HomeScreen` |
| `services/supabase_bootstrap.dart` | `bootstrapApp()` — nessun client globale per utente |

---

## Flussi

### Avvio

1. `AuthController.initialize()` → `AccountManager.initialize()` → `_rebuildFromManifest()`
2. Carica `OpenAccount[]`; rimuove entry con `refreshToken` vuoto
3. Focus da `alfred_focus_user_id` o primo account
4. `_activateFocusedSession()` — `AccountSession.restore()` solo per il focus
5. Zero account → overlay obbligatorio

### Login / registrazione

1. Client bootstrap effimero (`createBootstrapClient`, `EphemeralPkceStorage`)
2. **Non** chiamare `signOut` sul bootstrap dopo adozione sessione dedicata (revoca refresh condiviso)
3. `_sessionFromAuthResponse` → `setSession` sul client dedicato
4. `upsertAccount` nel manifest → `_rebuildFromManifest(focusUserId: nuovo)`

### Cambio focus

1. `setFocus(userId)` — se già in focus: solo `inboxController.load()`
2. Altrimenti: `disposeResources(clearAuthStorage: false)` sulla sessione corrente
3. `_activateFocusedSession()` — restore da manifest
4. `AccountViewState` per account **non** si azzera al switch

### Chiusura account

Logout **solo locale**: `close()` cancella storage, **nessuna** `POST /auth/v1/logout`.

### Persistenza dichiarativa

- Ogni `AccountSession` scrive solo la propria entry (`upsertAccount` / `removeAccount`)
- `AccountManager` **non** usa `saveAllAccounts` nel runtime
- `openAccounts` legge dal manifest

### Una GoTrue attiva (web)

Su web, N client GoTrue paralleli condividono `BroadcastChannel` (`sb-{projectRef}-auth-token`) — eventi auth di un account sovrascrivono la sessione in RAM degli altri.

| Aspetto | Comportamento |
|---------|---------------|
| RAM | Una sessione GoTrue (account in focus) |
| `setFocus` | Dispose (`clearAuthStorage: false`), restore nuovo account, `inbox.load()` |
| Account non in focus | Solo manifest + `alfred_auth_{userId}` su disco |
| Trade-off | Niente realtime in background per account non in focus |

---

## Overlay credenziali

La shell (inbox/chat) esiste **sempre**; le credenziali sono uno strato temporaneo.

| Condizione | Overlay | Chiudibile |
|------------|---------|------------|
| 0 account | Sì, automatico | No |
| «Aggiungi account» | Sì | Sì |

```
Stack → HomeScreen (sempre) + AuthOverlay (condizionale) → AuthScreen
```

---

## Provider (`main.dart`)

Nessun provider inbox globale — `ChangeNotifierProxyProvider` per contatti/profilo legati al focus.

`HomeScreen`: `ListenableBuilder` su `focusedSession?.inboxController` con `ValueKey(userId)`.

---

## Test

`account_storage_test`, `account_manager_view_state_test`, `multi_account_chat_scenario_test`, `inbox_realtime_owner_filter_test`, `e2e/multi-account-messages.spec.ts`

```bash
bash scripts/test.sh integration
bash scripts/test.sh e2e-multi
```
