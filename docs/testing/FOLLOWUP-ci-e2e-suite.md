# Follow-up: suite CI e Playwright (post-merge PR #231)

**Aggiornato:** 2026-09-05 — release snake unico (PR #270).

---

## Stato attuale

| Layer | Stato |
|-------|--------|
| Gate Dart (`verify.sh`) | ✅ unit/wiring/composition |
| CI release-suite step 1–5 | ✅ stack, SQL smoke, integration, Dart `@stack`, build web |
| CI Playwright step 6 | ✅ **1 spec** (`release-snake.spec.ts`, ~2 min headless, `--retries=0`) |

### Spec in `client/e2e/` (2)

| Spec | Tier |
|------|------|
| `release-snake` | **`e2e`** ★ — gate release unico (19 scenari) |
| `demo-live-startup-timing` | manuale / post-deploy Fly |

### Rimossi (2026-09 — assorbiti dal serpente)

| Spec | Motivo |
|------|--------|
| `photo-resume-session-repro` | Segmento `core.photo.*` nel serpente |
| `multi-account-persist`, `multi-account-messages` | `core.manifest.*`, `core.chat.*` |
| `inbox-open-chat`, `chat-inbox-parity`, `account-switch-restore` | `core.chat.*` |
| `peer-relationship-*`, `peer-profile-rubrica` | `core.peer.*` |
| `push-full`, `push-tap-multi-account`, `manual-push-poison-repro` | `core.push.*` |
| `instance-config-panel` | `core.instance.*` |
| `pages-smoke`, `inbox-load`, `push-registration`, `push-bug-repro` | Rimossi in precedenza (fragili/duplicati) |

### Comandi rimossi da `test.sh`

`e2e-multi`, `e2e-nav-local`, `e2e-push-local` — usare `bash scripts/test.sh e2e`.  
`flusso-reale` resta come **alias** di `e2e`.

---

## Comandi

```bash
cd client && bash scripts/verify.sh
bash scripts/test.sh e2e
cd client && npx playwright test e2e/release-snake.spec.ts --workers=1 --retries=0
```
