# SURF-AUTH — Overlay autenticazione multi-account

| Campo | Valore |
|-------|--------|
| **Superficie ID** | `SURF-AUTH` |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-12 |
| **Promesse** | [PROM-MULTI-ACCOUNT](../promises/product/PROM-MULTI-ACCOUNT.md), [PROM-SHAREABLE-LINK](../promises/product/PROM-SHAREABLE-LINK.md) |
| **PR** | #140, #147, #152, #139 (redirect email), #178, #184 (URL GitHub Pages `alfred-im`) |

Binding UX overlay login/registrazione sulla shell `HomeScreen` — credenziali come card temporanea, mai schermata full-screen.

---

## 1. Superficie

| Elemento | Valore |
|----------|--------|
| Layout | `Stack` — `HomeScreen` sotto, `AuthOverlay` (45% nero) + `AuthScreen` card sopra |
| Widget | `client/lib/widgets/auth_overlay.dart`, `client/lib/screens/auth_screen.dart` |
| Controller | `AuthController` — gate overlay, errori user-friendly |
| Shell parent | `client/lib/screens/app_shell.dart` — `sessionReady` → sempre `HomeScreen` |

---

## 2. Promesse SURFACE

### MUST

| ID | Promessa |
|----|----------|
| **SURF-AUTH-001** | Shell `HomeScreen` **sempre** visibile (sidebar + inbox + chat) — mai sostituita da auth full-screen |
| **SURF-AUTH-002** | 0 account → `AuthOverlay` obbligatorio, non dismissibile |
| **SURF-AUTH-003** | ≥1 account → overlay solo da «Aggiungi account», dismissibile |
| **SURF-AUTH-004** | Login e registrazione sulla stessa card (`AuthScreen`); toggle Accedi/Registrati |
| **SURF-AUTH-005** | «Chiudi account» (`removeAccount`): se ultimo account → overlay obbligatorio |
| **SURF-AUTH-006** | Registrazione: opzione tipo account `user` / `group` sulla stessa card — [SYS-GROUP](../promises/system/SYS-GROUP.md) SYS-GROUP-011 |
| **SURF-AUTH-008** | Conferma email e reset password: il client passa `emailRedirectTo` / `redirectTo` = web client GitHub Pages (`AuthRedirectUrl.githubPagesDefault`, `https://alfred-im.github.io/alfred-im/`) |
| **SURF-AUTH-014** | Fragment `#` in ingresso con **0 account**: overlay auth obbligatorio ([SURF-AUTH-002](./SURF-AUTH.md)); dopo primo account nel manifest → aprire risorsa linkata — [PROM-SHAREABLE-LINK](../promises/product/PROM-SHAREABLE-LINK.md) |

### SHOULD

| ID | Promessa |
|----|----------|
| **SURF-AUTH-007** | Dopo login/sign-up OK: overlay chiuso automaticamente |

### MUST NOT

| ID | Promessa |
|----|----------|
| **SURF-AUTH-010** | `AuthScreen` a tutto schermo che sostituisce `HomeScreen` (eccetto card in overlay) |
| **SURF-AUTH-011** | Overlay dismissibile con 0 account |
| **SURF-AUTH-012** | Rotella globale che nasconde shell durante switch account |
| **SURF-AUTH-013** | **Prodotto:** l'utente che si registra o resetta password dal web client pubblicato **non** deve essere reindirizzato su `localhost` dopo conferma email — destinazione attesa = `https://alfred-im.github.io/alfred-im/` |

---

## 3. Configurazione Supabase Auth (operativa)

Distinzione **prodotto** vs **canarino tecnico**:

| Livello | Regola |
|---------|--------|
| **Prodotto** | Flusso corretto → utente su `https://alfred-im.github.io/alfred-im/` (SURF-AUTH-008, SURF-AUTH-013) |
| **Tecnico (canarino)** | Site URL Supabase = fallback quando `redirect_to` manca o non è in allow list — **non** è destinazione prodotto; se l'utente ci arriva, c'è un errore da investigare |

| Elemento | Valore web client |
|----------|-------------------|
| **Site URL** (canarino) | `http://localhost:3000` — volutamente diverso dall'app; segnala config/deploy rotto |
| **Redirect URLs** | `https://alfred-im.github.io/alfred-im/**` — autorizza il redirect quando il client lo passa correttamente |

Il `supabase/config.toml` nel repo documenta anche `localhost:8080` per sviluppo agente; la dashboard live può ometterlo se non serve.

---

## 4. Tracciabilità

| SURF-ID | Verifica |
|--------------------|----------|
| SURF-AUTH-001 | `client/lib/screens/app_shell.dart` — `sessionReady` → sempre `HomeScreen`; `guides/multi-account.md` |
| SURF-AUTH-002 | `auth_overlay_shell.md`; `client/test/unit/auth_controller_test.dart` — gate overlay |
| SURF-AUTH-003 | `auth_overlay_shell.md` |
| SURF-AUTH-004 | `auth_screen.dart` — toggle Accedi/Registrati |
| SURF-AUTH-005 | `account_manager_persistence_test.dart`; `auth_controller_test.dart` — overlay dopo ultimo account |
| SURF-AUTH-006 | `AuthScreen` — toggle tipo account |
| SURF-AUTH-008 | `auth_redirect_url.dart`; `account_session.dart` (`signUp`); `account_manager.dart` (`resetPasswordForEmail`); `auth_redirect_url_test.dart` |
| SURF-AUTH-014 | `shareable_link_controller.dart`; scenario manuale — URL con `#peer` e 0 account → login → profilo |
| SURF-AUTH-010 | `guides/multi-account.md` |
| SURF-AUTH-013 | Verifica manuale: flusso corretto → GitHub Pages; localhost = canarino (errore config/deploy), non esito prodotto |

Gate: `cd client && bash scripts/verify.sh`

---

## 5. Riferimenti

- [SURF-ACCOUNT-SIDEBAR.md](./SURF-ACCOUNT-SIDEBAR.md)
- [PROM-SHAREABLE-LINK.md](../promises/product/PROM-SHAREABLE-LINK.md)
- [registry.md](../registry.md)
- [multi-account.md](../../guides/multi-account.md)
