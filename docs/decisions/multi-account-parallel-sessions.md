# Multi-account: sessioni Supabase parallele

**Stato**: 🟢 Vincolante (client Alpha)  
**Data**: 2026-06-29  
**Sostituisce**: modello client «un account attivo + token salvati + `setSession` al cambio» (PR #111–#131)

---

## 1. Problema

Il client Alpha (fino a PR #131) implementava il multi-account così:

- **Un solo** `SupabaseClient` globale (`Supabase.instance`)
- Lista `SavedAccount` in `SharedPreferences` = refresh token **in attesa**
- Cambio account = `setSession(refreshToken)` → spegnere una identità, accendere l’altra
- Gate app: `AppShell` mostrava `AuthScreen` **a tutto schermo** se `!isAuthenticated`

Questo modello è **incompatibile** con il prodotto concordato:

| Vecchio paradigma | Paradigma corretto |
|-------------------|-------------------|
| «Entri in Alfred» (auth = identità app) | «Usi Alfred» con N credenziali messaggistica |
| Account «salvato» ≠ account «loggato» | Account in lista = **sempre** autenticato e in ascolto |
| Switch = ri-autenticazione | Switch = **solo focus UI** |
| Auth sostituisce l’app | Auth è **overlay** sulla shell |

---

## 2. Decisione

### 2.1 Modello mentale

| Concetto | Significato |
|----------|-------------|
| **Sezione app** | Shell Alfred (`HomeScreen`: sidebar + inbox + chat). Nessun `auth.uid()` «utente dell’applicazione». |
| **Account aperto** | Identità messaggistica Alfred con sessione Supabase **viva**, servizi dedicati, `InboxController` + realtime inbox **sempre attivi**. |
| **Focus** | Quale account mostra inbox/chat in UI. Cambio istantaneo, **nessuna** chiamata auth. |
| **Lista account** | Solo account **aperti** (= autenticati). Non esiste «in lista ma disconnesso». |

**Analogia**: client email (Thunderbird). Le caselle restano connesse; cambi quale guardi.

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
│   → Tutti gli account: sessione + realtime inbox attivi │
│   → AuthOverlay solo da «Aggiungi account» (chiudibile) │
└─────────────────────────────────────────────────────────┘
```

**Stati NON ammessi** (il codice non deve più crearli):

- `savedAccounts` non vuota ma nessuna sessione attiva
- Schermata auth che **sostituisce** la shell (eccetto overlay)
- Switch account che invoca `setSession` tra account già aperti

### 2.3 Implementazione client (PR #140)

| Componente | Ruolo |
|------------|-------|
| `AccountManager` | Registro account aperti, focus UI, persistenza `OpenAccount` + `focusUserId` |
| `AccountSession` | Un `SupabaseClient` per account (`SharedPreferencesLocalStorage` con chiave `alfred_auth_{userId}`); servizi + `InboxController` dedicati |
| `OpenAccount` | Modello persistito (ex `SavedAccount`, stesso JSON su disco) |
| `AuthController` | Stato UI: overlay, loading auth, delega a `AccountManager` |
| `AuthOverlay` | Barriera semi-trasparente + `AuthScreen` (card) sopra `HomeScreen` |
| `NoAccountPlaceholder` | Area inbox vuota quando nessun focus / nessun account |

**Bootstrap app** (`bootstrapApp`): solo `WidgetsFlutterBinding` — **nessuna** sessione utente globale.

**Apertura nuovo account** (login/registrazione): client bootstrap temporaneo → credenziali → `AccountSession.restore` con client dedicato → chiusura bootstrap.

**Rimozione account** (`removeAccount`): `signOut` su quel client, dispose `InboxController`, rimozione da storage; se lista vuota → overlay obbligatorio.

**Refresh token**: ogni `AccountSession` ascolta `tokenRefreshed` e aggiorna `OpenAccount` in storage.

### 2.4 Backend

**Invariato**: ogni account Alfred = utente GoTrue + riga `profiles`. Nessun nuovo livello identità server.

Ogni sessione client usa JWT proprio → RLS e Realtime rispettano `auth.uid()` di quell’account.

### 2.5 Storage locale

| Chiave | Contenuto |
|--------|-----------|
| `alfred_saved_accounts` | JSON array `OpenAccount` (compatibile con ex `SavedAccount`) |
| `alfred_focus_user_id` | `userId` account in focus |
| `alfred_auth_{userId}` | Sessione GoTrue per client dedicato (Supabase Flutter local storage) |

---

## 3. Conseguenze

### 3.1 Architettura

- Tutti i servizi dati (`InboxService`, `MessageService`, `ProfileService`, `ContactService`, storage media/avatar) ricevono `SupabaseClient` **per account**, non singleton globale.
- `InboxController` **per sessione**, creato in `AccountSession`, non ricreato al cambio focus.
- `ChangeNotifierProxyProvider` in `main.dart`: `InboxController` = `focusedSession.inboxController` (cambia puntatore al focus, non ricrea sessioni).
- Rimossi: `AuthService`, gate `AppShell` auth vs home, `prepareAddAccount`, `switchAccount` con `setSession`.

### 3.2 UX

- Switch account **istantaneo** (nessun round-trip auth).
- Primo avvio e aggiunta account: **stesso** pattern visivo (overlay su shell).
- Login e registrazione **sempre insieme** (toggle sulla stessa card).
- «Chiudi account» (ex logout) = rimuove identità dall’app, non «esci da Alfred».

### 3.3 Abilitazioni future

- Badge / anteprima messaggi su account **non** in focus (ogni sessione riceve realtime inbox).
- Notifiche per account in background (client-side).

### 3.4 Costi

- N account aperti ≈ N WebSocket realtime (inbox) + N refresh token attivi.
- Accettabile per uso tipico (pochi account); da monitorare su mobile.

---

## 4. Riferimenti incrociati

| Documento | Contenuto |
|-----------|-----------|
| [auth-overlay-shell.md](../design/auth-overlay-shell.md) | Regole UX overlay + placeholder |
| [multi-account-client.md](../implementation/multi-account-client.md) | Dettaglio file e flussi codice |
| [alpha-full-stack.md](../architecture/alpha-full-stack.md) §2.3–2.4 | Architettura client aggiornata |
| `PROJECT_MAP.md` | Mappa sintetica non deducibile |

**Codice**: `client/lib/services/account_manager.dart`, `account_session.dart`, `client/lib/widgets/auth_overlay.dart`

**PR**: #140
