# Multi-account client Alpha

> **Contratto capability**: [AUTH-MULTI.spec.md](../specs/capabilities/AUTH-MULTI.spec.md) — questo ADR resta vincolante; la spec consolidano il contratto operativo.

**Stato**: 🟢 Vincolante (client Alpha)  
**Data**: 2026-06-29 (PR #140) · **runtime aggiornato** 2026-07-02 (PR #152)  
**Sostituisce**: modello client «un account attivo + token salvati + `setSession` al cambio» (PR #111–#131)

> **Nome file storico** (`multi-account-parallel-sessions.md`): la UX multi-account resta quella di PR #140; dal **2026-07-02** in RAM c’è **una sola** connessione GoTrue attiva (§2.6). La persistenza dichiarativa è PR #147.

---

## 1. Problema (contesto storico)

Il client Alpha (fino a PR #131) implementava il multi-account così:

- **Un solo** `SupabaseClient` globale (`Supabase.instance`)
- Lista `SavedAccount` in `SharedPreferences` = refresh token **in attesa**
- Cambio account = `setSession(refreshToken)` → spegnere una identità, accendere l’altra
- Gate app: `AppShell` mostrava `AuthScreen` **a tutto schermo** se `!isAuthenticated`

Questo modello è **incompatibile** con il prodotto concordato:

| Vecchio paradigma | Paradigma corretto |
|-------------------|-------------------|
| «Entri in Alfred» (auth = identità app) | «Usi Alfred» con N credenziali messaggistica |
| Account «salvato» ≠ account «loggato» | Account in lista = **aperto** (credenziali persistite, pronto al focus) |
| Switch = ri-autenticazione | Switch = **solo focus UI** (+ swap connessione GoTrue — §2.6) |
| Auth sostituisce l’app | Auth è **overlay** sulla shell |

---

## 2. Decisione

### 2.1 Modello mentale (UX — invariato)

| Concetto | Significato |
|----------|-------------|
| **Sezione app** | Shell Alfred (`HomeScreen`: sidebar + inbox + chat). Nessun `auth.uid()` «utente dell’applicazione». |
| **Account aperto** | Identità messaggistica Alfred **nel manifest** (`alfred_saved_accounts`); in RAM ha sessione GoTrue **solo se in focus** (§2.6). |
| **Focus** | Quale account mostra inbox/chat in UI. Cambio **senza** overlay login. |
| **Lista account** | Solo account **aperti** (non bookmark disconnessi). |

**Analogia**: client email (Thunderbird). Le caselle restano nell’elenco; guardi una alla volta; la connessione attiva segue il focus.

### 2.2 Stati ammessi

```
┌─────────────────────────────────────────────────────────┐
│ 0 account aperti                                        │
│   → HomeScreen (placeholder inbox)                      │
│   → AuthOverlay obbligatorio (login + registrazione)    │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ ≥1 account aperti                                       │
│   → HomeScreen con dati dell’account in focus           │
│   → Solo il focus: sessione GoTrue viva + realtime inbox│
│   → Altri account: manifest + storage auth su disco     │
│   → AuthOverlay solo da «Aggiungi account» (chiudibile) │
└─────────────────────────────────────────────────────────┘
```

**Stati NON ammessi** (il codice non deve più crearli):

- `savedAccounts` non vuota ma nessuna sessione attiva **quando c’è un focus valido**
- Schermata auth che **sostituisce** la shell (eccetto overlay)
- Switch account che invoca `setSession` **tra due account già in RAM** (swap = dispose + restore — §2.6)

### 2.3 Implementazione client (PR #140, UX)

| Componente | Ruolo |
|------------|-------|
| `AccountManager` | Manifest account aperti, focus UI, **una** `AccountSession` in RAM, persistenza |
| `AccountSession` | `SupabaseClient` con storage `alfred_auth_{userId}`; servizi + `InboxController` quando attiva |
| `OpenAccount` | Modello persistito (ex `SavedAccount`, stesso JSON su disco) |
| `AuthController` | Stato UI: overlay, loading auth, delega a `AccountManager` |
| `AuthOverlay` | Barriera semi-trasparente + `AuthScreen` (card) sopra `HomeScreen` |
| `NoAccountPlaceholder` | Area inbox vuota quando nessun focus / nessun account |

**Bootstrap app** (`bootstrapApp`): solo `WidgetsFlutterBinding` — **nessuna** sessione utente globale.

**Apertura nuovo account** (login/registrazione): client bootstrap temporaneo → credenziali → manifest + `restore` sessione dedicata → focus.

**Rimozione account** (`removeAccount`): rimuove entry manifest + clear `alfred_auth_{userId}`; dispose sessione se era in RAM; se lista vuota → overlay obbligatorio.

**Refresh token**: la sessione **attiva** ascolta `tokenRefreshed` e aggiorna la propria entry in manifest.

### 2.4 Backend

**Invariato**: ogni account Alfred = utente GoTrue + riga `profiles`. Nessun nuovo livello identità server.

La sessione client in focus usa il JWT proprio → RLS e Realtime rispettano `auth.uid()` di quell’account.

### 2.5 Storage locale

| Chiave | Contenuto |
|--------|-----------|
| `alfred_saved_accounts` | JSON array `OpenAccount` — **unica verità F5**; scritto da `AccountSession` al login/refresh (persistenza dichiarativa, PR #147) |
| `alfred_focus_user_id` | `userId` account in focus |
| `alfred_auth_{userId}` | Sessione GoTrue per client dedicato — **non** usato per ricostruire il manifest |

**Stato normale (D15)**: account in lista = aperto. Se restore fallisce (token revocato, caso raro), **rimuovere** l’entry e mostrare overlay login è accettabile.

### 2.6 Runtime connessione — una GoTrue attiva (PR #152)

**Problema** (PR #140–#147): N client GoTrue in parallelo su web → `BroadcastChannel` auth con chiave progetto unica → JWT in RAM corrotto al switch focus → inbox dell’account sbagliato.

**Decisione interim** (fino a fix upstream [#1085](https://github.com/supabase/supabase-flutter/issues/1085)):

| Evento | Comportamento |
|--------|---------------|
| `initialize()` / F5 | Carica manifest; ripristina **solo** l’account in focus |
| `setFocus(userId)` | `disposeResources(clearAuthStorage: false)` sulla sessione corrente; `AccountSession.restore()` per il nuovo focus da manifest; `inboxController.load()` |
| `openAccounts` | Legge dal **manifest** (non solo da `_sessions`) |
| Account non in focus | Nessun `SupabaseClient` in RAM; token e profilo restano su disco |

**Invariato rispetto a PR #140**: drawer, overlay, `AccountViewState` per account, switch istantaneo lato navigazione.

**Trade-off**: niente realtime inbox in background per account non in focus.

Dettaglio: `docs/fixes/multi-account-single-active-gotrue-pr152.md`

---

## 3. Conseguenze

### 3.1 Architettura

- Tutti i servizi dati ricevono `SupabaseClient` dalla **`AccountSession` in focus** (non singleton globale).
- `InboxController` creato in `AccountSession.restore()`; lifecycle in `AccountSession.close()` / dispose al cambio focus.
- `HomeScreen`: `ListenableBuilder` su `focusedSession?.inboxController` (binding diretto al focus).
- Rimossi: `AuthService`, gate `AppShell` auth vs home, `prepareAddAccount`, `switchAccount` con `setSession` tra account legacy.

### 3.2 UX

- Switch account **senza overlay login** (restore GoTrue in background).
- Primo avvio e aggiunta account: **stesso** pattern visivo (overlay su shell).
- Login e registrazione **sempre insieme** (toggle sulla stessa card).
- «Chiudi account» = rimuove identità dall’app, non «esci da Alfred».

### 3.3 Abilitazioni future

- Badge / anteprima messaggi su account **non** in focus — **rinviato** fino a sessioni parallele sicure su web o gestione `AuthState.fromBroadcast`.
- Notifiche per account in background (client-side) — stesso vincolo.

### 3.4 Costi

- **1** WebSocket realtime inbox (account in focus) + **1** refresh token attivo in RAM.
- Restore al cambio focus: round-trip auth + `list_inbox()` — accettabile per uso tipico (pochi account).

---

## 4. Riferimenti incrociati

| Documento | Contenuto |
|-----------|-----------|
| [auth-overlay-shell.md](../design/auth-overlay-shell.md) | Regole UX overlay + placeholder |
| [multi-account-client.md](../implementation/multi-account-client.md) | Dettaglio file e flussi codice (§3.5 persistenza PR #147) |
| [multi-account-single-active-gotrue-pr152.md](../fixes/multi-account-single-active-gotrue-pr152.md) | Fix BroadcastChannel web |
| [alpha-full-stack.md](../architecture/alpha-full-stack.md) §2.3–2.4 | Architettura client aggiornata |
| `PROJECT_MAP.md` | Mappa sintetica non deducibile |

**Codice**: `client/lib/services/account_manager.dart`, `account_session.dart`, `client/lib/widgets/auth_overlay.dart`

**PR**: #140 (UX/shell), #147 (persistenza), #152 (single-active GoTrue)
