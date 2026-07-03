# Implementazione client multi-account

> **Superseded by spec**: [AUTH-MULTI.spec.md](../specs/capabilities/AUTH-MULTI.spec.md) — guida implementativa dettagliata; per contratto usare la spec.

**Data**: 2026-06-29 (PR #140)  
**ADR**: [multi-account-parallel-sessions.md](../decisions/multi-account-parallel-sessions.md)  
**PR**: #140, #147, #152

Guida implementativa per AI — flussi e file.

---

## 1. Diagramma runtime (stato attuale)

```
AuthController
    └── AccountManager
            ├── _manifestAccounts[]     ← alfred_saved_accounts (tutti gli account aperti)
            ├── _sessions{}             ← al massimo 1 entry: account in focus
            │     └── AccountSession (focus)
            │           ├── SupabaseClient + alfred_auth_{userId}
            │           ├── InboxService / MessageService / …
            │           └── InboxController  ← realtime ON solo sul focus
            ├── _viewsByAccount{}         ← AccountViewState per userId (UI)
            └── focusUserId
```

Il **focus** determina quale `AccountSession` è in RAM e quindi inbox/chat/servizi esposti via `AuthController.focusedSession`. Gli altri account compaiono in sidebar da `openAccounts` (manifest).

---

## 2. File principali

| File | Responsabilità |
|------|----------------|
| `services/account_manager.dart` | Manifest cache, **una** sessione GoTrue attiva, focus, `setFocus` con swap |
| `services/account_session.dart` | Client Supabase, restore da `OpenAccount`, persistenza dichiarativa |
| `services/account_storage_service.dart` | `OpenAccount[]` + `focusUserId` in SharedPreferences |
| `models/open_account.dart` | DTO persistito (ex `SavedAccount`) |
| `providers/auth_controller.dart` | Stato UI auth, overlay, errori user-friendly |
| `widgets/auth_overlay.dart` | Barriera semi-trasparente |
| `widgets/no_account_placeholder.dart` | Inbox vuota |
| `screens/home_screen.dart` | Shell + `ListenableBuilder` inbox del focus |
| `screens/app_shell.dart` | Solo loading iniziale `sessionReady`, poi sempre `HomeScreen` |
| `services/supabase_bootstrap.dart` | `bootstrapApp()` — nessun `Supabase.initialize` globale per utente |

---

## 3. Flussi

### 3.1 Avvio app

1. `AuthController.initialize()` → `AccountManager.initialize()` → `_rebuildFromManifest()`
2. Carica e pulisce `OpenAccount[]` da storage (rimuove entry con `refreshToken` vuoto)
3. Imposta focus da `alfred_focus_user_id` o primo account nel manifest
4. **`_activateFocusedSession()`** — `AccountSession.restore()` **solo** per il focus
5. Se 0 account: `showAuthOverlay = true`, `authOverlayDismissible = false`

### 3.2 Login / registrazione

1. `AccountSession.signInOpenAccount` / `signUpOpenAccount` usa client bootstrap
2. `openAccountFromAuthResponse` → scrive `alfred_auth_{userId}` + restituisce `OpenAccount`
3. `AccountStorageService.upsertAccount` → manifest
4. `_rebuildFromManifest(focusUserId: nuovo)` → attiva sessione del nuovo account
5. Overlay chiuso

### 3.3 Cambio focus

1. `AuthController.setFocus(userId)` → `AccountManager.setFocus`
2. Se già in focus: solo `inboxController.load()` e return
3. Altrimenti: `disposeResources(clearAuthStorage: false)` sulla sessione corrente
4. Aggiorna `focusUserId` in storage
5. `_activateFocusedSession()` — restore nuovo account da manifest
6. `inboxController.load()`
7. `notifyListeners()` — UI legge `focusedSession` e `viewState` per account
8. **`AccountViewState` per `userId`** — `activePeer` e mobile inbox/chat **non** si azzerano al switch

### 3.4 Chiusura account

1. Se sessione in RAM: `session.clearStoredAccount()` (manifest + `alfred_auth_{userId}`)
2. Se solo in manifest: `storage.removeAccount` + `AccountSession.clearLocalAuthStorage`
3. Se era focus: attiva primo account rimasto o `null`
4. Se 0 account: overlay obbligatorio

### 3.5 Persistenza dichiarativa (PR #147)

**Implementazione**: `docs/implementation/multi-account-persistence-redesign.md` — ✅ completata.

- `AccountSession` scrive **solo la propria** entry in `alfred_saved_accounts` (`upsertAccount` / `removeAccount`)
- Login/sign-up: `persistOpenAccount` con token dalla **risposta HTTP**
- `tokenRefreshed`: aggiorna manifest (solo sessione attiva)
- `AccountManager` **non** usa `saveAllAccounts` nel runtime
- `_manifestAccounts` in RAM = cache del manifest per `openAccounts` e `_hasAccount`

### 3.6 Single-active GoTrue (PR #152)

**Fix**: `docs/fixes/multi-account-single-active-gotrue-pr152.md`

- Evita N client GoTrue paralleli su web (BroadcastChannel)
- Storage auth per account **conservato** al cambio focus (`clearAuthStorage: false` su dispose)
- Restore al focus: `recoverSession` locale o `setSession(refreshToken)` da manifest

---

## 4. Provider e UI (`main.dart`, `home_screen.dart`)

`main.dart` — **nessun** provider inbox globale:

```dart
ChangeNotifierProvider(create: (_) => AuthController()..initialize())
ChangeNotifierProxyProvider<AuthController, ContactsController?>(…)  // servizi del focus
ChangeNotifierProxyProvider<AuthController, ProfileController?>(…)
```

`HomeScreen` — inbox del focus:

```dart
final inbox = session?.inboxController;
ListenableBuilder(
  key: ValueKey(accountUserId),
  listenable: inbox,
  builder: … InboxPanel(…),
)
```

`MessagesController` resta per-chat, creato in `_ChatWithMessages` con i servizi della `AccountSession` in focus.

---

## 5. Migrazione da modello precedente

| Prima | Dopo |
|-------|------|
| `SavedAccount` | `OpenAccount` (stesso JSON) |
| `AuthService` | `AccountManager` + `AccountSession` |
| `switchAccount` + `setSession` | `setFocus` (+ restore al focus, PR #152) |
| `signOut` | `removeAccount` |
| N sessioni GoTrue in RAM | Una sessione GoTrue in RAM (PR #152) |
| `Supabase.instance.client` | `session.client` per ogni servizio |
| `bootstrapSupabase()` | `bootstrapApp()` |

Storage `alfred_saved_accounts` **non** cambia chiave — upgrade trasparente.

---

## 6. Test

| Test | Cosa verifica |
|------|----------------|
| `test/unit/account_storage_test.dart` | Round-trip `OpenAccount`, focus, `saveAllAccounts` atomico |
| `test/unit/auth_service_multi_account_test.dart` | Upsert multi-account storage |
| `test/unit/account_manager_view_state_test.dart` | View per account, `setFocus` non resetta altri |
| `test/unit/multi_account_chat_scenario_test.dart` | Focus switch + chat reciproca (mock) |
| `test/unit/messages_controller_multi_account_test.dart` | Scope `userId+peer`, errori RPC |
| `test/unit/account_manager_persistence_test.dart` | Persistenza 2 account |
| `test/widget/inbox_provider_lifecycle_test.dart` | Pattern lifecycle inbox (storico PR #143) |
| `e2e/multi-account-messages.spec.ts` | UI + DB: invio, switch, ricezione senza reload |

### Harness integrazione (no browser)

```bash
bash client/scripts/integration-multi-account.sh   # API agent1↔agent2
bash scripts/test.sh e2e-multi                     # Playwright multi-account
bash client/scripts/diagnose-test-env.sh           # Chrome CDP per computerUse
```

---

## 7. Verifica

```bash
cd client && bash scripts/verify.sh
```

---

## Riferimenti

- [auth-overlay-shell.md](../design/auth-overlay-shell.md)
- [multi-account-persistence-redesign.md](./multi-account-persistence-redesign.md)
- [multi-account-single-active-gotrue-pr152.md](../fixes/multi-account-single-active-gotrue-pr152.md)
- [alpha-full-stack.md](../architecture/alpha-full-stack.md) §2.3–2.4
- [flutter-inbox-stability.md](../fixes/flutter-inbox-stability.md) §3
