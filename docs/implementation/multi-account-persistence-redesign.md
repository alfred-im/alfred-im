# Multi-account: redesign persistenza (single source of truth)

**Data**: 2026-07-01  
**Stato**: 🟢 **Documento su `main`** — implementazione codice **non ancora fatta** (vedi §10)  
**Audience**: AI in sessioni future — implementare **solo** secondo questo documento  
**Non implementare**: catene di fallback RAM → cache → GoTrue → storage; `saveAllAccounts` ricostruito da sessioni

---

## 1. Perché questo documento

Dopo PR #140 (sessioni parallele) e PR #143/#144 (tentativi di fix persistenza F5), il codice **funziona a metà**: test unitari/live verdi, utente su web mobile perde il primo account al F5.

**Causa**: non un bug puntuale, ma **design della persistenza** — tre verità non coordinate, salvataggio **derivato** invece che **al momento del login**.

Questo file documenta:
- cosa del refactor PR #140 è **solido** e va tenuto
- cosa **non** ha funzionato e va **rimosso/sostituito**
- come funziona **oggi** (per non confondersi)
- come deve funzionare **dopo** il redesign (contratto implementativo)

---

## 2. Step zero — RAM vs localStorage (domanda fondamentale)

### Cosa l’utente si aspetta (corretto)

> «Salvo profilo + refresh token nella lista JSON in localStorage. F5 → rileggo la lista e ripristino. Aggiungo account → append/upsert nella lista.»

Questo è il modello giusto per la **parte che sopravvive al refresh della pagina**.

### Cosa c’è in RAM e perché non può stare su disco

In RAM (`AccountManager._sessions`) vivono oggetti **`AccountSession`** — non dati serializzabili:

| In RAM | Perché non va in localStorage |
|--------|-------------------------------|
| `SupabaseClient` (connessione HTTP + auth) | Oggetto runtime |
| `InboxController` + subscription Realtime | WebSocket attivo |
| `StreamSubscription` auth (`tokenRefreshed`) | Listener in memoria |
| `MessageService`, cache profilo, ecc. | Servizi legati al client |

**Analogia**: la lista JSON è la **rubrica con le chiavi di casa**; la RAM è **essere dentro casa con le luci accese**. Al F5 esci di casa (RAM si azzera); rileggi la rubrica (JSON) e rientri (`restore`).

Il refactor PR #140 su questo punto è **corretto**: N sessioni vive in parallelo in RAM; il focus UI sceglie quale mostrare.

### Cosa c’è su disco oggi (tre posti)

| Chiave | Prefisso web | Contenuto |
|--------|--------------|-----------|
| `alfred_saved_accounts` | `flutter.` | JSON array `OpenAccount[]`: profilo + `refreshToken` |
| `alfred_focus_user_id` | `flutter.` | `userId` account in focus |
| `alfred_auth_{userId}` | **nessuno** | Sessione GoTrue (JSON con `refresh_token`, `access_token`, …) scritta dalla libreria `supabase_flutter` |

Su web: SharedPreferences → `localStorage` con prefisso `flutter.`; GoTrue usa `localStorage` **diretto** senza prefisso.

### Come funziona oggi (flusso reale) — e dove si rompe

**Login / aggiungi account** (intenzione documentata in ADR):

1. Login → token noto da `AuthResponse`
2. `setSession` sul client dedicato → GoTrue scrive `alfred_auth_{userId}`
3. `_adoptSession` → sessione in RAM
4. `_persistAllOpenAccounts()` → **riscrive** `alfred_saved_accounts`

Il passo 4 **non** usa il token della risposta HTTP. Su `main` legge:

```dart
session.refreshToken  // = currentSession?.refreshToken
```

Su Flutter web, per l’account **non in focus**, `currentSession` è spesso `null` → account **saltato** → su `main` `saveAllAccounts([solo l’ultimo])` **cancella** gli altri.

**Quindi**: la lista JSON esiste e il modello mentale dell’utente è giusto, ma l’implementazione **non scrive al login** — **ricostruisce dopo** leggendo dalla sessione, e quella lettura fallisce su web.

### Cosa deve fare il redesign (allineato all’aspettativa utente)

La lista JSON resta il **manifest degli account aperti** per il F5. La regola:

> **Scrivi in `alfred_saved_accounts` nel momento esatto in cui conosci il `refreshToken` (risposta login o `tokenRefreshed`), non quando riesci a leggerlo indietro dalla sessione.**

La RAM resta per tutto ciò che è vivo; il disco solo per **sopravvivenza** e **metadati profilo**.

---

## 3. Cosa ha funzionato bene (tenere)

| Area | Dettaglio | PR / file |
|------|-----------|-----------|
| Sessioni parallele | N × `SupabaseClient`, una per account | #140, `account_session.dart` |
| Focus = solo UI | `setFocus` senza `setSession` tra account aperti | `account_manager.dart` |
| Inbox per sessione | `InboxController` in `AccountSession`, realtime sempre ON | `account_session.dart` |
| Lifecycle inbox | Provider con dispose noop; close in `AccountSession.close()` | #143, `main.dart` |
| Vista per account | `Map<userId, AccountViewState>` | #143, `account_manager.dart` |
| Overlay auth | Shell sempre visibile; credenziali in overlay | #140, `auth_overlay.dart` |
| Bootstrap login | Client effimero; **no** `signOut` post-login | #142, `account_session.dart` |
| Logout locale | `close()` cancella solo storage locale, no revoca GoTrue | #143 |
| Messaggistica server | Isolata per JWT; nessun mixing tra account | invariato |
| Coda invio | Chiave `userId\|peerProfileId` | `messages_controller.dart` |
| Write lock storage | `_serializedWrite` in `AccountStorageService` | `account_storage_service.dart` |

**Non rifare**: il refactor PR #140 sul runtime. Il problema è **solo il confine persistenza**.

---

## 4. Cosa non ha funzionato (abbandonare)

| Approccio | Perché fallisce |
|-----------|-----------------|
| `_persistAllOpenAccounts()` che scorre tutte le sessioni e **ricostruisce** la lista | Dipende da `currentSession` inaffidabile su web |
| `saveAllAccounts(lista)` come operazione normale | Sovrascrive l’intera lista; un salvataggio parziale cancella account |
| Catena fallback RAM → `_cachedRefreshToken` → GoTrue storage → entry vecchia | Quattro fonti, nessuna verità unica; ogni fix aggiunge un ramo |
| PR #144 come modello | Pezze incrementali su design rotto — **non mergiare così** |
| `initialize()` che **cancella** account su restore fallito | L’utente non ha chiesto di chiudere l’account; confonde errore tecnico con intento |
| Test come prova assoluta | Mock/VM non riproducono `currentSession == null` su web per account in background |
| Doc fix senza codice | Es. `onSessionEnded` in `conversations-empty-diagnosis.md` — non implementato |

---

## 5. Design target — single source of truth

### 5.1 Principio

**Un solo contratto di persistenza account:**

```
AccountSession è l’unico componente che scrive/aggiorna/rimuove la propria entry in alfred_saved_accounts.
AccountManager NON ricostruisce mai la lista leggendo token dalle sessioni.
```

### 5.2 Ruoli chiari

```
┌─────────────────────────────────────────────────────────────────┐
│ AccountManager                                                  │
│   • registro RAM: Map<userId, AccountSession>                 │
│   • focus UI                                                    │
│   • orchestrazione: initialize, adopt, remove                     │
│   • NON legge refreshToken dalle sessioni per persistere        │
└───────────────────────────┬─────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────┐
│ AccountSession (un “contenitore” per account)                   │
│   • SupabaseClient + servizi + InboxController                  │
│   • persistOpenAccount(refreshToken)  ← scrittura manifest        │
│   • updateStoredRefresh(token)        ← su tokenRefreshed       │
│   • clearStoredAccount()              ← su remove               │
└───────────────────────────┬─────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────┐
│ AccountStorageService                                           │
│   • upsertAccount(OpenAccount)   — una entry alla volta           │
│   • removeAccount(userId)                                         │
│   • loadAccounts() / loadFocusUserId()                            │
│   • VIETATO saveAllAccounts() nel flusso normale multi-account    │
└───────────────────────────┬─────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────┐
│ flutter.alfred_saved_accounts  ← UNICA verità per F5            │
│   [{ profile, refreshToken }, ...]                              │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ alfred_auth_{userId}  ← dettaglio GoTrue (gestito dalla lib)   │
│   Usato da SupabaseClient per refresh automatico in sessione     │
│   NON usato come fonte per ricostruire alfred_saved_accounts     │
└─────────────────────────────────────────────────────────────────┘
```

**Single source of truth per «quali account sono aperti e come ripristinarli al F5»**: `alfred_saved_accounts`.

`alfred_auth_{userId}` resta come implementazione interna GoTrue (refresh automatico in RAM), non come backup da cui il manager «indovina» i token.

### 5.3 Contratto operativo (implementazione futura)

#### A. Login / sign-up / aggiungi account

```
1. bootstrap.auth.signIn* → AuthResponse con refreshToken noto
2. client dedicato = createClient(userId)
3. await client.auth.setSession(refresh, accessToken: ...)
4. session = AccountSession.fromClient(...)
5. await session.persistOpenAccount(
     refreshToken: refresh,   // dalla risposta HTTP — MAI da currentSession
     profile: ...
   )
   → storage.upsertAccount(OpenAccount(...))
6. manager.adopt(session)     // solo RAM + focus — nessun persist globale
```

#### B. Token refreshed (evento GoTrue)

```
onAuthStateChange(tokenRefreshed):
  await session.updateStoredRefresh(newRefreshToken)
  → storage.upsertAccount con stesso profile, nuovo token
```

#### C. Remove account

```
1. await session.close()           // clear alfred_auth_{userId}
2. await storage.removeAccount(userId)
3. manager rimuove da RAM
```

#### D. Initialize (F5)

```
1. accounts = storage.loadAccounts()
2. for each account:
     try session = await AccountSession.restore(account)
     manager.register(session)
   catch auth error:
     → NON cancellare da storage
     → segnare sessione come needsReauth (stato UI: «Riconnetti»)
3. focus da alfred_focus_user_id
```

#### E. Operazioni vietate nel nuovo design

- `_persistAllOpenAccounts()` che itera `_sessions` e legge `refreshToken`
- `resolvePersistableRefreshToken()` con catena di fallback
- `_cachedRefreshToken` come pezza web
- `saveAllAccounts()` se non per migrazione una tantum o test
- `storage.removeAccount` automatico in `initialize()` su errore restore

### 5.4 Modello dati `OpenAccount` (invariato)

```json
[
  {
    "id": "uuid",
    "username": "alfredagent1",
    "display_name": "Agent 1",
    "avatar_url": null,
    "pronouns": null,
    "refreshToken": "..."
  }
]
```

Chiave: `flutter.alfred_saved_accounts` (SharedPreferences).

---

## 6. Flussi utente — prima e dopo

### Scenario: login A → aggiungi B → F5

| Step | Oggi (`main`) | Dopo redesign |
|------|---------------|---------------|
| Login A | RAM: A. Disco: forse A (se currentSession leggibile) | RAM: A. Disco: **A subito** (token da AuthResponse) |
| Aggiungi B | `_persistAllOpenAccounts`: A saltato su web, disco = [B] | `persistOpenAccount` B. Disco: **[A, B]** |
| F5 | Restore solo B | Restore **A e B** |

### Scenario: switch A ↔ B senza F5

| | Oggi | Dopo |
|---|------|------|
| Comportamento atteso | Solo cambio focus | Invariato — **nessun** persist al switch |

---

## 7. Chat vuota (problema correlato, scope separato ma documentato)

**Sintomo**: inbox con anteprime, chat vuota; o sessione morta dopo switch.

**Causa design**: `list_peer_messages` ritorna `[]` senza errore se JWT assente; UI non distingue «nessun messaggio» da «sessione invalida»; inbox può avere cache RAM vecchia.

**Regola da aggiungere nel redesign (fase 2 o stesso PR se piccolo):**

```
Prima di fetch messaggi/inbox:
  if (!session.hasValidJwt()) → UI errore «Sessione scaduta — riconnetti»
  mai lista vuota silenziosa
```

Non implementare `onSessionEnded` come nome — usare `session.hasValidJwt()` o equivalente esplicito.

---

## 8. File da modificare (checklist implementazione)

| File | Azione |
|------|--------|
| `account_session.dart` | Aggiungere `persistOpenAccount`, `updateStoredRefresh`; rimuovere catena fallback/cache; restore non dipende da re-lettura token |
| `account_manager.dart` | Rimuovere `_persistAllOpenAccounts` / `resolvePersistableRefreshToken`; `adoptSession` senza persist globale; `initialize` non cancella account su errore |
| `account_storage_service.dart` | Tenere `upsertAccount` / `removeAccount`; deprecare `saveAllAccounts` per uso runtime (solo test/migrazione) |
| `auth_controller.dart` | Invariato se API manager stabile |
| `account_manager_persistence_test.dart` | Riscrivere: scenario login A → add B → loadAccounts == 2 senza mock token override |
| `test/live/multi_account_persist_live_test.dart` | Tenere come gate; aggiungere assert su storage dopo **solo** login A (prima di B) |
| `docs/implementation/multi-account-client.md` | Aggiornare §3.5 Refresh token con questo contratto |
| `docs/decisions/multi-account-parallel-sessions.md` | Aggiungere nota §2.5 persistenza dichiarativa |

**Non toccare** (salvo bug evidenti): `home_screen.dart`, `InboxController`, overlay, layout.

---

## 9. Criteri di accettazione

### Automatici

```bash
cd client && bash scripts/verify.sh
flutter test test/live/multi_account_persist_live_test.dart --tags live
```

Test obbligatorio da aggiungere/rafforzare:

- Dopo **solo** login account A: `loadAccounts().length == 1` con `refreshToken` non vuoto **senza** `testRefreshTokenOverride`
- Dopo login A + B: `length == 2`
- Nuovo `AccountManager` + `initialize()`: `openAccounts.length == 2`

### Manuali (web mobile)

1. Svuota dati sito
2. Login account 1 — **non aprire chat**
3. DevTools → `flutter.alfred_saved_accounts` → **1 entry** con refresh
4. Aggiungi account 2
5. DevTools → **2 entry**
6. F5 → sidebar mostra 2 account
7. Switch tra account senza F5 → inbox carica (o errore esplicito se sessione morta)

---

## 10. Stato PR e pulizia (2026-07-01)

| PR / branch | Esito |
|-------------|--------|
| #143 (mergiata su `main`) | Tenere fix runtime (view per account, logout locale, inbox lifecycle) |
| #144 + `cursor/fix-multi-account-persist-merge-c1ed` | **Chiusa / rimossa** — patch persistenza abbandonate; non mergiate |
| Questo documento | **Mergiato su `main`** — unica base per la prossima implementazione |

Il redesign **sostituisce** la logica persistenza delle patch #144, non la affianca.

---

## 11. Riferimenti

- ADR sessioni parallele: `docs/decisions/multi-account-parallel-sessions.md`
- Implementazione attuale: `docs/implementation/multi-account-client.md`
- Cronaca tentativi falliti: `docs/fixes/multi-account-chat-persistence-pr143.md`
- Bootstrap auth: `docs/fixes/auth-bootstrap-gotrue-revoke.md`
- Chat vuota: `docs/fixes/conversations-empty-diagnosis.md`

---

**Istruzione per la prossima sessione AI**: leggere questo file **prima** di qualsiasi modifica a `account_manager.dart` / `account_session.dart`. Implementare il contratto §5.3. Non aggiungere fallback.
