# Suite test Alfred (`client/`)

**SSOT catalogo comandi client** — altri file (`AGENTS.md`, `PROJECT_MAP.md`, `README.md`) rimandano qui.

**Verifica (obbligo unico):** [docs/testing/strategy.md](../../../docs/testing/strategy.md) → dalla root, `bash scripts/verify.sh`.  
**SSOT indice:** [docs/SSOT.md](../../../docs/SSOT.md)

Questo file elenca **solo** i comandi del hub client. Non è il catalogo della verifica.

**Entry point:** dalla cartella `client/`:

```bash
bash scripts/test.sh list          # catalogo comandi client
bash scripts/test.sh gate          # igiene (non verifica)
```

Verifica: dalla root del repository, `bash scripts/verify.sh`.

---

## Igiene (non verifica)

`gate.sh` esegue sync spec/modello, `flutter analyze`, `flutter test` su pezzi isolati (mock, fake, harness). **Non** apre l’app e **non** dimostra il prodotto. È la fase 1 di `scripts/verify.sh`.

| Suite | Comando | Cosa fa |
|-------|---------|---------|
| **gate** | `bash scripts/test.sh gate` | `gate.sh` — lint + compile + test isolati (esclusi tag `stack`, `diagnostic`) |
| **unit** | `bash scripts/test.sh unit` | Solo `flutter test` (esclusi tag `stack`) — senza analyze |

Opzione build web sull’igiene: `bash scripts/gate.sh --build` (oppure `bash scripts/verify.sh --build` dalla root, che inoltra e poi esegue lo stack).

**Dart igiene:** `client/test/unit/`, `client/test/widget/`, `client/test/wiring/`, `client/test/composition/`

### Conversation scope (igiene)

| ID | File | Invariante |
|----|------|------------|
| SCOPE-001–004 | `unit/conversation_scope_test.dart` | `ConversationScope`, commit/invalidate, epoch |
| SCOPE-005–006 | `unit/messages_controller_scope_guard_test.dart`, `unit/multi_account_message_store_test.dart` (INV-R4) | Fetch/render solo con scope attivo |
| **SCOPE-008** | `unit/conversation_open_session_test.dart` | Consolidamento GoTrue all'ingresso chat (fase B) |
| SCOPE-008 wiring | `wiring/navigation_wiring_test.dart` | Stack produzione: open peer + sessione |
| **SCOPE-009–012** | `wiring/navigation_open_ingress_test.dart`; `widget/conversation_scope_ingress_test.dart` | Ingresso UI sync prima di refresh inbox; header peer senza sessione in RAM; inbox silent refresh |

### Composition (igiene)

Provider + `AccountSession` dopo `setFocus`. Harness: `client/test/support/composition_harness.dart`.

| ID | File | Invariante |
|----|------|------------|
| COMP-001, COMP-002 | `composition/messaging_session_scope_test.dart` | Messaggi legati a sessione viva (PROM-MULTI-ACCOUNT-022) |
| COMP-003 | `widget/inbox_provider_lifecycle_test.dart` | Inbox non dispose al focus switch |

Script: `scripts/check-composition-sync.sh` (invocato da `gate.sh`).

---

## Comandi stack locale (mirati, non verifica)

Richiedono Docker + `supabase start` dove indicato. Lo stack completo gira già dentro `bash scripts/verify.sh`.

| Suite | Comando | Cosa verifica |
|-------|---------|---------------|
| **sql-smoke** | `bash scripts/test.sh sql-smoke` | Tutti gli smoke SQL (`supabase/tests/*.sql`) |
| **integration** | `bash scripts/test.sh integration` | Login agenti CI + RPC inbox/peer + **contratto spunte** |
| **integration-ticks** | `bash scripts/test.sh integration-ticks` | Solo contratto spunte delivery plane (3 fasi) |
| **integration-push** | `bash scripts/test.sh integration-push` | Smoke SQL `push_*` su stack locale (ad-hoc; verify li esegue già via `sql-smoke`) |
| **stack** | `bash scripts/test.sh stack` | Dart con tag `@Tags(['stack'])` (password reset PKCE su GoTrue locale) |

`e2e`, `release`, `manual`, `ci`, `playwright`, `flusso-reale` **non** sono comandi del hub: se invocati, escono 2 e rimandano a `bash scripts/verify.sh`.

### Playwright (`client/e2e/`)

Spec funzionali nella verifica (non un comando hub):

| File | Ruolo |
|------|-------|
| **`release-snake.spec.ts`** | Serpente unico — eseguito da `scripts/verify.sh` via `ci-release-tests.sh` (`--retries=0`) |
| `demo-live-startup-timing.spec.ts` | Manuale / post-deploy Fly (`ALFRED_BASE_URL`) |

Helper: `e2e/helpers/snake-*.ts`, `local-multi-account.ts`, `focus.ts`, `push.ts`, `peer-relationship.ts`, `backend-assertions.ts`.

Come scrivere nuovi scenari: [docs/testing/strategy.md](../../../docs/testing/strategy.md).

#### Log diagnostici push (`ALFRED_DIAGNOSTIC_LOG`)

Strumentazione in `client/lib/utils/diagnostic_log.dart` — **non** inclusa nelle build Pages.

Lo stack di `scripts/verify.sh` passa `--dart-define=ALFRED_DIAGNOSTIC_LOG=true`. In DevTools (console pagina), filtrare `[alfred][push]`. Fasi attese su tap riuscito: `sw.message` → `open_chat.emit` → `handler.enqueue` → `focus.ok` → `handler.chat_opened`. Assert nel serpente: `expectPushNavigationDiagnostics`.

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
| `push_notification_listener_test.dart` | Tap notifica / open_chat → chat peer (mock, igiene) |
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
| `scripts/test.sh` | Hub comandi client |
| `scripts/gate.sh` | Igiene (fase 1 di verify) |
| `../../scripts/verify.sh` | Unica verifica (root) |
| `scripts/check-composition-sync.sh` | Catalogo COMP + hygiene wiring JWT |
| `scripts/integration-multi-account.sh` | Integrazione API |
| `scripts/integration-photo-session-repro.sh` | Non è un alias — rimanda a `scripts/verify.sh` (exit 2) |
| `docs/AGENT_DEBUG_ACCOUNTS.md` | Credenziali account agente |
