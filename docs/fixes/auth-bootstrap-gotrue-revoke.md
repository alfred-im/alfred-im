# Fix: bootstrap auth revoca refresh token condiviso

**Data**: 2026-06-29  
**Status**: ✅ **Risolto su `main`** (PR #142)  
**Categoria**: Auth / multi-account

Documento per AI.

---

## Sintomi

| Sintomo | Contesto |
|---------|----------|
| «Sessione scaduta» subito dopo **Aggiungi account** / login | Client, multi-account |
| Logout di **tutti** i dispositivi quando un client fa `signOut` o `POST /auth/v1/logout` | Test agente, stesso account su più browser |
| Al riavvio browser, account salvato non si ripristina | Refresh token revocato ma ancora in `SharedPreferences` |
| Recupero password → crash client «null value» | Bootstrap senza `pkceAsyncStorage` con flusso PKCE default |

---

## Causa radice (GoTrue)

1. Login bootstrap e client dedicato ricevono lo **stesso** `refresh_token`.
2. `bootstrap.auth.signOut()` (o logout HTTP) **revoca** quel refresh token lato server (`refresh_token_not_found` al refresh successivo).
3. Il client dedicato ha già persistito il token revocato → `restore()` fallisce al prossimo avvio.
4. PKCE default richiede storage per il code verifier; `EmptyLocalStorage` senza `pkceAsyncStorage` → `resetPasswordForEmail` crasha.

Riproduzione documentata in `client/test/unit/account_session_bootstrap_test.dart` (commento regressione) e `client/test/live/password_reset_live_test.dart`.

---

## Fix client (PR #142 — su `main`)

| File | Cambiamento |
|------|-------------|
| `client/lib/services/account_session.dart` | Rimosso `signOut()` nel `finally` di login/signup; `createBootstrapClient()` con `EmptyLocalStorage` + `autoRefreshToken: false` |
| `client/lib/utils/ephemeral_pkce_storage.dart` | `EphemeralPkceStorage` — PKCE verifier in RAM per bootstrap effimero |
| `client/lib/services/account_session.dart` | `_sessionFromAuthResponse`: `setSession(refresh, accessToken: …)` sul client dedicato |

**Non usare** `AuthFlowType.implicit` come workaround PKCE (scartato dall'utente).

PR #141 aveva introdotto `_sessionFromAuthResponse` ma **lasciava** `signOut` nel `finally` — completamente risolto in #142.

---

## Impatto test agente

- **Mai** `POST /auth/v1/logout` su account utente (`test1`/`test2`/`test3`).
- **Mai** login/password change su account utente senza istruzione esplicita.
- Usare solo `alfredagent1` / `alfredagent2` — vedi `docs/AGENT_DEBUG_ACCOUNTS.md`.

---

## Riferimenti

- `docs/decisions/multi-account-parallel-sessions.md`
- `docs/decisions/single-device-logout-open.md`
- `client/lib/services/account_session.dart`
