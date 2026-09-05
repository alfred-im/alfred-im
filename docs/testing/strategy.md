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
| **Validazione release** | Browser e/o DB reali, percorso utente end-to-end. **È** il criterio di release. | `cd client && bash scripts/test.sh e2e` o `release` |

**Tier di riferimento** per «funziona sul telefono»: `bash scripts/test.sh e2e` (release snake, tag `@release-snake`).  
**Riferimento per estendere i test:** [`client/e2e/release-snake.spec.ts`](../../client/e2e/release-snake.spec.ts) — vedi sezione [Come si scrivono i test di release](#come-si-scrivono-i-test-di-release) sotto.

Altre suite manuali (`integration`, …) coprono **parti** del prodotto senza UI completa.

**Frase vietata nelle spec:** implicare che `verify.sh` o il conteggio gate validino il comportamento utente.

**Frase corretta in fondo alle promesse SURFACE/PRODUCT:**

```
Igiene (CI): check-spec-sync + verify.sh
Release: vedi docs/testing/strategy.md — bash scripts/test.sh e2e (release snake)
```

---

## Come si scrivono i test di release

**Modello obbligatorio** (da estendere, non reinventare):  
[`client/e2e/release-snake.spec.ts`](../../client/e2e/release-snake.spec.ts) · comando `bash scripts/test.sh e2e` · tag `@release-snake`.

Ogni nuovo comportamento che l’utente vede sul telefono si valida **aggiungendo un segmento al serpente** (o un helper invocato da lì) — non con altri unit test Dart nel gate.

### Cosa fa il modello (checklist)

| # | Regola | Esempio nel serpente |
|---|--------|----------------------|
| 1 | **Stesso percorso utente** — tap, drawer, chat, allegati, lifecycle PWA | cast e1–e4 + gruppo → switch → galleria → resume |
| 2 | **Stack reale** — `supabase start`, Flutter web release su `:8080`, Playwright | `bash scripts/test.sh e2e` |
| 3 | **Auth reale** — utenti creati su stack locale (admin API), login **dal form** nell’app | `ensureManifestAccounts`, `loginInAuthForm` |
| 4 | **Niente scorciatoie** — no curl con JWT forzato, no `setSession` nel test | tutto via UI + storage GoTrue dell’app |
| 5 | **Assert su effetti** — non solo “il bottone c’è”: errore assente in UI **e** stato in Postgres | `expectImagePersistedBothSides`, `expectContactInDb` |
| 6 | **Viewport telefono** + permessi PWA se servono (notifiche, push al resume) | `390×844`, `installPushTestEnvironment` |
| 7 | **Lifecycle OS** quando il bug dipende da background/resume (picker galleria, ecc.) | `simulateAppBackground` / `simulateAppResume` |
| 8 | **Serpente ordinato** — cast comune, transizioni SQL, `snakeStep()` per copertura | `snake-transitions.ts`, `snake-log.ts` |
| 9 | **Helper condivisi** — `e2e/helpers/*`, non duplicare login/setup | `snake-cast.ts`, `peer-relationship.ts` |
| 10 | **Registrato in hub** — `scripts/test.sh` + riga in `scripts/test/README.md` | comando `e2e` |

### Cosa non è il modello

- Aggiungere test in `client/test/unit/` o `wiring/` e chiamarli “release”.
- Playwright che invia RPC/fetch al posto dei tap utente.
- Assert solo su `img` in canvas Flutter senza verifica DB.
- Nuovi file `.spec.ts` paralleli al serpente (salvo benchmark Fly o debug ad hoc).

### Aggiungere un nuovo scenario

1. Estendere `release-snake.spec.ts` con nuovo `snakeStep('core.…')` e assert.
2. Se serve setup SQL/DB, aggiungere transizione in `snake-transitions.ts`.
3. Helper riusabile in `e2e/helpers/` se la logica è ripetibile.
4. Riga in tabella tracciabilità promessa → colonna **Release**.

---

| Tier | Dove | Quando gira | Cosa dimostra |
|------|------|-------------|---------------|
| **1a–1d Gate** | `client/test/unit/`, `wiring/`, `composition/`, `widget/` | Ogni PR (CI) | Lint, compile, pezzi isolati con mock/fake — **non** il prodotto |
| **★ Release snake** | `scripts/test.sh e2e` | **Ogni release** (multi-account, media, auth, push, peer, instance) | Percorso telefono completo + verifica Postgres — **riferimento** per «l’app funziona» |
| **2 Integration** | `scripts/integration-multi-account.sh` | Release (CI step 3) | RPC Supabase multi-account — **senza** UI completa |
| **3 E2E** | `client/e2e/release-snake.spec.ts` | CI step 6 (`ci-release-tests.sh`) | Browser + DB locale — unico gate Playwright |
| **Fly benchmark** | `demo-live-startup-timing.spec.ts` | Manuale post-deploy | Timing splash/rete su Fly — **fuori** gate locale |
| **Diagnostic** | `client/test/diagnostic/` (tag `diagnostic`) | Su richiesta agente | Log `[alfred]` con `ALFRED_DIAGNOSTIC_LOG=true` |

Gate: `check-spec-sync` + `check-model-sync` + `check-composition-sync` + `flutter analyze` + `flutter test` (esclusi tag `stack`, `diagnostic`).

**CI completa:** `.github/workflows/release-suite.yml` — un job sequenziale: gate → docker-smoke → `ci-release-tests.sh`.

**Nota:** `flutter test` senza `--exclude-tags` include i test `diagnostic` (falliscono by design senza define). Il gate usa `verify.sh`.

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

## Scenari nel release snake (tier 3 — catalogo)

Tutti in `client/e2e/release-snake.spec.ts` (`snakeStep`):

| Area | Step core | Ex-spec originale (rimosso) |
|------|-----------|----------------------------|
| Manifest | `core.manifest.*` | `multi-account-persist` |
| Peer | `core.peer.*` | `peer-relationship-*`, `peer-profile-rubrica` |
| Chat | `core.chat.*` | `inbox-open-chat`, `chat-inbox-parity`, `account-switch-restore`, `multi-account-messages` |
| Push | `core.push.*` | `push-full`, `push-tap-multi-account`, `manual-push-poison-repro` |
| Media | `core.photo.*` | `photo-resume-session-repro` |
| Instance | `core.instance.*` | `instance-config-panel` |

Il bug foto PWA (2026-07) era in produzione con il gate tutto verde: nessun tier 1 esegue l’app come l’utente. **`bash scripts/test.sh e2e`** è il test che avrebbe dovuto bloccare il rilascio.

---

## Tracciabilità promessa → verifica

| Promessa | Igiene CI (mock) | Release (prodotto) |
|----------|------------------|-------------------------|
| PROM-MULTI-ACCOUNT-006 | `account_manager_persistence_test.dart` | **`e2e`** (snake), `integration` |
| PROM-MULTI-ACCOUNT-009 | `inbox_provider_lifecycle_test.dart` (COMP-003) | **`e2e`** |
| PROM-MULTI-ACCOUNT-010, 020 | `multi_account_chat_scenario_test.dart` | `integration`, **`e2e`** |
| **PROM-MULTI-ACCOUNT-022** | `composition/messaging_session_scope_test.dart` (COMP-001, COMP-002) | **`e2e`** |
| PROM-CHAT-MEDIA | `messages_controller_media_test.dart`, smoke SQL | **`e2e`** |
| PROM-PUSH-NOTIFY | unit/widget push | **`e2e`** |
| SURF-INSTANCE-CONFIG | — | **`e2e`** |

---

## Perché il gate non ha fermato nulla (2026-07)

Il gate non testa il prodotto: non c’è browser, non c’è PWA, non c’è multi-account reale, non c’è upload verso storage con auth vera. Machine, wiring e composition girano in harness sintetici con mock e bypass documentati. **Possono essere tutti verdi mentre l’app è rotta sul telefono.**

Ogni release richiede **`bash scripts/test.sh e2e`**.

---

## Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [client/scripts/test/README.md](../../client/scripts/test/README.md) | Catalogo comandi |
| [PROM-MULTI-ACCOUNT](../specs/promises/product/PROM-MULTI-ACCOUNT.md) | Promesse multi-account |
| [docs/domain/README.md](../domain/README.md) | Modello e gate `check-model-sync` |
