# Multi-account: redesign persistenza (single source of truth)

**Data**: 2026-07-01 (revisione design completa)  
**Stato**: 🟢 **Documento su `main`** — implementazione codice **non ancora fatta**  
**Audience**: AI in sessioni future — implementare **solo** secondo questo documento  
**Obiettivo PR**: far **funzionare** il flusso normale multi-account (login → aggiungi → F5 → switch). Non coprire tutti i casi limite.

---

## 0. Premessa — tutto ciò che è in discussione

Questa sezione riassume **in un unico posto** il contesto, lo stato del codice verificato, le decisioni di design e le risposte del product owner. Leggerla per intero prima di implementare.

### 0.1 Problema da risolvere

Dopo PR #140 (sessioni parallele) e PR #143 (fix runtime), il multi-account **a runtime funziona** ma su **web mobile** spesso **si perde il primo account al F5**.

**Causa**: design della persistenza — il manifest `alfred_saved_accounts` viene **ricostruito** dal manager leggendo `currentSession?.refreshToken` invece di essere scritto al login con il token già noto dalla risposta HTTP.

**Non è il bug da debuggare ora**: restore fallito per token revocato/scaduto (caso raro). Quello si gestisce in modo semplice (vedi §0.4 D1).

### 0.2 Cosa resta valido (non rifare)

| Area | Dettaglio |
|------|-----------|
| N sessioni `SupabaseClient` in parallelo | PR #140 |
| Focus = solo UI, nessun `setSession` tra account aperti | PR #140 |
| `InboxController` per sessione, realtime sempre ON | PR #140 |
| `Map<userId, AccountViewState>` | PR #143 |
| Overlay auth su shell | PR #140 |
| Bootstrap senza `signOut` post-login | PR #142 |
| Logout locale (no revoca GoTrue) | PR #143 |
| Write lock `_serializedWrite` in storage | PR #143 |

Il problema è **solo il confine persistenza** tra RAM e `alfred_saved_accounts`.

### 0.3 Stato codice su `main` (verificato 2026-07-01)

**Architettura persistenza attuale** — tutto passa da qui:

```
_trigger (login, remove, sync profili, tokenRefreshed)
    → AccountManager._persistAllOpenAccounts()
        → per ogni sessione: session.refreshToken (= currentSession?.refreshToken)
        → AccountStorageService.saveAllAccounts(lista)   // sostituisce TUTTA la lista
```

**Fatti verificati nel codice:**

| Fatto | File / dettaglio |
|-------|------------------|
| Il token è **noto** in `_sessionFromAuthResponse` ma **non** passato allo storage | `account_session.dart` |
| `upsertAccount` esiste ma **non è usato** in `lib/` | `account_storage_service.dart` |
| `removeAccount` storage usato **solo** in `initialize()` su auth failure | `account_manager.dart` |
| `removeAccount` manager **non** chiama `storage.removeAccount` — ricostruisce la lista | `account_manager.dart` |
| `onPersistRequested` collega ogni sessione al persist **globale** | `account_manager.dart` |
| Test persistenza usano `testRefreshTokenOverride` — mascherano il gap web | `account_manager_persistence_test.dart` |
| Live test citato in versioni precedenti del doc | **non esiste ancora** nel repo |

**Bug collaterale attuale:** se `_persistAllOpenAccounts` non trova token leggibili, fa `return` senza scrivere → storage può restare **stale** dopo remove.

### 0.4 Decisioni product owner (risposte D1–D15)

| ID | Domanda | Decisione |
|----|---------|-----------|
| **D1** | Restore fallito (token revocato — caso raro) | **Non è il focus.** Va bene **rimuovere** l’entry come fa oggi, oppure mostrare di nuovo il login. Scegliere la via **più veloce** da implementare — equivalente per il product. |
| **D2** | Entry con `refreshToken` vuoto | **Stesso trattamento di D1** — rimuovere o richiedere login. |
| **D3** | Focus su account con restore fallito | **Non importante.** |
| **D4** | UX tap su account da riconnettere | **Non importante** — niente stato `needsReauth` dedicato. |
| **D5–D8** | Sidebar, inbox stale, sync profilo, campo token su refresh | **Non importanti** per questa PR — default implementativi in §5. |
| **D9** | Scope PR | **Fix completo in un PR** (persistenza + chat vuota), salvo che l’implementatore chieda split per dimensione eccessiva. |
| **D10** | `saveAllAccounts` | Vedi §0.5 — metodo oggi usato per **sostituire l’intera lista JSON**; nel nuovo design **non** va usato nel flusso normale. |
| **D11** | Ordine account in lista | **Non importante.** |
| **D12** | Due tab stesso browser | **Non importante** — last-write-wins accettabile, limite noto. |
| **D13** | Live test in CI | **Rimandato** — si discute al massimo in seguito. |
| **D14** | `testRefreshTokenOverride` | **Mantenere** con avvertenza esplicita: **vietato** come unica prova di persistenza; ok per test che non toccano storage. |
| **D15** | ADR «account in lista = autenticato e in ascolto» | Significa lo **stato normale** dopo login: salvi, sono loggati, ascoltano. Se serve ri-autenticare, **rimuoverli dalla lista va bene**. Coerente con D1. |

### 0.5 Cos’è `saveAllAccounts` (risposta D10)

Metodo in `AccountStorageService` che **sovrascrive l’intero array** `alfred_saved_accounts` in una scrittura atomica.

**Perché è pericoloso nel flusso attuale:** se la lista ricostruita contiene solo l’ultimo account (perché gli altri hanno `currentSession == null`), **cancella** tutti gli altri dal disco.

**Nel nuovo design:**

| Operazione | Metodo |
|------------|--------|
| Login / aggiungi account | `upsertAccount` (una entry) |
| Token refreshed | `upsertAccount` (stessa entry, nuovo token) |
| Sync profilo | `upsertAccount` (stessa entry, profilo aggiornato) |
| Chiudi un account | `removeAccount(userId)` |
| Chiudi **ultimo** account | `removeAccount` o equivalente che svuota la chiave — **non** serve ricostruire la lista |
| `saveAllAccounts` | **Vietato** nel runtime; ammesso solo in **test** che verificano il round-trip del metodo stesso |

### 0.6 Obiettivo e non-obiettivi

**Obiettivo:** login A → aggiungi B → F5 → **A e B** ancora presenti; switch A↔B funziona; chat non vuota silenziosa con sessione morta.

**Non-obiettivo:** gestione elegante di ogni caso limite (token revocato, dati corrotti, multi-tab, ordine sidebar). Per quelli: comportamento semplice (rimuovi / overlay login) senza investire in stati intermedi.

---

## 1. Modello mentale — RAM vs disco

### Cosa l’utente si aspetta (corretto)

> Salvo profilo + refresh token nella lista JSON. F5 → rileggo la lista e ripristino. Aggiungo account → upsert nella lista.

### Cosa vive in RAM (non serializzabile)

| In RAM | Perché non va su disco |
|--------|------------------------|
| `SupabaseClient` | Oggetto runtime |
| `InboxController` + Realtime | WebSocket attivo |
| `StreamSubscription` auth | Listener in memoria |
| Servizi messaggistica/profilo | Legati al client |

**Analogia:** la lista JSON è la **rubrica con le chiavi**; la RAM è **essere in casa con le luci accese**. Al F5 esci, rileggi la rubrica, rientri con `restore`.

### Tre posti su disco oggi

| Chiave | Prefisso web | Contenuto |
|--------|--------------|-----------|
| `alfred_saved_accounts` | `flutter.` | JSON `OpenAccount[]` |
| `alfred_focus_user_id` | `flutter.` | `userId` in focus |
| `alfred_auth_{userId}` | **nessuno** | Sessione GoTrue (lib `supabase_flutter`) |

### Dove si rompe oggi

Al login il token è noto da `AuthResponse`, ma il passo 4 del flusso attuale è:

```
_persistAllOpenAccounts() → session.refreshToken (= currentSession?.refreshToken)
```

Su web, per account **non in focus**, `currentSession` è spesso `null` → account saltato → `saveAllAccounts([solo ultimo])` **cancella** gli altri.

### Regola del redesign

> **Scrivi in `alfred_saved_accounts` quando conosci il `refreshToken` (risposta login o `tokenRefreshed`), mai rileggendolo da `currentSession` per persistere.**

---

## 2. Cosa abbandonare

| Approccio | Motivo |
|-----------|--------|
| `_persistAllOpenAccounts()` che ricostruisce da `_sessions` | Dipende da `currentSession` inaffidabile su web |
| `saveAllAccounts()` nel flusso login/add/remove/refresh | Replace totale; un salvataggio parziale cancella account |
| Catene fallback RAM → cache → GoTrue storage → entry vecchia | Nessuna verità unica |
| PR #144 e patch incrementali | Non mergiare |
| `onPersistRequested` → persist globale | Sostituire con scrittura per-entry nella sessione |
| Stato `needsReauth` / sezioni UI dedicate | Fuori scope (D4, D15) |
| Test persistenza che dipendono solo da `testRefreshTokenOverride` | Non riproducono il bug web |

**Nota:** `initialize()` che **rimuove** account su restore fallito **resta accettabile** (D1, D15) — non è il bug da fixare.

---

## 3. Design target

### 3.1 Principio

```
AccountSession è l’unico componente che scrive/aggiorna/rimuove la propria entry in alfred_saved_accounts.
AccountManager NON ricostruisce mai la lista leggendo token dalle sessioni.
```

### 3.2 Diagramma responsabilità

```
┌─────────────────────────────────────────────────────────────────┐
│ AccountManager                                                  │
│   • Map<userId, AccountSession>  (RAM)                          │
│   • focus UI, view state per account                            │
│   • orchestrazione: initialize, adopt, remove                   │
│   • NON legge refreshToken per persistere                         │
└───────────────────────────┬─────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────┐
│ AccountSession                                                  │
│   • SupabaseClient + servizi + InboxController                  │
│   • persistOpenAccount(refreshToken, profile)  ← login/signup    │
│   • updateStoredRefresh(token)                 ← tokenRefreshed │
│   • updateStoredProfile(profile)               ← sync profilo   │
│   • clearStoredAccount()                       ← remove         │
└───────────────────────────┬─────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────┐
│ AccountStorageService                                           │
│   • upsertAccount / removeAccount  (per entry)                  │
│   • loadAccounts / loadFocusUserId / saveFocusUserId            │
└───────────────────────────┬─────────────────────────────────────┘
                            ▼
              flutter.alfred_saved_accounts  ← UNICA verità F5

              alfred_auth_{userId}  ← GoTrue only; NON fonte per il manifest
```

### 3.3 API `AccountSession` (nuove / modificate)

| Metodo | Quando | Azione |
|--------|--------|--------|
| `persistOpenAccount({required String refreshToken, required ProfileSummary profile})` | Subito dopo login/signup riuscito | `storage.upsertAccount` — token dalla **risposta HTTP** |
| `updateStoredRefresh(String refreshToken)` | `AuthChangeEvent.tokenRefreshed` | `upsertAccount` — token dall’**evento** (`state.session?.refreshToken`) |
| `updateStoredProfile(ProfileSummary profile)` | Dopo `syncProfileSummary` | `upsertAccount` — stesso token, profilo aggiornato |
| `clearStoredAccount()` | `close()` / remove | `storage.removeAccount` + clear `alfred_auth_{userId}` |
| `hasValidJwt()` | Prima di fetch messaggi | `currentSession?.accessToken != null` (o equivalente) |

**Rimuovere:**

- `onPersistRequested` e wiring verso persist globale
- Uso di `refreshToken` getter (`currentSession`) per **persistere**
- `toOpenAccount()` che legge token da `currentSession` per esporre la lista UI — usare `_lastKnownRefreshToken` (copia RAM del token scritto su disco)

**`testRefreshTokenOverride`:** mantenere solo per test che **non** verificano persistenza; commento/avvertenza nel codice e nel doc test (D14).

### 3.4 API `AccountManager` (modifiche)

| Metodo | Cambiamento |
|--------|-------------|
| `_adoptSession` | Dopo wiring RAM: `await session.persistOpenAccount(...)` con token noto — **eliminare** `_persistAllOpenAccounts` |
| `initialize` | Restore per entry; su fallimento o token vuoto: **`storage.removeAccount`** (come oggi, D1/D2) |
| `removeAccount` | `await session.clearStoredAccount()` — **non** ricostruire lista |
| `_syncAllProfiles` | Per sessione active: sync → `session.updateStoredProfile` — **non** persist globale |
| `_persistAllOpenAccounts` | **Eliminato** |
| `persistSession` / `persistAllOpenAccountsForTesting` | **Eliminati** o sostituiti da test su `upsertAccount` |

### 3.5 Contratto operativo

#### A. Login / sign-up / aggiungi account

```
1. bootstrap.auth.signIn* → AuthResponse (refreshToken NOTO)
2. createClient(userId)
3. await client.auth.setSession(refresh, accessToken: ...)
4. session = AccountSession da client
5. await session.persistOpenAccount(refreshToken: refresh, profile: ...)
6. manager: registra in RAM, setFocus se richiesto
   — NESSUN saveAllAccounts / _persistAllOpenAccounts
```

**Account già aperto (re-login):** `disposeResources(clearAuthStorage: false)` sulla sessione duplicata; `persistOpenAccount` con nuovo token; focus se richiesto.

#### B. Token refreshed

```
_listenAuth: tokenRefreshed →
  token = state.session?.refreshToken
  if (token != null && token.isNotEmpty)
    await updateStoredRefresh(token)
```

#### C. Remove account

```
1. await session.clearStoredAccount()   // removeAccount storage + clear alfred_auth_{userId}
2. dispose RAM, rimuovi da mappe
3. ricalcola focus; se 0 account → overlay obbligatorio
```

#### D. Initialize (F5)

```
1. accounts = storage.loadAccounts()
2. for each account:
     if refreshToken.isEmpty → storage.removeAccount(userId); continue   // D2
     try AccountSession.restore(account) → registra in RAM
     catch permanent auth failure → storage.removeAccount(userId)         // D1
3. focus da alfred_focus_user_id (o primo account rimasto)
4. sync profili per sessioni ripristinate → updateStoredProfile ciascuna
```

Se dopo il loop **0 account** → overlay login obbligatorio (comportamento attuale).

#### E. Switch focus

Invariato. Solo `saveFocusUserId`. Nessuna scrittura token.

#### F. Operazioni vietate

- `_persistAllOpenAccounts` / lettura `session.refreshToken` per persistere
- `saveAllAccounts` nel flusso runtime (salvo test del metodo stesso)
- Catene fallback token
- Lettura `alfred_auth_{userId}` per ricostruire il manifest

### 3.6 Modello dati `OpenAccount` (invariato)

```json
{
  "id": "uuid",
  "username": "alfredagent1",
  "display_name": "Agent 1",
  "avatar_url": null,
  "pronouns": null,
  "refreshToken": "..."
}
```

Chiave: `flutter.alfred_saved_accounts`.

---

## 4. Fix chat vuota (stesso PR — D9)

**Sintomo:** inbox con anteprime, pannello chat vuoto; o lista messaggi `[]` senza errore con JWT assente.

**Causa:** `list_peer_messages` ritorna `[]` silenzioso; `MessagesController.load()` non distingue «nessun messaggio» da «sessione invalida».

**Fix minimo (obiettivo: sistema funzionante, non tutti i edge case):**

```
Prima di fetchPeerMessages / send:
  if (!session.hasValidJwt())
    → error esplicito in UI («Sessione scaduta — accedi di nuovo»)
    → mai [] silenzioso interpretato come «chat vuota»
```

**File coinvolti:** `account_session.dart` (`hasValidJwt`), `messages_controller.dart` (check in `load`/`send`), `chat_panel.dart` (mostrare `error` se presente).

**Non implementare:** `onSessionEnded` come nome API; stati `needsReauth` in sidebar.

Se restore fallisce al F5, l’account viene rimosso (D1) — l’utente rifà login dall’overlay. Non serve UI intermedia.

---

## 5. Flussi — prima e dopo

### Login A → aggiungi B → F5

| Step | Oggi (`main`) | Dopo |
|------|---------------|------|
| Login A | Disco: forse A | Disco: **A subito** (`persistOpenAccount`) |
| Aggiungi B | Disco spesso solo [B] | Disco: **[A, B]** |
| F5 | Restore solo B | Restore **A e B** |

### Switch A ↔ B (senza F5)

Invariato — solo cambio focus.

---

## 6. Migrazione e limiti noti

| Caso | Comportamento |
|------|---------------|
| Manifest già corrotto (solo 1 account per bug passato) | Nessuna migrazione automatica; utente ri-aggiunge account |
| Manifest integro post-deploy | Trasparente |
| Token revocato al F5 | Entry rimossa; overlay login (D1) |
| Due tab stesso origin | Last-write-wins sul manifest — limite accettato (D12) |
| Ordine in sidebar | Irrilevante (D11) |

---

## 7. Test

### 7.1 Unit — da riscrivere

| Test | Assert chiave |
|------|---------------|
| Login solo A (mock con token esplicito in `persistOpenAccount`) | `loadAccounts().length == 1`, token corretto |
| Adopt A poi B | `length == 2`, entrambi i token |
| Remove B | `length == 1`, A intatto |
| `tokenRefreshed` simulato | solo entry interessata aggiornata |

**Vietato** come unica prova persistenza: `testRefreshTokenOverride` + `persistAllOpenAccounts` (D14).

### 7.2 Live

File proposto: `test/live/multi_account_persist_live_test.dart` — **da definire** se entra in CI (D13 rimandato). Gate manuale o script agenti fino a decisione.

### 7.3 Manuale web mobile (obbligatorio pre-merge)

1. Svuota dati sito
2. Login account 1 — non aprire chat
3. DevTools → `flutter.alfred_saved_accounts` → **1 entry** con refresh
4. Aggiungi account 2
5. DevTools → **2 entry**
6. F5 → sidebar **2 account**
7. Switch A↔B → inbox carica
8. Apri chat con storico → messaggi visibili (non lista vuota silenziosa)

---

## 8. Checklist implementazione

| File | Azione |
|------|--------|
| `account_session.dart` | `persistOpenAccount`, `updateStoredRefresh`, `updateStoredProfile`, `clearStoredAccount`, `hasValidJwt`, `_lastKnownRefreshToken`; rimuovere `onPersistRequested` |
| `account_manager.dart` | Eliminare persist globale; adopt/initialize/remove/sync come §3.5 |
| `account_storage_service.dart` | Runtime solo `upsertAccount`/`removeAccount`; documentare `saveAllAccounts` = solo test |
| `messages_controller.dart` | Check JWT prima di load/send |
| `chat_panel.dart` | Mostrare errore sessione |
| `account_manager_persistence_test.dart` | Riscrittura completa |
| `docs/implementation/multi-account-client.md` | Aggiornare §3.5 |
| `docs/decisions/multi-account-parallel-sessions.md` | Nota §2.5 persistenza dichiarativa + chiarimento D15 |

**Non toccare** salvo bug evidenti: `home_screen.dart`, `InboxController`, overlay shell, layout sidebar.

---

## 9. Criteri di accettazione

### Must (merge)

- [ ] Login A → `loadAccounts().length == 1` con token non vuoto **prima** di aggiungere B
- [ ] Login A + B → `length == 2`
- [ ] F5 → 2 account in sidebar
- [ ] Remove B → `length == 1`
- [ ] Nessuna chiamata `_persistAllOpenAccounts` / `saveAllAccounts` nel flusso login/add/remove/refresh
- [ ] Chat: sessione invalida → errore esplicito, non `[]` silenzioso
- [ ] `cd client && bash scripts/verify.sh` verde (zero issue `analyze`)

### Should (manuale)

- [ ] Checklist §7.3 su web mobile

### Out of scope

- [ ] UX `needsReauth` / badge sidebar
- [ ] Multi-tab coordination
- [ ] Live test in CI (finché D13 non deciso)

---

## 10. Stato PR e cronaca

| PR / branch | Esito |
|-------------|--------|
| #140 | Sessioni parallele — **tenere** |
| #143 | Fix runtime — **tenere** |
| #144 | **Chiusa** — patch persistenza abbandonate |
| Questo documento | Base unica per la prossima implementazione |

---

## 11. Riferimenti

- ADR sessioni parallele: `docs/decisions/multi-account-parallel-sessions.md`
- Implementazione runtime: `docs/implementation/multi-account-client.md`
- Cronaca PR #143: `docs/fixes/multi-account-chat-persistence-pr143.md`
- Bootstrap auth: `docs/fixes/auth-bootstrap-gotrue-revoke.md`
- Chat vuota: `docs/fixes/conversations-empty-diagnosis.md`

---

**Istruzione per la prossima sessione AI:** leggere **§0 per intero**, poi implementare §3–§8. Non aggiungere fallback token. Non implementare stati `needsReauth`. Obiettivo: flusso normale funzionante, non ogni caso limite.
