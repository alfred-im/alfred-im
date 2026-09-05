# Suite test Alfred (`client/`)

**SSOT catalogo comandi** — altri file (`AGENTS.md`, `PROJECT_MAP.md`, `README.md`) rimandano qui.

**Filosofia gate vs release:** [docs/testing/strategy.md](../../../docs/testing/strategy.md) · **SSOT indice:** [docs/SSOT.md](../../../docs/SSOT.md)

Punto unico per **scoprire** e **lanciare** tutti i test del client.

**Entry point:** dalla cartella `client/`:

```bash
bash scripts/test.sh list          # catalogo completo
bash scripts/test.sh gate          # gate CI (default)
bash scripts/test.sh e2e           # ★ release — serpente Playwright unico
bash scripts/test.sh release       # suite release completa (alias: manual, ci)
```

---

## Tier 1 — Gate CI (igiene codice, non prodotto)

Eseguito da `verify.sh` e da GitHub Actions (`release-suite.yml`) su ogni PR/push che tocca `client/**` (o stack release).

**Cosa fa davvero:** `flutter analyze`, sync spec/modello, `flutter test` su pezzi isolati (mock, fake, harness sintetici). **Non** apre l’app, **non** usa il telefono, **non** dimostra che messaggi, media, multi-account o auth funzionano per l’utente.

**Verde al gate ≠ Alfred funziona.** Per quello esiste il tier **release snake** (`e2e`).

| Suite | Comando | Cosa verifica |
|-------|---------|---------------|
| **gate** | `bash scripts/test.sh gate` | Lint + compile + test isolati (esclusi tag `stack`, `diagnostic`) |
| **unit** | `bash scripts/test.sh unit` | Solo `flutter test` (esclusi tag `stack`) — senza analyze |

Equivalente diretto: `bash scripts/verify.sh`  
Opzione build web: `bash scripts/verify.sh --build`

**Fine lavoro agente / sviluppatore su `client/`:** dopo `verify_ok`, eseguire sempre `bash scripts/test.sh e2e` (vedi `.cursor-rules.md` § Build, `AGENTS.md`).

**Dart gate:** `client/test/unit/`, `client/test/widget/`, `client/test/wiring/`, `client/test/composition/`

### Tier 1b — Conversation scope (gate)

| ID | File | Invariante |
|----|------|------------|
| SCOPE-001–004 | `unit/conversation_scope_test.dart` | `ConversationScope`, commit/invalidate, epoch |
| SCOPE-005–006 | `unit/messages_controller_scope_guard_test.dart`, `unit/multi_account_message_store_test.dart` (INV-R4) | Fetch/render solo con scope attivo |
| **SCOPE-008** | `unit/conversation_open_session_test.dart` | Consolidamento GoTrue all'ingresso chat (fase B) |
| SCOPE-008 wiring | `wiring/navigation_wiring_test.dart` | Stack produzione: open peer + sessione |
| **SCOPE-009–012** | `wiring/navigation_open_ingress_test.dart`; `widget/conversation_scope_ingress_test.dart` | Ingresso UI sync prima di refresh inbox; header peer senza sessione in RAM; inbox silent refresh |

**Strategia completa:** [docs/testing/strategy.md](../../../docs/testing/strategy.md) — gate = igiene; `e2e` = riferimento prodotto.

### Tier 1c — Composition (gate)

Provider + `AccountSession` dopo `setFocus`. Harness: `client/test/support/composition_harness.dart`.

| ID | File | Invariante |
|----|------|------------|
| COMP-001, COMP-002 | `composition/messaging_session_scope_test.dart` | Messaggi legati a sessione viva (PROM-MULTI-ACCOUNT-022) |
| COMP-003 | `widget/inbox_provider_lifecycle_test.dart` | Inbox non dispose al focus switch |

Gate script: `scripts/check-composition-sync.sh`

---

## Tier ★ — Release snake (quello che conta)

**Comando:** `bash scripts/test.sh e2e`  
**Alias:** `flusso-reale`, `real-flow`, `integration-photo-repro`, `photo-repro`  
**Relazione con `release`:** `release` include lo stesso spec via build statica in step 6 di `ci-release-tests.sh`.

### Riferimento per scrivere test

**Ogni nuovo scenario release si aggiunge al serpente** (o a un helper condiviso invocato da lì):

[`client/e2e/release-snake.spec.ts`](../../e2e/release-snake.spec.ts)

Checklist: [docs/testing/strategy.md § Come si scrivono i test di release](../../../docs/testing/strategy.md#come-si-scrivono-i-test-di-release).

| Cosa | Dettaglio |
|------|-----------|
| **Perché esiste** | Percorso **telefono** end-to-end in un solo run: manifest, peer, chat, push, media, instance — browser, tap, drawer, galleria, resume, Supabase e Postgres veri. |
| **File** | `e2e/release-snake.spec.ts` (tag `@release-snake`) |
| **Stack** | `supabase start` + Flutter release `:8080` + Playwright (`--retries=0`) |
| **Cast** | 4 user + gruppo fisso; transizioni SQL tra fasi peer (`snake-transitions.ts`) |
| **Log** | `[snake] YYYY-MM-DD HH:MM:SS >>> step=…` per copertura e timing |

Incidente 2026-07: il gate era tutto verde e il bug era in produzione. **`bash scripts/test.sh e2e`** è il test di release — senza quello non c’è release valida.

## Tier 2 — Release (stack locale, in CI)

Richiedono Docker + `supabase start` + browser. Eseguiti da `.github/workflows/release-suite.yml`.

| Suite | Comando | Cosa verifica |
|-------|---------|---------------|
| **sql-smoke** | `bash scripts/test.sh sql-smoke` | Tutti gli smoke SQL (`supabase/tests/*.sql`) |
| **integration** | `bash scripts/test.sh integration` | Login agenti CI + RPC inbox/peer + **contratto spunte** |
| **integration-ticks** | `bash scripts/test.sh integration-ticks` | Solo contratto spunte delivery plane (3 fasi) |
| **integration-push** | `bash scripts/test.sh integration-push` | Smoke SQL `push_*` su stack locale (ad-hoc; **release** li esegue già via `sql-smoke`) |
| **e2e** | `bash scripts/test.sh e2e` | **Release snake** — unico Playwright gate (`release-snake.spec.ts`) |
| **stack** | `bash scripts/test.sh stack` | Dart con tag `@Tags(['stack'])` (password reset PKCE su GoTrue locale) |
| **release** | `bash scripts/test.sh release` | Suite sequenziale stack (alias: `manual`, `ci`) |

### Playwright (`client/e2e/`)

| File | Suite | Note |
|------|-------|------|
| **`release-snake.spec.ts`** | **`e2e`** ★ | Gate release unico — 19 scenari funzionali in un serpente |
| `demo-live-startup-timing.spec.ts` | manuale / post-deploy Fly | Cronometra splash e transfer su demo live (`ALFRED_BASE_URL`, default `alfred-im-web.fly.dev`) |

Helper riusabili: `e2e/helpers/snake-*.ts`, `local-multi-account.ts`, `focus.ts`, `push.ts`, `peer-relationship.ts`, `backend-assertions.ts`.

Lancio: `bash scripts/test.sh e2e` (avvia Supabase locale, Flutter release su `:8080` con `ALFRED_DIAGNOSTIC_LOG=true`).

#### Log diagnostici push (`ALFRED_DIAGNOSTIC_LOG`)

Strumentazione in `client/lib/utils/diagnostic_log.dart` — **non** inclusa nelle build Pages.

Il dev server e2e passa `--dart-define=ALFRED_DIAGNOSTIC_LOG=true`. In DevTools (console pagina), filtrare `[alfred][push]`. Fasi attese su tap riuscito: `sw.message` → `open_chat.emit` → `handler.enqueue` → `focus.ok` → `handler.chat_opened`. Assert nel serpente: `expectPushNavigationDiagnostics`.

### SQL smoke push (`supabase/tests/` — post SYS-PUSH)

| File | Verifica |
|------|----------|
| `push_subscriptions_schema_smoke.sql` | DDL, indici, UNIQUE |
| `push_subscriptions_rls_smoke.sql` | RLS cross-user negato |
| `push_delivery_trigger_smoke.sql` | Recapito → push_notify; allow list rifiutata → nessun push |
| `push_multi_device_smoke.sql` | Subscription multiple per user_id |

### Dart unit push (post SYS-PUSH)

| File | Verifica |
|------|----------|
| `push_subscription_service_test.dart` | device_id, upsert, delete on close |
| `push_suppression_test.dart` | Matrice focus × peer × visibility |
| `push_preview_test.dart` | Anteprima testo/media allineata inbox |
| `push_notification_listener_test.dart` | Tap notifica / open_chat → chat peer (mock, gate CI) |
| `notification_permission_test.dart` | Matrice permesso push + subscribe-first |

Account CI (solo stack locale): `scripts/ci-agents.env.sh` — `ci-agent1@e2e.local.test` / `ci-agent2@e2e.local.test`.

### Utilità

| Script | Comando |
|--------|---------|
| Diagnostica | `bash scripts/test.sh diagnose` |
| Reset Chrome CDP | `bash scripts/reset-chrome-cdp.sh` |
| SDD spec sync | `bash scripts/test.sh spec-sync` (alias: `sdd`) |

Prima di test browser: `bash scripts/diagnose-test-env.sh` (o `test.sh diagnose`).

---

## Riferimenti rapidi

| Dove | Ruolo |
|------|-------|
| `scripts/test.sh` | Hub comandi |
| `scripts/verify.sh` | Implementazione gate (usata da CI) |
| `scripts/check-composition-sync.sh` | Catalogo COMP + hygiene wiring JWT |
| `scripts/integration-multi-account.sh` | Integrazione API |
| `scripts/integration-photo-session-repro.sh` | Alias → `test.sh e2e` (compatibilità) |
| `docs/AGENT_DEBUG_ACCOUNTS.md` | Credenziali account agente |
