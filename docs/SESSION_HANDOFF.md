# Handoff sessione — 2026-07-01 (redesign persistenza multi-account)

Documento per AI — **leggere prima di qualsiasi task**.

---

## ⚠️ Priorità assoluta per implementazione

**Leggere e seguire**: [`docs/implementation/multi-account-persistence-redesign.md`](./implementation/multi-account-persistence-redesign.md)

- Analisi design: persistenza **derivata** (rotta su web) vs **dichiarativa** (target)
- **Non** mergiare PR #144 così com’è — pezze su design rotto
- **Non** aggiungere fallback RAM/cache/GoTrue
- Single source of truth: `flutter.alfred_saved_accounts`, scritto da `AccountSession` al login

---

## Stato repository

| Item | Valore |
|------|--------|
| Branch `main` | #140, #142, #143 — persistenza F5 **ancora rotta su web** |
| PR #144 | Draft — **non mergiare**; sostituita dal redesign doc sopra |
| Alpha live | https://alfred-im.github.io/XmppTest/ — ultimo deploy-alpha riuscito |

---

## Recap conversazione utente (critico)

L'utente ha segnalato tre bug multi-account. Fix #143/#144 **non** risolvono il design:

1. **Logout globale** — fix `close()` senza `signOut` (ok su main)
2. **Chat vuota** — parziale; `onSessionEnded` documentato ma non implementato
3. **F5 perde account** — **problema di design persistenza**, non bug puntuale

**Lezione**: test unitari/mock **≠** web mobile. L'utente vuole **refactor pulito**, non altra patch.

---

## PR #143 — cosa tenere

Vedi `docs/fixes/multi-account-chat-persistence-pr143.md`. Tenere fix **runtime** (view per account, inbox lifecycle, logout locale). **Sostituire** logica `_persistAllOpenAccounts`.

---

## Regole operative agente

| Regola | Dettaglio |
|--------|-----------|
| Account debug | **Solo** `alfredagent1` / `alfredagent2` — `docs/AGENT_DEBUG_ACCOUNTS.md` |
| Non toccare | `test1`/`test2`/`test3` |
| Sviluppo | `.cursor-rules.md` — comando esplicito prima di codice |
| Persistenza | Solo secondo `multi-account-persistence-redesign.md` |

---

## Verifica pre-task

```bash
cd client && bash scripts/verify.sh
flutter test test/live/multi_account_persist_live_test.dart --tags live
bash client/scripts/integration-multi-account.sh
```

---

## Topic ancora aperti

| Topic | Doc |
|-------|-----|
| Implementazione redesign persistenza | `implementation/multi-account-persistence-redesign.md` |
| Chat vuota / sessione morta | `fixes/conversations-empty-diagnosis.md` + §7 redesign |
| E2E multi-account F5 | Da fare post-redesign |

---

## Indice doc

`docs/INDICE.md`
