# Follow-up: suite CI e Playwright (post-merge PR #231)

**Aggiornato:** 2026-09-27 — verifica unica `bash scripts/verify.sh` (root).

---

## Stato attuale

| Layer | Stato |
|-------|--------|
| Igiene (`client/scripts/gate.sh`) | ✅ unit/wiring/composition — fase 1 di verify |
| Stack (`scripts/ci-release-tests.sh`) | ✅ SQL smoke, integration, Dart `@stack`, build web, Playwright |
| Verifica | ✅ un comando: `bash scripts/verify.sh` |

### Spec in `client/e2e/` (2)

| Spec | Ruolo |
|------|-------|
| `release-snake` | Serpente unico — eseguito da verify |
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

`e2e`, `playwright`, `release`, `manual`, `ci`, `all-manual`, `flusso-reale` — usare `bash scripts/verify.sh` dalla root.

---

## Comandi

```bash
bash scripts/verify.sh
```
