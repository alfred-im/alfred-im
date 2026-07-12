# Logout solo dispositivo (locale)

**Data**: 2026-06-29 · **aggiornato** 2026-07-09  
**Status**: ✅ **Implementato** — `AccountSession.close()` senza revoca GoTrue  
**Categoria**: Auth / multi-account

Documento per AI. **Chiudi account** = logout **solo su questo dispositivo**, senza buttare fuori gli altri client.

---

## Decisione (2026-06-29)

**Chiudi account** = logout **solo su questo dispositivo**:

- `AccountSession.close()` → dispose inbox/realtime + `removePersistedSession` su `alfred_auth_{userId}`
- **Nessuna** chiamata `GoTrueClient.signOut` / `POST /auth/v1/logout`
- Altri dispositivi con refresh token propri restano connessi

Futuro opzionale: azione separata «Disconnetti ovunque» (`signOut(scope: global)`).

---

## Problema (storico — pre #143)

Prima del fix multi-account (#143), `removeAccount` poteva chiamare `client.auth.signOut()` e revocare il refresh token lato server (logout globale).

**Oggi (implementato):**

1. **Rimuovi account** (`removeAccount`) → `clearStoredAccount` + `disposeResources(clearAuthStorage: true)` — **nessuna** revoca GoTrue server.
2. **Chiudi account** (`AccountSession.close()`) → stesso comportamento locale-only.
3. Altri dispositivi con refresh token propri restano connessi finché non si usa un'azione futura «Disconnetti ovunque».

---

## Vincoli noti

- Storage auth per account: `alfred_auth_{userId}` (solo sessione in RAM quando in focus — PR #152).
- `OpenAccount` persiste solo `refreshToken` (non access token).
- Multi-account: manifest con N account; **una** sessione GoTrue viva (focus UI).

---

## Direzioni da valutare (non approvate)

| Approccio | Pro | Contro |
|---------|-----|--------|
| **Logout locale** — cancella storage client, nessuna chiamata GoTrue | Altri dispositivi restano connessi | Refresh token resta valido su server; “sicurezza” solo locale |
| **Sessioni GoTrue per dispositivo** — investigare API session management Supabase | Logout selettivo possibile lato provider | Complessità, limiti piano, da verificare in dashboard/docs |
| **Refresh token rotation + non revocare al bootstrap** (fix #142) | Evita auto-sabotaggio post-login | Non risolve logout esplicito globale |
| **Etichettare UX** — “Esci da questo dispositivo” vs “Disconnetti ovunque” | Chiarezza utente | Richiede due flussi e copy |

---

## Azione futura opzionale

1. Azione UX «Disconnetti ovunque» (`signOut(scope: global)`) — separata da «Chiudi account»
2. Verificare capability Supabase Auth session management se serve revoke selettivo server-side

---

## Riferimenti

- `docs/guides/multi-account.md`
- `docs/decisions/multi-account-parallel-sessions.md`
- `docs/AGENT_DEBUG_ACCOUNTS.md`
