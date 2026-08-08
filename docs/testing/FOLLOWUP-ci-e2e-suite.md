# Follow-up: suite CI e Playwright (post-merge PR #231)

**Data:** 2026-08-08 (snapshot stato suite)  
**Contesto:** tier Playwright in CI ripristinati a spec documentati (PR #232+).

---

## Stato attuale

| Layer | Stato |
|-------|--------|
| Gate Dart (`verify.sh`) | ✅ 481 test |
| CI release-suite step 1–5 | ✅ stack, SQL smoke, integration, Dart `@stack`, build web |
| CI Playwright step 6 | ✅ **9 spec** (`e2e/` intero, ~2.6 min headless) |

### Spec in `client/e2e/` (9)

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

### Rimossi

| Spec | Motivo |
|------|--------|
| `pages-smoke.spec.ts` | Fragile su canvas Flutter |
| `inbox-load.spec.ts` | Duplicato/fragile |
| `push-registration.spec.ts` | Subset di `push-full` (registrazione + assert `device_id`) |
| `push-bug-repro.spec.ts` | Headed/debug; coperto da `push-tap-multi-account` in CI |

---

## Comandi

```bash
cd client && bash scripts/verify.sh
bash scripts/test.sh flusso-reale
cd client && npx playwright test e2e/ --workers=1
```
