# AUTH-MULTI — Multi-account client

| Campo | Valore |
|-------|--------|
| **Spec ID** | `AUTH-MULTI` |
| **Layer** | capability |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-03 |
| **ADR** | [multi-account-parallel-sessions.md](../../decisions/multi-account-parallel-sessions.md) |
| **PR** | #140 (UX/shell), #147 (persistenza), #152 (single-active GoTrue) |
| **Supersedes** | modello legacy `setSession` tra account (#111–#131) |

Documento per AI — contratto multi-account: manifest account aperti, focus UI, una sessione GoTrue attiva in RAM.

---

## 1. Problema / obiettivo

L’utente opera Alfred con una o più identità messaggistica sulla stessa shell. Le credenziali sono overlay temporaneo, non schermata che sostituisce l’app. Il cambio account è focus istantaneo senza re-login.

---

## 2. Requisiti

### MUST

| ID | Requisito |
|----|-----------|
| **AUTH-MULTI-REQ-001** | Shell `HomeScreen` **sempre** visibile (sidebar + inbox + chat) — mai sostituita da auth full-screen |
| **AUTH-MULTI-REQ-002** | Account in lista sidebar = account **aperti** nel manifest — non bookmark disconnessi |
| **AUTH-MULTI-REQ-003** | Storage manifest: `alfred_saved_accounts` (JSON `OpenAccount[]`) — verità dopo F5 (PR #147) |
| **AUTH-MULTI-REQ-004** | Focus: `alfred_focus_user_id` — quale account mostra inbox/chat |
| **AUTH-MULTI-REQ-005** | Auth per account: `alfred_auth_{userId}` — sessione GoTrue dedicata; non ricostruisce il manifest |
| **AUTH-MULTI-REQ-006** | **Una** `AccountSession` / connessione GoTrue attiva in RAM (PR #152); al `setFocus`: dispose sessione corrente (`clearAuthStorage: false`), restore nuovo account da manifest |
| **AUTH-MULTI-REQ-007** | Bootstrap app: `bootstrapApp()` — nessun `Supabase.initialize` globale per utente |
| **AUTH-MULTI-REQ-008** | Servizi dati usano `session.client` della sessione in focus, non singleton globale |
| **AUTH-MULTI-REQ-009** | `InboxController` + realtime inbox solo sul focus — [MAILBOX-INBOX](./MAILBOX-INBOX.spec.md) REQ-010 |
| **AUTH-MULTI-REQ-010** | `AccountViewState` per `userId`: `activePeer` e stato mobile inbox/chat **persistono** al cambio focus |
| **AUTH-MULTI-REQ-011** | 0 account → `AuthOverlay` obbligatorio, non dismissibile |
| **AUTH-MULTI-REQ-012** | ≥1 account → overlay solo da «Aggiungi account», dismissibile |
| **AUTH-MULTI-REQ-013** | Login e registrazione sulla stessa card (`AuthScreen`); toggle Accedi/Registrati |
| **AUTH-MULTI-REQ-014** | «Chiudi account» (`removeAccount`): rimuove manifest + `alfred_auth_{userId}`; se ultimo account → overlay obbligatorio |
| **AUTH-MULTI-REQ-015** | Token refresh: sessione attiva aggiorna propria entry manifest su `tokenRefreshed` |

### SHOULD

| ID | Requisito |
|----|-----------|
| **AUTH-MULTI-REQ-016** | Switch focus senza loading auth visibile (restore in background) |
| **AUTH-MULTI-REQ-017** | `NoAccountPlaceholder` in area inbox quando nessun account/focus |

### MUST NOT

| ID | Requisito |
|----|-----------|
| **AUTH-MULTI-REQ-018** | `AuthScreen` a tutto schermo che sostituisce `HomeScreen` (eccetto card in overlay) |
| **AUTH-MULTI-REQ-019** | N client GoTrue paralleli in RAM su web (BroadcastChannel collision) |
| **AUTH-MULTI-REQ-020** | `switchAccount` legacy con `setSession` tra account già in RAM |
| **AUTH-MULTI-REQ-021** | Overlay dismissibile con 0 account |
| **AUTH-MULTI-REQ-022** | Rotella globale che nasconde shell durante switch |

---

## 3. Fuori scope

- Realtime inbox per account non in focus (trade-off PR #152).
- Badge/anteprima messaggi su account in background (rinviato).
- Encryption refresh token (post-Alpha).
- Backend multi-identità server (resta 1 GoTrue user = 1 `profiles`).

---

## 4. Contratto

### 4.1 Runtime

```
AuthController
  └── AccountManager
        ├── manifest (OpenAccount[])
        ├── sessions{} — max 1 AccountSession (focus)
        ├── viewsByAccount{} — AccountViewState per userId
        └── focusUserId
```

### 4.2 Flussi

| Evento | Comportamento |
|--------|---------------|
| Avvio | Carica manifest; pulisce entry senza refreshToken; restore **solo** focus |
| Login/sign-up | Bootstrap client → manifest + focus nuovo account; overlay chiuso |
| `setFocus(userId)` | Swap sessione GoTrue; `inboxController.load()`; UI da `focusedSession` |
| `removeAccount` | Clear storage account; se era focus → primo rimasto o null |
| Restore fallito | Rimuovere entry manifest + overlay login (accettabile, caso raro) |

### 4.3 UX overlay

| Condizione | Overlay | Chiudibile |
|------------|---------|------------|
| 0 account | Sì | No |
| Aggiungi account | Sì | Sì |
| Dopo login OK | No | — |

Layout: `Stack` — `HomeScreen` sotto, `AuthOverlay` (45% nero) + `AuthScreen` card sopra.

### 4.4 Client — file chiave

| File | Ruolo |
|------|--------|
| `account_manager.dart` | Manifest, focus, swap GoTrue |
| `account_session.dart` | Client Supabase, servizi, persistenza dichiarativa |
| `account_storage_service.dart` | SharedPreferences |
| `auth_controller.dart` | Overlay, errori user-friendly |
| `auth_overlay.dart`, `no_account_placeholder.dart` | UX gate |
| `home_screen.dart` | `ListenableBuilder` su inbox focus |
| `app_shell.dart` | Loading `sessionReady` → sempre `HomeScreen` |

### 4.5 Provider (`main.dart`)

- `ChangeNotifierProvider` → `AuthController`
- `ChangeNotifierProxyProvider` → `ContactsController`, `ProfileController` (servizi focus)
- **Nessun** provider inbox globale — binding in `HomeScreen`

---

## 5. Tracciabilità

| REQ-ID | Verifica |
|--------|----------|
| AUTH-MULTI-REQ-001 | `app_shell.dart` — `sessionReady` → sempre `HomeScreen`; `design/auth-overlay-shell.md` |
| AUTH-MULTI-REQ-002, REQ-003 | `account_storage_test.dart` — round-trip `OpenAccount[]` |
| AUTH-MULTI-REQ-004 | `account_storage_test.dart` — `saveFocusUserId` / `loadFocusUserId` |
| AUTH-MULTI-REQ-005 | `account_manager_persistence_test.dart` — `persistOpenAccount` + `alfred_auth_*` via `AccountSession` |
| AUTH-MULTI-REQ-006 | `account_manager_persistence_test.dart` — adopt A then B, single active session |
| AUTH-MULTI-REQ-010 | `account_manager_view_state_test.dart` — `setFocus` preserva `activePeer` per account |
| AUTH-MULTI-REQ-011, REQ-012, REQ-021 | `auth_overlay_shell.md`; `auth_controller.dart` — gate overlay |
| AUTH-MULTI-REQ-014 | `account_manager_persistence_test.dart` — `removeAccount drops only the closed entry` |
| AUTH-MULTI-REQ-009, REQ-019 | `inbox_provider_lifecycle_test.dart` — inbox non disposed al focus switch |
| AUTH-MULTI-REQ-010, REQ-016 | `multi_account_chat_scenario_test.dart` — storico chat per account al cambio focus |
| AUTH-MULTI-REQ-015 | `auth_service_multi_account_test.dart` — upsert refresh token in manifest |
| AUTH-MULTI-REQ-018, REQ-022 | `design/auth-overlay-shell.md`; PR #140 |

Gate: `cd client && bash scripts/verify.sh` · Integrazione: `bash scripts/test.sh integration` · E2E: `bash scripts/test.sh e2e-multi`

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [multi-account-client.md](../../implementation/multi-account-client.md) | Dettaglio file/flussi |
| [auth-overlay-shell.md](../../design/auth-overlay-shell.md) | UX overlay |
| [multi-account-single-active-gotrue-pr152.md](../../fixes/multi-account-single-active-gotrue-pr152.md) | Fix BroadcastChannel |
| [MAILBOX-INBOX](./MAILBOX-INBOX.spec.md) | Inbox scoped al focus |

**Codice**: `client/lib/services/account_manager.dart`, `account_session.dart`, `providers/auth_controller.dart`
