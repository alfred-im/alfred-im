# Handoff sessione — 2026-07-02 (multi-account completo)

Documento per AI — **leggere prima di qualsiasi task multi-account**.

---

## Stato repository

| Item | Valore |
|------|--------|
| Branch `main` | #140–#152 — multi-account **funzionante** su web (persistenza + switch inbox) |
| Alpha live | https://alfred-im.github.io/XmppTest/ — ultimo deploy-alpha riuscito |
| Multi-account runtime | **Una** sessione GoTrue in RAM (focus); manifest con tutti gli account |

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
4. `docs/implementation/multi-account-persistence-redesign.md` — storico persistenza (implementato)

---

## Regole operative agente

| Regola | Dettaglio |
|--------|-----------|
| Account debug | **Solo** `alfredagent1` / `alfredagent2` — `docs/AGENT_DEBUG_ACCOUNTS.md` |
| Non toccare | `test1`/`test2`/`test3` |
| Sviluppo | `.cursor-rules.md` — analisi sì; **modifiche solo con conferma** |
| Verifica | `bash scripts/verify.sh` prima di push |

---

## Verifica multi-account

```bash
cd client && bash scripts/verify.sh
bash scripts/integration-multi-account.sh
bash scripts/test.sh e2e-multi    # Playwright — Alpha o localhost
```

---

## Topic aperti

| Topic | Doc |
|-------|-----|
| Badge / realtime account in background | Rinviato — serve fix BroadcastChannel o upstream |
| Multi-tab stesso browser | Last-write-wins (limite noto) |
| Logout solo dispositivo | `decisions/single-device-logout-open.md` |

---

## Indice doc

`docs/INDICE.md`
