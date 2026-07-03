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

- Shell `HomeScreen` **sempre** visibile (sidebar + inbox + chat).
- Account in lista sidebar = account **aperti** nel manifest — non bookmark disconnessi.
- Storage manifest: `alfred_saved_accounts` (JSON `OpenAccount[]`) — verità dopo F5 (PR #147).
- Focus: `alfred_focus_user_id` — quale account mostra inbox/chat.
- Auth per account: `alfred_auth_{userId}` — sessione GoTrue dedicata; non ricostruisce il manifest.
- **Una** `AccountSession` / connessione GoTrue attiva in RAM (PR #152); al `setFocus`: dispose sessione corrente (`clearAuthStorage: false`), restore nuovo account da manifest.
- Bootstrap app: `bootstrapApp()` — nessun `Supabase.initialize` globale per utente.
- Servizi dati usano `session.client` della sessione in focus, non singleton globale.
- `InboxController` + realtime inbox solo sul focus.
- `AccountViewState` per `userId`: `activePeer` e stato mobile inbox/chat **persistono** al cambio focus.
- 0 account → `AuthOverlay` obbligatorio, non dismissibile.
- ≥1 account → overlay solo da «Aggiungi account», dismissibile.
- Login e registrazione sulla stessa card (`AuthScreen`); toggle Accedi/Registrati.
- «Chiudi account» (`removeAccount`): rimuove manifest + `alfred_auth_{userId}`; se ultimo account → overlay obbligatorio.
- Token refresh: sessione attiva aggiorna propria entry manifest su `tokenRefreshed`.

### SHOULD

- Switch focus senza loading auth visibile (restore in background).
- `NoAccountPlaceholder` in area inbox quando nessun account/focus.

### MUST NOT

- `AuthScreen` a tutto schermo che sostituisce `HomeScreen` (eccetto card in overlay).
- N client GoTrue paralleli in RAM su web (BroadcastChannel collision).
- `switchAccount` legacy con `setSession` tra account già in RAM.
- Overlay dismissibile con 0 account.
- Rotella globale che nasconde shell durante switch.

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

## 5. Verifica

| Tipo | Riferimento |
|------|-------------|
| Gate | `cd client && bash scripts/verify.sh` |
| Unit | `account_storage_test.dart`, `account_manager_view_state_test.dart`, `account_manager_persistence_test.dart`, `multi_account_chat_scenario_test.dart` |
| Integrazione | `bash scripts/test.sh integration` |
| E2E | `bash scripts/test.sh e2e-multi` |

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [multi-account-client.md](../../implementation/multi-account-client.md) | Dettaglio file/flussi |
| [auth-overlay-shell.md](../../design/auth-overlay-shell.md) | UX overlay |
| [multi-account-single-active-gotrue-pr152.md](../../fixes/multi-account-single-active-gotrue-pr152.md) | Fix BroadcastChannel |
| [multi-account-persistence-redesign.md](../../implementation/multi-account-persistence-redesign.md) | Design PR #147 (storico) |
| [MSG-INBOX](./MSG-INBOX.spec.md) | Inbox scoped al focus |

**Codice**: `client/lib/services/account_manager.dart`, `account_session.dart`, `providers/auth_controller.dart`
