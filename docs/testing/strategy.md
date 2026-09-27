# Strategia test Alfred

**SSOT indice doc:** [SSOT.md](../SSOT.md) · **Comandi client:** [client/scripts/test/README.md](../../client/scripts/test/README.md)

**Una verifica.** Dalla root del repository:

```bash
bash scripts/verify.sh
```

Quello script è l’unico obbligo. Esegue in ordine: [1] igiene client (`client/scripts/gate.sh`) [2] stack release (`scripts/ci-release-tests.sh`, incluso il serpente Playwright).

`client/scripts/gate.sh` è **solo igiene** (analyze + test Dart isolati). **Non** è verifica. Il hub `client/scripts/test.sh` elenca comandi client mirati — non sostituisce `scripts/verify.sh`.

Piano a livelli allineato a **dominio → UML → statechart → composition root** (`client/lib/screens/`, Provider, chiavi di scope sessione).

---

## Convenzione documentazione

Usare **sempre** questa distinzione in README, promesse, guide e `AGENTS.md`:

| Termine | Significato | Comando |
|---------|-------------|---------|
| **Verifica** | Igiene client + stack reale (SQL, integration, Playwright snake). **È** l’unico criterio. | `bash scripts/verify.sh` (root) |
| **Igiene** | Lint, compile, test Dart isolati (mock/fake). **Non** dimostra che l’app funziona. | `cd client && bash scripts/gate.sh` |
| **Comando client mirato** | Una suite del hub (integration, sql-smoke, …). Traccia extra, non verifica. | `cd client && bash scripts/test.sh <cmd>` |

**Frase vietata:** implicare che `gate.sh` o il conteggio test Dart isolati validino il comportamento utente.  
**Frase vietata:** un secondo obbligo (`test.sh e2e`, `test.sh release`, `ci-release-tests.sh` da solo).

**Frase corretta in fondo alle promesse SURFACE/PRODUCT:**

```
Verifica: bash scripts/verify.sh
```

Tracce extra (`integration`, `integration-ticks`, `integration-push`) restano nella tabella se servono.

**Riferimento per estendere i test di prodotto:** [`client/e2e/release-snake.spec.ts`](../../client/e2e/release-snake.spec.ts) — vedi [Come si scrivono i test di release](#come-si-scrivono-i-test-di-release).

---

## Come si scrivono i test di release

**Modello obbligatorio** (da estendere, non reinventare):  
[`client/e2e/release-snake.spec.ts`](../../client/e2e/release-snake.spec.ts) · eseguito da `bash scripts/verify.sh` · tag `@release-snake`.

Ogni nuovo comportamento che l’utente vede sul telefono si valida **aggiungendo un segmento al serpente** (o un helper invocato da lì) — non con altri unit test Dart nel gate.

### Cosa fa il modello (checklist)

| # | Regola | Esempio nel serpente |
|---|--------|----------------------|
| 1 | **Stesso percorso utente** — tap, drawer, chat, allegati, lifecycle PWA | cast e1–e4 + gruppo → switch → galleria → resume |
| 2 | **Stack reale** — `supabase start`, Flutter web release su `:8080`, Playwright | incluso in `bash scripts/verify.sh` |
| 3 | **Auth reale** — utenti creati su stack locale (admin API), login **dal form** nell’app | `ensureManifestAccounts`, `loginInAuthForm` |
| 4 | **Niente scorciatoie** — no curl con JWT forzato, no `setSession` nel test | tutto via UI + storage GoTrue dell’app |
| 5 | **Assert su effetti** — non solo “il bottone c’è”: errore assente in UI **e** stato in Postgres | `expectImagePersistedBothSides`, `expectContactInDb` |
| 6 | **Viewport telefono** + permessi PWA se servono (notifiche, push al resume) | `390×844`, `installPushTestEnvironment` |
| 7 | **Lifecycle OS** quando il bug dipende da background/resume (picker galleria, ecc.) | `simulateAppBackground` / `simulateAppResume` |
| 8 | **Serpente ordinato** — cast comune, transizioni SQL, `snakeStep()` per copertura | `snake-transitions.ts`, `snake-log.ts` |
| 9 | **Helper condivisi** — `e2e/helpers/*`, non duplicare login/setup | `snake-cast.ts`, `peer-relationship.ts` |
| 10 | **Dentro la verifica** — nuovo scenario nel serpente, non un secondo comando hub | `bash scripts/verify.sh` |

### Cosa non è il modello

- Aggiungere test in `client/test/unit/` o `wiring/` e chiamarli “verifica”.
- Playwright che invia RPC/fetch al posto dei tap utente.
- Assert solo su `img` in canvas Flutter senza verifica DB.
- Nuovi file `.spec.ts` paralleli al serpente (salvo benchmark Fly o debug ad hoc).

### Aggiungere un nuovo scenario

1. Estendere `release-snake.spec.ts` con nuovo `snakeStep('core.…')` e assert.
2. Se serve setup SQL/DB, aggiungere transizione in `snake-transitions.ts`.
3. Helper riusabile in `e2e/helpers/` se la logica è ripetibile.
4. Riga in tabella tracciabilità promessa → colonna **Verifica**.

---

| Cosa | Dove | Quando | Cosa dimostra |
|------|------|--------|---------------|
| **Verifica** | `bash scripts/verify.sh` | Ogni PR / fine lavoro | Igiene + percorso telefono + Postgres — **unico criterio** |
| **Igiene** | `client/scripts/gate.sh` | Fase 1 di verify; ad hoc in locale | Lint, compile, pezzi isolati — **non** il prodotto |
| **Integration** | `scripts/test.sh integration` | Fase stack di verify; ad hoc | RPC multi-account — traccia extra |
| **Playwright snake** | `client/e2e/release-snake.spec.ts` | Fase stack di verify | Browser + DB — unico spec funzionale |
| **Fly benchmark** | `demo-live-startup-timing.spec.ts` | Manuale post-deploy | Timing splash/rete su Fly — **fuori** verify |
| **Diagnostic** | `client/test/diagnostic/` (tag `diagnostic`) | Su richiesta agente | Log `[alfred]` con `ALFRED_DIAGNOSTIC_LOG=true` |

Igiene (fase 1): `check-spec-sync` + `check-model-sync` + `check-composition-sync` + `flutter analyze` + `flutter test` (esclusi tag `stack`, `diagnostic`).

**CI:** `.github/workflows/release-suite.yml` — un job: `bash scripts/verify.sh` dalla root. Smoke Docker Fly resta un workflow a parte.

**Nota:** `flutter test` senza `--exclude-tags` include i test `diagnostic` (falliscono by design senza define). L’igiene usa `gate.sh`.

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

## Regole wiring (igiene)

1. **Vietato** `hasValidSession: () => true` in `test/wiring/` salvo riga con commento `// wiring-jwt-bypass-ok` (check: `check-composition-sync.sh`).
2. Sessioni di test: **un `FakeMessageService` (o equivalente) per `AccountSession`**, non singleton condiviso tra restore.
3. Almeno un test negativo per contesti con JWT: operazione fallisce se la sessione diventa invalida dopo il load.

---

## Scenari nel release snake

Tutti in `client/e2e/release-snake.spec.ts` (`snakeStep`):

| Area | Step core | Ex-spec originale (rimosso) |
|------|-----------|----------------------------|
| Manifest | `core.manifest.*` | `multi-account-persist` |
| Peer | `core.peer.*` | `peer-relationship-*`, `peer-profile-rubrica` |
| Chat | `core.chat.*` | `inbox-open-chat`, `chat-inbox-parity`, `account-switch-restore`, `multi-account-messages` |
| Push | `core.push.*` | `push-full`, `push-tap-multi-account`, `manual-push-poison-repro` |
| Media | `core.photo.*` | `photo-resume-session-repro` |
| Instance | `core.instance.*` | `instance-config-panel` |

Il bug foto PWA (2026-07) era in produzione con la sola igiene verde: nessun test isolato esegue l’app come l’utente. Per questo la verifica include lo stack reale.

---

## Tracciabilità promessa → verifica

| Promessa | Igiene (mock) | Verifica (prodotto) |
|----------|------------------|-------------------------|
| PROM-MULTI-ACCOUNT-006 | `account_manager_persistence_test.dart` | **`bash scripts/verify.sh`**, `integration` |
| PROM-MULTI-ACCOUNT-009 | `inbox_provider_lifecycle_test.dart` (COMP-003) | **`bash scripts/verify.sh`** |
| PROM-MULTI-ACCOUNT-010, 020 | `multi_account_chat_scenario_test.dart` | `integration`, **`bash scripts/verify.sh`** |
| **PROM-MULTI-ACCOUNT-022** | `composition/messaging_session_scope_test.dart` (COMP-001, COMP-002) | **`bash scripts/verify.sh`** |
| PROM-CHAT-MEDIA | `messages_controller_media_test.dart`, smoke SQL | **`bash scripts/verify.sh`** |
| PROM-PUSH-NOTIFY | unit/widget push | **`bash scripts/verify.sh`** |
| SURF-INSTANCE-CONFIG | — | **`bash scripts/verify.sh`** |

---

## Perché l’igiene da sola non basta (2026-07)

`gate.sh` non testa il prodotto: non c’è browser, non c’è PWA, non c’è multi-account reale, non c’è upload verso storage con auth vera. Machine, wiring e composition girano in harness sintetici con mock e bypass documentati. **Possono essere tutti verdi mentre l’app è rotta sul telefono.**

Ogni modifica richiede **`bash scripts/verify.sh`** dalla root.

---

## Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [client/scripts/test/README.md](../../client/scripts/test/README.md) | Catalogo comandi client |
| [PROM-MULTI-ACCOUNT](../specs/promises/product/PROM-MULTI-ACCOUNT.md) | Promesse multi-account |
| [docs/domain/README.md](../domain/README.md) | Modello e `check-model-sync` |
