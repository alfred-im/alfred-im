# Topic aperto: logout su un solo dispositivo

**Data**: 2026-06-29  
**Status**: ✅ Implementato — logout locale in `AccountSession.close()` (nessuna revoca GoTrue)  
**Categoria**: Auth / multi-account

Documento per AI. L'utente ha chiesto esplicitamente un sistema per fare logout **solo sul dispositivo corrente**, senza buttare fuori gli altri client.

---

## Decisione (2026-06-29)

**Chiudi account** = logout **solo su questo dispositivo**:

- `AccountSession.close()` → dispose inbox/realtime + `removePersistedSession` su `alfred_auth_{userId}`
- **Nessuna** chiamata `GoTrueClient.signOut` / `POST /auth/v1/logout`
- Altri dispositivi con refresh token propri restano connessi

Futuro opzionale: azione separata «Disconnetti ovunque» (`signOut(scope: global)`).

---

## Problema (storico)

Oggi (GoTrue / Supabase Auth):

- `signOut()` e `POST /auth/v1/logout` **revocano il refresh token** lato server.
- Tutti i client che usano quel refresh token (stesso account, altri browser/tab/dispositivi) perdono la sessione al prossimo refresh o al riavvio.
- Non è un bug del client Alfred: è il comportamento standard di revoca token.
- I test agente con curl logout su account live hanno causato logout globale all'utente.

Il client Alfred oggi ha due “logout” concettuali non distinti in UX:

1. **Rimuovi account** (`removeAccount`) → `client.auth.signOut()` + dispose sessione → revoca server.
2. **Solo chiudi / smetti di usare su questo browser** → oggi non esiste come azione separata; basta non chiamare logout server.

---

## Vincoli noti

- Un `SupabaseClient` per account con `SharedPreferencesLocalStorage` scope `alfred_auth_{userId}`.
- `OpenAccount` persiste solo `refreshToken` (non access token).
- Multi-account parallelo: N sessioni vive, un focus UI.

---

## Direzioni da valutare (non approvate)

| Approccio | Pro | Contro |
|---------|-----|--------|
| **Logout locale** — cancella storage client, nessuna chiamata GoTrue | Altri dispositivi restano connessi | Refresh token resta valido su server; “sicurezza” solo locale |
| **Sessioni GoTrue per dispositivo** — investigare API session management Supabase | Logout selettivo possibile lato provider | Complessità, limiti piano, da verificare in dashboard/docs |
| **Refresh token rotation + non revocare al bootstrap** (fix #142) | Evita auto-sabotaggio post-login | Non risolve logout esplicito globale |
| **Etichettare UX** — “Esci da questo dispositivo” vs “Disconnetti ovunque” | Chiarezza utente | Richiede due flussi e copy |

---

## Azione richiesta prima di implementare

1. Concordare con l'utente semantica desiderata (locale vs globale).
2. Verificare capability Supabase Auth (session list, revoke single session) sul progetto `tvwpoxxcqwphryvuyqzu`.
3. Solo dopo accordo: ADR vincolante + implementazione.

---

## Riferimenti

- `docs/fixes/auth-bootstrap-gotrue-revoke.md`
- `docs/decisions/multi-account-parallel-sessions.md`
- `docs/AGENT_DEBUG_ACCOUNTS.md`
