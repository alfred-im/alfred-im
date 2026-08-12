# Strategia test client Alfred

**SSOT comandi suite:** [client/scripts/test/README.md](../../client/scripts/test/README.md) · **SSOT indice doc:** [SSOT.md](../SSOT.md)

Piano a livelli allineato a **dominio → UML → statechart → composition root** (`client/lib/screens/`, Provider, chiavi di scope sessione).

**Hub comandi:** `client/scripts/test.sh` · **Gate CI:** `client/scripts/verify.sh`

---

## Convenzione documentazione (gate vs prodotto)

Usare **sempre** questa distinzione in README, promesse, guide e `AGENTS.md`:

| Termine | Significato | Comando tipico |
|---------|-------------|----------------|
| **Gate CI / igiene** | Lint, compile, test Dart isolati (mock/fake). **Non** dimostra che l’app funziona per l’utente. | `cd client && bash scripts/verify.sh` |
| **Validazione release** | Browser e/o DB reali, percorso utente o contratto end-to-end. **È** il criterio di release. | `cd client && bash scripts/test.sh release` (alias `manual`) o suite singole sotto |

**Tier di riferimento** per «funziona sul telefono»: `bash scripts/test.sh flusso-reale` (`@real-flow`).  
**Riferimento per scrivere nuovi test:** [`client/e2e/photo-resume-session-repro.spec.ts`](../../client/e2e/photo-resume-session-repro.spec.ts) — vedi sezione [Come si scrivono i test di release](#come-si-scrivono-i-test-di-release) sotto.

Altre suite manuali (`integration`, `e2e-multi`, …) coprono **parti** del prodotto; i test legacy vanno riallineati a questo modello quando si toccano.

**Frase vietata nelle spec:** implicare che `verify.sh` o il conteggio gate validino il comportamento utente.

**Frase corretta in fondo alle promesse SURFACE/PRODUCT:**

```
Igiene (CI): check-spec-sync + verify.sh
Release: vedi docs/testing/strategy.md — almeno flusso-reale se multi-account / media / auth / push
```

---

## Come si scrivono i test di release

**Modello obbligatorio** (da copiare, non reinventare):  
[`client/e2e/photo-resume-session-repro.spec.ts`](../../client/e2e/photo-resume-session-repro.spec.ts) · comando `bash scripts/test.sh flusso-reale` · tag Playwright `@real-flow`.

Ogni nuovo comportamento che l’utente vede sul telefono si valida **così** — non con altri unit test Dart nel gate.

### Cosa fa il modello (checklist)

| # | Regola | Esempio nel file modello |
|---|--------|---------------------------|
| 1 | **Stesso percorso utente** — tap, drawer, chat, allegati, lifecycle PWA | `setupFiveLocalAccounts` → switch account → `composeNewMessage` → `sendPhotoFromGalleryAfterPickerResume` |
| 2 | **Stack reale** — `supabase start`, Flutter web release su `:8080`, Playwright | runner `scripts/run-photo-repro-e2e-local.sh` |
| 3 | **Auth reale** — utenti creati su stack locale (admin API), login **dal form** nell’app | `prepareLocalFiveAccountManifest`, `loginInAuthForm` |
| 4 | **Niente scorciatoie** — no curl con JWT forzato, no `setSession` nel test, no “simula mismatch” | tutto via UI + storage GoTrue dell’app |
| 5 | **Assert su effetti** — non solo “il bottone c’è”: errore assente in UI **e** stato in Postgres | `expectImagePersistedBothSides` (mittente + destinatario) |
| 6 | **Viewport telefono** + permessi PWA se servono (notifiche, push al resume) | `390×844`, `installPushTestEnvironment` |
| 7 | **Lifecycle OS** quando il bug dipende da background/resume (picker galleria, ecc.) | `simulateAppBackground` / `simulateAppResume` in `helpers/chat-media.ts` |
| 8 | **Un file, un viaggio** — uno spec = un flusso completo, non frammenti sparsi | un `test.describe('@real-flow …')` |
| 9 | **Helper condivisi** — `e2e/helpers/local-multi-account.ts`, `backend-assertions.ts`, `multi-account.ts` | non duplicare login/setup |
| 10 | **Registrato in hub** — `scripts/test.sh` + riga in `scripts/test/README.md` | comando `flusso-reale` |

### Cosa non è il modello

- Aggiungere test in `client/test/unit/` o `wiring/` e chiamarli “release”.
- Playwright che invia RPC/fetch al posto dei tap utente.
- Assert solo su `img` in canvas Flutter senza verifica DB.
- Più PR con “un pezzetto” di test senza flusso end-to-end.

### Aggiungere un nuovo scenario

1. Copiare la struttura di `photo-resume-session-repro.spec.ts`.
2. Tag `@real-flow` nel `test.describe`.
3. Runner dedicato `scripts/run-*-e2e-local.sh` (pattern `run-photo-repro-e2e-local.sh`) o estendere quello esistente se stesso stack.
4. Voce in `scripts/test.sh` (alias sotto `flusso-reale` o nuovo comando documentato in README).
5. Riga in tabella tracciabilità promessa → colonna **Release**.

---

| Tier | Dove | Quando gira | Cosa dimostra |
|------|------|-------------|---------------|
| **1a–1d Gate** | `client/test/unit/`, `wiring/`, `composition/`, `widget/` | Ogni PR (CI) | Lint, compile, pezzi isolati con mock/fake — **non** il prodotto |
| **★ Flusso reale** | `scripts/test.sh flusso-reale` | **Ogni release** (media, multi-account, auth, push-on-resume) | Percorso telefono completo + verifica Postgres — **riferimento** per «l’app funziona» |
| **2 Integration** | `scripts/integration-multi-account.sh` | Release (non in CI) | RPC Supabase multi-account — **senza** UI completa |
| **3 E2E** | `client/e2e/` (10 spec) | CI step 6 (`ci-release-tests.sh`) | Browser + DB locale — `e2e/` = suite completa |
| **Diagnostic** | `client/test/diagnostic/` (tag `diagnostic`) | Su richiesta agente | Log `[alfred]` con `ALFRED_DIAGNOSTIC_LOG=true` |

Gate: `check-spec-sync` + `check-model-sync` + `check-composition-sync` + `flutter analyze` + `flutter test` (esclusi tag `stack`, `diagnostic`).

**CI completa:** `.github/workflows/release-suite.yml` — un job sequenziale: gate → docker-smoke → `ci-release-tests.sh` (target wall clock ~10 min, timeout 15).

**Nota:** `flutter test` senza `--exclude-tags` include i test `diagnostic` (falliscono by design senza define). Il gate usa `verify.sh` — **481** test al 2026-08-08 (tag `stack` e `diagnostic` esclusi).

---

## Invarianti composition (catalogo COMP)

Test in `client/test/composition/` — harness in `client/test/support/composition_harness.dart` (`createCompositionAuth`, `roundTripFocus`; widget mirror opzionale per scenari UI futuri). Gate attuale: test unit veloci su auth wired reale.

| ID | Invariante | Contesto | File |
|----|-----------|----------|------|
| **COMP-001** | Dopo round-trip focus A→B→A, controller messaggi usa servizi della sessione **viva** (non istanza dispose) | messaging | `messaging_session_scope_test.dart` |
| **COMP-002** | `hasValidSession` legato a `auth.focusedSession` live; chiave scope include identità sessione (`messagesSessionKey`) | messaging | stesso |
| **COMP-003** | Inbox resta in RAM al focus switch (non dispose nel Provider) | multi-account | `widget/inbox_provider_lifecycle_test.dart` |
| **COMP-004** | Push / deep link con sessione stale → focus + chat corretta | navigation, notifications | `unit/push_tap_stale_chat_verification_test.dart` (estendere a widget) |

Estensioni future: **COMP-005** groups (`groupSessionKey` + `GroupMessagesController` dopo focus).

---

## Regole wiring (tier 1b)

1. **Vietato** `hasValidSession: () => true` in `test/wiring/` salvo riga con commento `// wiring-jwt-bypass-ok` (gate: `check-composition-sync.sh`).
2. Sessioni di test: **un `FakeMessageService` (o equivalente) per `AccountSession`**, non singleton conmotionato tra restore.
3. Almeno un test negativo per contesti con JWT: operazione fallisce se la sessione diventa invalida dopo il load.

---

## Scenari E2E (tier 3 — catalogo)

| Scenario | File | Stato |
|----------|------|-------|
| **★ Foto dopo galleria + resume (4 user + gruppo)** | `e2e/photo-resume-session-repro.spec.ts` | **`flusso-reale`** — implementato |
| Persistenza manifest + F5 | `e2e/multi-account-persist.spec.ts` | Implementato |
| Invio + DB + ricezione UI (live) | `e2e/multi-account-messages.spec.ts` | Implementato (override Pages) |
| Testo, foto, switch e spunte (locale) | `e2e/multi-account-messages.spec.ts` | Implementato (`e2e-multi` default) |
| **Invio dopo round-trip focus con chat aperta** | `e2e/multi-account-send-after-focus-roundtrip.spec.ts` | Da implementare (tier 2) |
| Tap push multi-account | `e2e/push-tap-multi-account.spec.ts` | Locale (`e2e-push-local`) |

Il bug foto PWA (2026-07) era in produzione con il gate tutto verde: nessun tier 1 esegue l’app come l’utente. **`bash scripts/test.sh flusso-reale`** è il test che avrebbe dovuto bloccare il rilascio.

---

## Tracciabilità promessa → verifica

| Promessa | Igiene CI (mock) | Release (prodotto) |
|----------|------------------|-------------------------|
| PROM-MULTI-ACCOUNT-006 | `account_manager_persistence_test.dart` | `flusso-reale`, `e2e-multi`, `integration` |
| PROM-MULTI-ACCOUNT-009 | `inbox_provider_lifecycle_test.dart` (COMP-003) | `e2e-multi` |
| PROM-MULTI-ACCOUNT-010, 020 | `multi_account_chat_scenario_test.dart` | `integration`, `e2e-multi` |
| **PROM-MULTI-ACCOUNT-022** | `composition/messaging_session_scope_test.dart` (COMP-001, COMP-002) | **`flusso-reale`** |
| PROM-CHAT-MEDIA | `messages_controller_media_test.dart`, smoke SQL | **`flusso-reale`** |

---

## Perché il gate non ha fermato nulla (2026-07)

Il gate non testa il prodotto: non c’è browser, non c’è PWA, non c’è multi-account reale, non c’è upload verso storage con auth vera. Machine, wiring e composition girano in harness sintetici con mock e bypass documentati. **Possono essere tutti verdi mentre l’app è rotta sul telefono.**

Ogni release richiede **`flusso-reale`** (e, dove applicabile, le altre suite manuali con DB/browser).

---

## Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [client/scripts/test/README.md](../../client/scripts/test/README.md) | Catalogo comandi |
| [PROM-MULTI-ACCOUNT](../specs/promises/product/PROM-MULTI-ACCOUNT.md) | Promesse multi-account |
| [docs/domain/README.md](../domain/README.md) | Modello e gate `check-model-sync` |
