# Fix multi-account: logout locale, chat vuota, persistenza refresh (PR #143)

**Data**: 2026-06-29  
**PR**: #143  
**Branch**: `cursor/local-logout-chat-empty-fix-422b`  
**Status**: 🟡 Mergiato su `main` — **validazione UI utente ancora negativa** al momento del handoff

Documento per AI — recap sessione, cause, fix, gap test.

---

## Segnalazione utente (bug report)

| # | Sintomo | Scope richiesto |
|---|---------|-----------------|
| 1 | Logout su un dispositivo disconnette altri dispositivi | Solo logout locale, no revoca GoTrue |
| 2 | Conversazioni **vuote nel pannello chat** (inbox può mostrare anteprime) | Sì |
| 3 | Due account che si scrivono: caos focus, chat reciproca non carica, **dopo F5 resta 1 account** | Sì |
| 4–5 | Altri punti review architetturale | **Esplicitamente esclusi** dall'utente |

### Chiarimenti sessione

- L'utente ha criticato sviluppo **senza comando esplicito** in un primo momento.
- Dopo implementazione branch: **«non ha funzionato»** in pratica sul deploy/browser.
- Test CI verdi ≠ app funzionante: i test unitari usano **mock**, non il flusso browser reale.
- Debug browser (computerUse) spesso **bloccato** — Chrome CDP `:9222` zombie dopo red screen Flutter.
- Backend API agent1↔agent2 **OK** (`scripts/integration-multi-account.sh`).

---

## Cause root individuate (client)

| Causa | Effetto |
|-------|---------|
| Reset globale `AccountViewState` su `setFocus` | `activePeer` sbagliato dopo switch account |
| `ChangeNotifierProxyProvider` dispose `InboxController` al cambio focus | Crash «used after being disposed»; inbox/chat instabile |
| `upsertAccount` / race su storage | Dopo F5 solo 1 account in `alfred_saved_accounts` |
| `initialize()` rimuoveva account su qualsiasi errore restore | Account sparisce al refresh |
| `_adoptSession` chiamava `close()` su login duplicato | Wipe storage `alfred_auth_{userId}` |
| `AccountSession.close()` con `signOut()` GoTrue | Revoca refresh → logout globale |

---

## Fix implementati (PR #143)

### Auth — logout locale

- `AccountSession.close()` → `disposeResources(clearAuthStorage: true)` **senza** `GoTrueClient.signOut`
- Cancella solo `alfred_auth_{userId}` via `SharedPreferencesLocalStorage.removePersistedSession`
- ADR aggiornato: `docs/decisions/single-device-logout-open.md`

### Multi-account — view e chat

- `Map<userId, AccountViewState>` in `AccountManager` — vista **per account**, non globale
- `sanitizedForAccount()` — ignora peer = proprio `userId`
- `MessagesController.outboundQueueKey` = `userId|peerProfileId`
- `ListenableProxyProvider` in `main.dart` con **dispose noop** per `InboxController`

### Persistenza refresh

- `_persistAllOpenAccounts()` — salva **tutte** le sessioni aperte in un'unica `saveAllAccounts`
- `AccountStorageService._serializedWrite` — write lock
- `initialize()` — rimuove account solo su errori auth **definitivi** (`_isPermanentAuthFailure`)
- `_adoptSession` duplicato — `disposeResources(clearAuthStorage: false)` sulla sessione nuova

### Test aggiunti (59 totali in `verify.sh`, esclusi `live`)

| File | Copertura |
|------|-----------|
| `multi_account_chat_scenario_test.dart` | Focus switch, chat reciproca mock, peer=stesso account |
| `messages_controller_multi_account_test.dart` | Scope fetch, errori RPC |
| `account_manager_persistence_test.dart` | Persistenza 2 account |
| `inbox_provider_lifecycle_test.dart` | No dispose inbox al focus switch |
| `account_manager_view_state_test.dart` | View per account (pre-esistente) |

**Limite**: test con `FakeMessageService` / `seedTestAccount` — **non** validano Flutter web + GoTrue + F5.

### Harness diagnostico

- `client/scripts/diagnose-test-env.sh` — rileva Chrome CDP morto
- `client/scripts/reset-chrome-cdp.sh` — reset CDP locale
- `client/scripts/integration-multi-account.sh` — API live agent1↔agent2 senza browser

---

## Stato validazione

| Layer | Esito handoff |
|-------|----------------|
| `verify.sh` (analyze + unit/widget) | ✅ Verde |
| `integration-multi-account.sh` | ✅ Messaggi bidirezionali su Supabase |
| Browser Alpha / localhost (utente) | ❌ Bug ancora percepiti |
| E2E Playwright multi-account + F5 | ❌ Non implementato |

### Checklist diagnosi manuale (se bug persistono post-deploy)

1. DevTools → Application → Local Storage → `alfred_saved_accounts` **prima** di F5 con 2 account
2. F5 → stesso storage: quanti account? refresh token presenti?
3. Network → `rpc/list_peer_messages` con JWT account corretto vs `activePeer.profileId`
4. Confrontare URL deploy con ultimo workflow `deploy-alpha` riuscito (non assumere = `main`)

Account debug: **solo** `alfredagent1` / `alfredagent2` — `docs/AGENT_DEBUG_ACCOUNTS.md`.

---

## File toccati

| File | Ruolo |
|------|--------|
| `lib/services/account_session.dart` | Logout locale, `createForTest` |
| `lib/services/account_manager.dart` | View per account, persistenza atomica, test hooks |
| `lib/services/account_storage_service.dart` | `saveAllAccounts`, write lock |
| `lib/models/account_view_state.dart` | `sanitizedForAccount` |
| `lib/main.dart` | `ListenableProxyProvider` inbox |
| `lib/screens/home_screen.dart` | `ValueKey` chat per `userId-peer` |

---

## Prossimi passi (non fatti in #143)

1. E2E Playwright: login 2 agent, chat reciproca, F5, switch focus
2. Widget/integration test con `SharedPreferences` + restore reale (no fake message service)
3. Punti architetturali 4–5 se utente li riapre

---

## Riferimenti

- `docs/fixes/conversations-empty-diagnosis.md`
- `docs/fixes/auth-bootstrap-gotrue-revoke.md` (PR #142)
- `docs/implementation/multi-account-client.md`
- `docs/SESSION_HANDOFF.md`
