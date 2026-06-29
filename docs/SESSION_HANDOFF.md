# Handoff sessione — 2026-06-29 (multi-account PR #143)

Documento per AI — **leggere prima di qualsiasi task**. Stato dopo merge #143 su `main`.

---

## Stato repository

| Item | Valore |
|------|--------|
| Branch `main` | Include #140, #142, **#143** (logout locale + multi-account fix + test regressione) |
| Alpha live | https://alfred-im.github.io/XmppTest/ — **ultimo `deploy-alpha` riuscito**, non necessariamente ultimo push `main` finché CI non completa |
| `verify.sh` | 59 test (esclusi tag `live`) — verde al merge |

---

## Recap conversazione utente (critico)

L'utente ha segnalato tre bug multi-account. Il branch #143 contiene fix **plausibili** ma l'utente ha confermato che **in browser l'app resta rotta**:

1. **Logout globale** — voleva solo locale → fix `close()` senza `signOut`
2. **Chat vuota** nel pannello (inbox ok) → fix view per account + inbox lifecycle + error surfacing parziale
3. **F5 perde account** / chat reciproca rotta → fix persistenza atomica + view per account

**Lezione**: test unitari con mock **non** equivalgono a validazione app. L'utente ha rifiutato l'interpretazione «test verdi = fix ok».

Punti **4–5** review architetturale: **non** implementati per richiesta esplicita.

---

## PR #143 — contenuto merge

Vedi `docs/fixes/multi-account-chat-persistence-pr143.md` (causa, fix, gap test, checklist).

Commit principali:

- `fix(auth): logout locale senza revoca GoTrue`
- `fix(multi-account): scope chat, outbound queue e sync profili`
- `fix(multi-account): per-account view state for mutual conversations`
- `fix(multi-account): stop Provider disposing session InboxController`
- `fix(multi-account): persist all open accounts across refresh`
- `test: regression suite for multi-account chat and persistence`

---

## Regole operative agente

| Regola | Dettaglio |
|--------|-----------|
| Account debug | **Solo** `alfredagent1` / `alfredagent2` — `docs/AGENT_DEBUG_ACCOUNTS.md` |
| Non toccare | `test1`/`test2`/`test3` — incidente password 2026-06-29 |
| Non fare | `POST /auth/v1/logout` su account utente |
| Sviluppo | `.cursor-rules.md` — comando esplicito prima di codice |
| Debug browser | CDP `:9222` spesso morto — `scripts/diagnose-test-env.sh`, `reset-chrome-cdp.sh` |
| Non riavviare Flutter | Senza motivo — preferire kill Chrome |

---

## Verifica pre-task

```bash
cd client && bash scripts/verify.sh
bash client/scripts/integration-multi-account.sh   # API live, no browser
```

---

## Topic ancora aperti

| Topic | Doc / nota |
|-------|------------|
| Validazione UI post-#143 | Utente — F5, 2 account, chat reciproca |
| E2E multi-account | Non implementato |
| Rate limit email GoTrue | Dashboard Supabase |
| Architettura punti 4–5 | Non in scope #143 |

---

## Indice doc

`docs/INDICE.md` — fix #143, handoff, multi-account implementation.
