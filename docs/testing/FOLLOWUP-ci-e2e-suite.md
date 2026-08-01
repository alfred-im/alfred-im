# Follow-up: suite CI e Playwright (post-merge PR #231)

**Data:** 2026-08-01 (agg. fine sessione)  
**Contesto:** tier Playwright in CI ripristinati a spec documentati (PR #232+).

---

## Stato attuale

| Layer | Stato |
|-------|--------|
| Gate Dart (`verify.sh`) | ✅ ~446 test |
| CI full-suite step 1–5 | ✅ stack, SQL smoke, integration, Dart `@stack`, build web |
| CI Playwright step 6 | ✅ **9 spec** (~2.2 min headless) |
| `e2e/` intero | ❌ non usare — `push-bug-repro` (headed), `push-registration` (debug) esclusi |

### Step 6 CI — spec inclusi

| Spec | Tier |
|------|------|
| `photo-resume-session-repro` | flusso-reale ★ |
| `inbox-open-chat` | e2e-nav-local |
| `chat-inbox-parity` | e2e-nav-local |
| `manual-push-poison-repro` | e2e-nav-local |
| `multi-account-persist` | e2e-multi |
| `multi-account-messages` | e2e-multi |
| `account-switch-restore` | e2e-nav-local |
| `push-full` | e2e-push-local |
| `push-tap-multi-account` | e2e-push-local |

### Fuori CI (tenere nel repo)

| Spec | Motivo |
|------|--------|
| `push-bug-repro` | Agente locale headed; `test.skip(CI)` |
| `push-registration` | Subset debug di `push-full` |

### Rimossi

- `pages-smoke.spec.ts`, `inbox-load.spec.ts` — fragili/duplicati

---

## Fix harness applicati

| Fix | File |
|-----|------|
| `fillFlutterTextField` (login password 2° account) | `e2e/helpers/multi-account.ts` |
| `closeDrawerIfOpen` multi-strategy (toggle, scrim, Escape) | idem |
| `ensureInboxReady` prima di compose | idem |
| `assertImageInUi: false` + assert DB per foto headless | `chat-media.ts`, `multi-account-messages` |
| `ALFRED_DIAGNOSTIC_LOG=true` in build CI | `ci-serve-flutter-web.sh` |
| `account-switch-restore`: tap inbox dopo switch (no auto-restore chat) | spec allineato al prodotto |

---

## Comandi

```bash
cd client && bash scripts/verify.sh
bash scripts/test.sh flusso-reale
cd client && npx playwright test e2e/photo-resume-session-repro.spec.ts e2e/inbox-open-chat.spec.ts ... --workers=1
```
