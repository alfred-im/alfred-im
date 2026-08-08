# Suite test Alfred (`client/`)

**SSOT catalogo comandi** — altri file (`AGENTS.md`, `PROJECT_MAP.md`, `README.md`) rimandano qui.

**Filosofia gate vs release:** [docs/testing/strategy.md](../../docs/testing/strategy.md) · **SSOT indice:** [docs/SSOT.md](../../SSOT.md)

Punto unico per **scoprire** e **lanciare** tutti i test del client.

**Entry point:** dalla cartella `client/`:

```bash
bash scripts/test.sh list          # catalogo completo
bash scripts/test.sh gate          # gate CI (default)
bash scripts/test.sh flusso-reale  # ★ release — stesso percorso del telefono
bash scripts/test.sh manual        # alias di `release` — stack locale completo (`ci-release-tests.sh`)
```

---

## Tier 1 — Gate CI (igiene codice, non prodotto)

Eseguito da `verify.sh` e da GitHub Actions (`release-suite.yml`) su ogni PR/push che tocca `client/**` (o stack release).

**Cosa fa davvero:** `flutter analyze`, sync spec/modello, `flutter test` su pezzi isolati (mock, fake, harness sintetici). **Non** apre l’app, **non** usa il telefono, **non** dimostra che messaggi, media, multi-account o auth funzionano per l’utente.

**Verde al gate ≠ Alfred funziona.** Per quello esiste il tier **flusso-reale** (e le altre suite manuali con browser/DB).

| Suite | Comando | Cosa verifica |
|-------|---------|---------------|
| **gate** | `bash scripts/test.sh gate` | Lint + compile + test isolati (esclusi tag `stack`, `diagnostic`) |

Equivalente diretto: `bash scripts/verify.sh`  
Opzione build web: `bash scripts/verify.sh --build`

**Dart gate:** `client/test/unit/`, `client/test/widget/`, `client/test/wiring/`, `client/test/composition/`

### Tier 1b — Conversation scope (gate)

| ID | File | Invariante |
|----|------|------------|
| SCOPE-001–004 | `unit/conversation_scope_test.dart` | `ConversationScope`, commit/invalidate, epoch |
| SCOPE-005–006 | `unit/messages_controller_scope_guard_test.dart`, `unit/multi_account_message_store_test.dart` (INV-R4) | Fetch/render solo con scope attivo |
| **SCOPE-008** | `unit/conversation_open_session_test.dart` | Consolidamento GoTrue all'ingresso chat (fase B) |
| SCOPE-008 wiring | `wiring/navigation_wiring_test.dart` | Stack produzione: open peer + sessione |
| **SCOPE-009–012** | `wiring/navigation_open_ingress_test.dart`; `widget/conversation_scope_ingress_test.dart` | Ingresso UI sync prima di refresh inbox; header peer senza sessione in RAM; inbox silent refresh |

**Strategia completa:** [docs/testing/strategy.md](../../docs/testing/strategy.md) — gate = igiene; `flusso-reale` = riferimento prodotto.

### Tier 1c — Composition (gate)

Provider + `AccountSession` dopo `setFocus`. Harness: `client/test/support/composition_harness.dart`.

| ID | File | Invariante |
|----|------|------------|
| COMP-001, COMP-002 | `composition/messaging_session_scope_test.dart` | Messaggi legati a sessione viva (PROM-MULTI-ACCOUNT-022) |
| COMP-003 | `widget/inbox_provider_lifecycle_test.dart` | Inbox non dispose al focus switch |

Gate script: `scripts/check-composition-sync.sh`

---

## Tier ★ — Flusso utente reale (quello che conta)

**Comando:** `bash scripts/test.sh flusso-reale`  
**Alias:** `real-flow`, `integration-photo-repro`, `photo-repro`  
**Relazione con `release`:** suite separata (`flutter run`); `release` include lo stesso spec via build statica in step 6 — vedi tier 2 sotto. Obbligatorio prima di release su media / multi-account / auth.

### Riferimento per scrivere test

**Da oggi, ogni test nuovo che conta per la release segue questo file:**

[`client/e2e/photo-resume-session-repro.spec.ts`](../../e2e/photo-resume-session-repro.spec.ts)

Checklist completa: [docs/testing/strategy.md § Come si scrivono i test di release](../../docs/testing/strategy.md#come-si-scrivono-i-test-di-release).

In sintesi: percorso telefono intero, stack locale reale, login da UI, assert su Postgres — **non** altri unit test al posto di questo.

| Cosa | Dettaglio |
|------|-----------|
| **Perché esiste** | Percorso **telefono** end-to-end: browser, tap, drawer, galleria, resume, Supabase e Postgres veri. I test Dart del gate non eseguono nessuno di questi passi. |
| **File** | `e2e/photo-resume-session-repro.spec.ts` (tag `@real-flow`) |
| **Stack** | `supabase start` + Flutter release `:8080` + Playwright |
| **Verifica** | UI + messaggio `image` con `media_url` in archivio mittente **e** destinatario |
| **Scenario** | 4 user + 1 gruppo → focus account 2 → nuova chat → Allega → Galleria → resume → invio foto |

Incidente 2026-07: il gate era tutto verde e il bug era in produzione. **`flusso-reale` è il test di release** — senza quello non c’è release valida.

## Tier 2 — Release (stack locale, in CI)

Richiedono Docker + `supabase start` + browser. Eseguiti da `.github/workflows/release-suite.yml`.

| Suite | Comando | Cosa verifica |
|-------|---------|---------------|
| **sql-smoke** | `bash scripts/test.sh sql-smoke` | Tutti gli smoke SQL (`supabase/tests/*.sql`) |
| **integration** | `bash scripts/test.sh integration` | Login agenti CI + RPC inbox/peer + **contratto spunte** |
| **integration-ticks** | `bash scripts/test.sh integration-ticks` | Solo contratto spunte delivery plane (3 fasi) |
| **integration-push** | `bash scripts/test.sh integration-push` | Smoke SQL `push_*` su stack locale |
| **e2e-push-local** | `bash scripts/test.sh e2e-push-local` | Playwright push locale: ricezione SW + **tap multi-account** |
| **e2e-nav-local** | `bash scripts/test.sh e2e-nav-local` | Playwright navigation locale: inbox tap, switch account restore, push tap/poison |
| **e2e** | `bash scripts/test.sh e2e` | Tutti i Playwright in `client/e2e/` (stack locale) |
| **e2e-multi** | `bash scripts/test.sh e2e-multi` | Multi-account: persistenza F5 + messaggi (testo/foto) |
| **stack** | `bash scripts/test.sh stack` | Dart con tag `@Tags(['stack'])` (password reset PKCE su GoTrue locale) |
| **release** | `bash scripts/test.sh release` | Suite sequenziale stack (alias: `manual`, `ci`) |

### Playwright (`client/e2e/`)

| File | Suite | Note |
|------|-------|------|
| **`photo-resume-session-repro.spec.ts`** | **`flusso-reale`** ★ | Test di release: multi-account + galleria + resume + foto in DB |
| `multi-account-persist.spec.ts` | `e2e-multi` | 2 account, F5, manifest |
| `multi-account-messages.spec.ts` | `e2e-multi` | Testo, foto, switch e spunte (assert DB; img canvas opzionale) |
| `inbox-open-chat.spec.ts` | `e2e-nav-local` | Tap inbox → input chat visibile (cattura spinner infinito) |
| `account-switch-restore.spec.ts` | `e2e-nav-local` | Switch sidebar → inbox + riapertura chat peer |
| `manual-push-poison-repro.spec.ts` | `e2e-nav-local` | Push tap multi-account + mailbox poison |
| `push-tap-multi-account.spec.ts` | `e2e-nav-local`, `e2e-push-local` | Due account → tap notifica → focus destinatario + chat |
| `push-full.spec.ts` | `e2e-push-local`, CI step 6 | Permesso → subscribe → messaggio → notifica in SW |
| `chat-inbox-parity.spec.ts` | `e2e-nav-local`, CI step 6 | Parità inbox ↔ chat |

Helper riusabili: `e2e/helpers/local-multi-account.ts`, `focus.ts`, `push.ts` (`simulateNotificationTap`, `installPushTestEnvironment`).

Lancio: `bash scripts/test.sh e2e-push-local` (avvia Supabase locale, Flutter su `:8080` con VAPID e2e e `ALFRED_DIAGNOSTIC_LOG=true`).  
Per riusare un `flutter run` già avviato sullo stack locale: `E2E_PUSH_REUSE_FLUTTER=1 bash scripts/test.sh e2e-push-local`

**Post-fix navigation/scope:** `bash scripts/test.sh e2e-nav-local` (richiede stack locale già avviato; usa `E2E_PUSH_REUSE_FLUTTER=1` se `:8080` è occupato).

#### Log diagnostici push (`ALFRED_DIAGNOSTIC_LOG`)

Strumentazione in `client/lib/utils/diagnostic_log.dart` — **non** inclusa nelle build Pages.

```bash
cd client && flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0 \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=<anon locale> \
  --dart-define=ALFRED_DIAGNOSTIC_LOG=true
```

In DevTools (console pagina), filtrare `[alfred][push]`. Fasi attese su tap riuscito: `sw.message` → `open_chat.emit` → `handler.enqueue` → `focus.ok` → `handler.chat_opened`. Copertura tap multi-account: `push-tap-multi-account.spec.ts`, `manual-push-poison-repro.spec.ts`.

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

Default `e2e-multi`: stack locale (`supabase start` + Flutter release su `:8080`).

Account CI (solo stack locale): `scripts/ci-agents.env.sh` — `ci-agent1@e2e.local.test` / `ci-agent2@e2e.local.test`.

### Utilità ambiente GUI

| Script | Comando |
|--------|---------|
| Diagnostica | `bash scripts/test.sh diagnose` |
| Reset Chrome CDP | `bash scripts/reset-chrome-cdp.sh` |

Prima di test browser: `bash scripts/diagnose-test-env.sh` (o `test.sh diagnose`).

---

## Riferimenti rapidi

| Dove | Ruolo |
|------|-------|
| `scripts/test.sh` | Hub comandi |
| `scripts/verify.sh` | Implementazione gate (usata da CI) |
| `scripts/check-composition-sync.sh` | Catalogo COMP + hygiene wiring JWT |
| `scripts/integration-multi-account.sh` | Integrazione API |
| `scripts/integration-photo-session-repro.sh` | ★ Flusso utente reale (foto + resume) |
| `scripts/run-photo-repro-e2e-local.sh` | Runner Playwright `flusso-reale` |
| `scripts/run-e2e-multi-account.sh` | Playwright multi-account |
| `docs/AGENT_DEBUG_ACCOUNTS.md` | Credenziali account agente |
