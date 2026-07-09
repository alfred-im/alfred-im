# Fix multi-account: una sola sessione GoTrue attiva (PR #152)

**Data**: 2026-07-02  
**PR**: #152  
**Problema**: inbox errata dopo switch account su web  
**Causa**: `BroadcastChannel` GoTrue con chiave unica per progetto — eventi auth di un account sovrascrivono `_currentSession` in RAM degli altri client paralleli

---

## Sintomo

Dopo invio da account A → switch a account B, l'inbox mostra conversazioni di A (JWT sbagliato in RAM). Il DB è corretto; `alfred_focus_user_id` è corretto.

Riproducibile con `e2e/multi-account-messages.spec.ts` (`expectReceivedMessageOnAccount`).

---

## Causa root

PR #140 introdusse **N `SupabaseClient` GoTrue in parallelo** (realtime sempre ON per ogni account). Su web, gotrue-dart propaga eventi auth via `BroadcastChannel` (`sb-{projectRef}-auth-token`) — **stessa chiave per tutti i client dello stesso progetto**, indipendentemente da `alfred_auth_{userId}`.

Issue upstream: [supabase-flutter #1085](https://github.com/supabase/supabase-flutter/issues/1085) (aperta).

---

## Soluzione (interim)

Modifica **solo** il meccanismo connessione; navigazione e UI **identiche**.

| Aspetto | Prima (PR #140–#147) | Dopo (PR #152) |
|---------|----------------------|----------------|
| Manifest `alfred_saved_accounts` | Tutti gli account aperti | Invariato |
| RAM GoTrue | N sessioni parallele | **Una** sessione (account in focus) |
| `setFocus` | Solo UI + `inbox.load()` | Dispose sessione corrente (`clearAuthStorage: false`), `restore()` nuovo account da manifest, `inbox.load()` |
| Account non in focus | Client vivo + realtime | Solo manifest + `alfred_auth_{userId}` su disco |
| `openAccounts` | Da sessioni RAM | Da **manifest** (profilo focus aggiornato da sessione viva se presente) |

---

## File modificati

| File | Modifica |
|------|----------|
| `client/lib/services/account_manager.dart` | `_activateFocusedSession`, cache manifest, `setFocus` con swap sessione |
| `client/lib/services/account_session.dart` | `clearLocalAuthStorage(userId)` |

Binding inbox UI (già su main da PR precedente): `HomeScreen` usa `ListenableBuilder` su `focusedSession?.inboxController` — non `ListenableProxyProvider` in `main.dart`.

---

## Trade-off

- **Niente realtime in background** per account non in focus (badge/anteprima futuri rinviati fino a fix upstream o `AuthState.fromBroadcast`).
- Breve latenza al cambio focus (restore + `list_inbox()`).
- Accettabile per lo scope attuale; UX switch resta istantanea lato navigazione.

---

## Verifica

```bash
cd client && bash scripts/verify.sh
bash scripts/integration-multi-account.sh
ALFRED_BASE_URL=http://localhost:8081/XmppTest/ npx playwright test e2e/multi-account-messages.spec.ts --workers=1
```

Test manuale multi-account su demo live: confermato OK (2026-07-02).

---

## Riferimenti

- ADR (modello UX + runtime aggiornato): `docs/decisions/multi-account-parallel-sessions.md` §2.6
- Implementazione: `docs/implementation/multi-account-client.md`
- Persistenza dichiarativa (invariata): `docs/implementation/multi-account-client.md` §3.5
- E2E: `client/e2e/multi-account-messages.spec.ts`
