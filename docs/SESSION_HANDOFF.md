# Handoff sessione — 2026-07-04

Documento per AI — **leggere prima di task multi-account o messaggistica**.

---

## Stato repository

| Item | Valore |
|------|--------|
| Branch `main` | PR Alpha **#108–#160** (mailbox #159) |
| Alpha live | https://alfred-im.github.io/XmppTest/ — ultimo `deploy-alpha` riuscito |
| Multi-account | Manifest tutti gli account; **una** GoTrue in RAM (focus) |
| Messaggistica | Modello **caselle** (`MAILBOX-*`): archivio per `owner_id`, outbox sempre, spunte `delivered_at`/`read_at` |
| Chat media | Testo, GIF, voice (WebM), location (OSM) |

---

## Architettura multi-account (sintesi)

| Layer | Comportamento |
|-------|---------------|
| **UX** (PR #140) | Shell sempre visibile; overlay auth; switch = focus UI; `AccountViewState` per account |
| **Persistenza** (PR #147) | `alfred_saved_accounts` scritto dichiarativamente da `AccountSession`; no `saveAllAccounts` runtime |
| **Connessione** (PR #152) | Una GoTrue attiva; `setFocus` = dispose + restore; fix BroadcastChannel web |

**Non reintrodurre** N client GoTrue paralleli su web senza fix upstream ([#1085](https://github.com/supabase/supabase-flutter/issues/1085)).

---

## Doc di riferimento (ordine lettura)

1. `docs/decisions/multi-account-parallel-sessions.md` — ADR vincolante (§2.6 runtime)
2. `docs/implementation/multi-account-client.md` — flussi codice
3. `docs/fixes/multi-account-single-active-gotrue-pr152.md` — fix web switch inbox
4. `docs/implementation/multi-account-client.md` §3.5 — persistenza dichiarativa (PR #147)
5. `docs/architecture/alpha-pr-registry.md` — registro PR → doc
6. `docs/architecture/mailbox-inbox-outbox-spec.md` + `docs/specs/capabilities/MAILBOX-*.spec.md` — messaggistica caselle (PR #159)

---

## Regole operative agente

| Regola | Dettaglio |
|--------|-----------|
| Account debug | **Solo** `alfredagent1` / `alfredagent2` — `docs/AGENT_DEBUG_ACCOUNTS.md` |
| Non toccare | `test1`/`test2`/`test3` |
| Sviluppo | `.cursor-rules.md` — analisi sì; **modifiche solo con conferma** |
| Verifica | `bash scripts/verify.sh` prima di push (82 test gate) |

---

## Verifica multi-account

```bash
cd client && bash scripts/verify.sh
cd client && bash scripts/integration-multi-account.sh
cd client && bash scripts/test.sh e2e-multi    # Playwright — Alpha o localhost
```

---

## Topic aperti

| Topic | Doc |
|-------|-----|
| Badge / realtime account in background | Rinviato — serve fix BroadcastChannel o upstream |
| Multi-tab stesso browser | Last-write-wins (limite noto) |
| «Disconnetti ovunque» (revoca globale) | Futuro opzionale — logout locale già in `AccountSession.close()` (`single-device-logout-open.md`) |
| Bridge federazione (consumer outbox) | Stub health only — vedi `docs/architecture/alpha-full-stack.md` |

---

## Indice doc

`docs/INDICE.md`
