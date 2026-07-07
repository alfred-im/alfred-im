# Handoff sessione — 2026-07-06

Documento per AI — **leggere prima di task multi-account, messaggistica o gruppi**.

---

## Stato repository

| Item | Valore |
|------|--------|
| Branch `main` | PR Alpha **#108–#162** (gruppi #162 in review) |
| Alpha live | https://alfred-im.github.io/XmppTest/ — ultimo `deploy-alpha` riuscito |
| Multi-account | Manifest tutti gli account; **una** GoTrue in RAM (focus) |
| Messaggistica | Modello **caselle** (`MAILBOX-*`): archivio per `owner_id`, outbox sempre, spunte `delivered_at`/`read_at` |
| **Ricezione filtrata** | **`RECEPTION-ALLOWLIST`**: allow list sempre attiva; lista vuota = nessun recapito; rifiuto silenzioso (✓ senza ✓✓) |
| **Gruppi** | **`GROUP-CORE` + `GROUP-DELIVERY`**: account `profile_kind = group`; partecipazione allow list bidirezionale; erogazione automatica; shell senza inbox; `original_author_id` canonico; UI autore avatar+nome |
| Chat media | Testo, GIF, voice (WebM), location (OSM) |

---

## Breaking change allow list (#161)

- Ogni account parte con **`reception_allowlist` vuota** → nessuno può consegnare messaggi finché non si aggiunge qualcuno in **Persone consentite** (icona inbox accanto a Contatti).
- Account esistenti: **nessuna** voce pre-popolata; aggiunta manuale obbligatoria per ripristinare recapito.
- Mittente non in lista: RPC **ok**, copia mittente su server (✓), **mai** `delivered_at` (no ✓✓) — non è errore di invio.
- Rubrica (`contacts`) **≠** allow list.

---

## Gruppi (#162) — sintesi

| Concetto | Comportamento |
|----------|---------------|
| Identità | Gruppo = account Alfred (`profile_kind = group`), registrazione con email reale |
| Partecipazione | Solo allow list **bidirezionale** — nessuna membership / inviti |
| Shell gruppo | No `list_inbox`; `GroupConversationScreen` + allow list + profilo |
| Invio umano→gruppo | Storico gruppo + erogazione automatica ai membri in allow list |
| Broadcast | **Una** riga storico gruppo + fan-out proxy (`broadcast_message_to_allowlist`) |
| Autore UI | `original_author_id` = chi ha scritto; header con avatar + `display_name` (non `@username`) |
| Spunte umano→gruppo | ✓✓ = recapito al **gruppo**; erogazione verso terzi non tocca spunte originali |

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
3. `docs/implementation/groups-client.md` — shell gruppo, controller, UI autore
4. `docs/fixes/multi-account-single-active-gotrue-pr152.md` — fix web switch inbox
5. `docs/implementation/multi-account-client.md` §3.5 — persistenza dichiarativa (PR #147)
6. `docs/architecture/alpha-pr-registry.md` — registro PR → doc
7. `docs/architecture/mailbox-inbox-outbox-spec.md` + `docs/specs/capabilities/MAILBOX-*.spec.md` — messaggistica caselle (PR #159)
8. `docs/specs/capabilities/RECEPTION-ALLOWLIST.spec.md` — allow list ricezione (PR #161)
9. `docs/specs/capabilities/GROUP-CORE.spec.md` + `GROUP-DELIVERY.spec.md` — gruppi (PR #162)
10. `docs/decisions/server-as-reception.md` — semantica spunte a due livelli (✓ accettato server → ✓✓ consegnato destinatario)

---

## Regole operative agente

| Regola | Dettaglio |
|--------|-----------|
| Account debug | **Solo** `alfredagent1` / `alfredagent2` — `docs/AGENT_DEBUG_ACCOUNTS.md` |
| Non toccare | `test1`/`test2`/`test3` |
| Sviluppo | `.cursor-rules.md` — analisi sì; **modifiche solo con conferma** |
| Verifica | `bash scripts/verify.sh` prima di push (**103** test gate) |

---

## Verifica multi-account e gruppi

```bash
cd client && bash scripts/verify.sh
cd client && bash scripts/test.sh integration   # auth + RPC live
cd client && bash scripts/test.sh e2e-multi    # Playwright — Alpha o localhost
```

Smoke SQL gruppi: `supabase/tests/group_schema_smoke.sql`, `group_delivery_smoke.sql`, `group_broadcast_smoke.sql`.

---

## Topic aperti

| Topic | Doc |
|-------|-----|
| Badge / realtime account in background | Rinviato — serve fix BroadcastChannel o upstream |
| Multi-tab stesso browser | Last-write-wins (limite noto) |
| «Disconnetti ovunque» (revoca globale) | Futuro opzionale — logout locale già in `AccountSession.close()` (`single-device-logout-open.md`) |
| Bridge federazione (consumer outbox) | Stub health only — gate allow list anche su bridge (fase B) |
| Preview inbox autore gruppo (REQ-020) | SHOULD non implementato — prefisso autore in `list_inbox` preview |
| Toggle allow list in scheda profilo peer | Fuori scope #161 — scheda profilo peer non esiste |

---

## Indice doc

`docs/INDICE.md`
