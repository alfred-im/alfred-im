# Account debug agente

**Audience:** agenti AI / Cursor Cloud — **non** documentazione utente.

**Fonte unica** per regole account di test — vedi anche [SSOT.md](./SSOT.md). Altri file (`AGENTS.md`, promesse) **rimandano qui**.

---

## Stato attuale (live)

| Elemento | Stato |
|----------|--------|
| Account agente su Supabase live (`alfredagent1` / `alfredagent2`) | **Non esistenti** — rimossi 2026-07-12; ricreati senza autorizzazione e **rimossi di nuovo** 2026-08-08 |
| Credenziali live in repository | **Nessuna** — non reintrodurre |
| Default per test agente | Stack **locale** (`supabase start`) + account `ci-agent*` |

Progetto live: `tvwpoxxcqwphryvuyqzu` (demo Pages). **Non** usare il live per script che scrivono dati senza conferma esplicita dell'utente.

---

## Come testare (percorso corretto)

1. `supabase start` (Docker) — vedi [AGENTS.md](../AGENTS.md) § Whole-stack local dev.
2. Account integrazione: `scripts/ci-agents.env.sh` — `ciagent1` / `ciagent2` (`ci-agent1@e2e.local.test`, …).
3. Comandi: `cd client && bash scripts/test.sh integration` · `e2e-multi` · `e2e-push-local` · `release`.

Dettaglio suite: [`client/scripts/test/README.md`](../client/scripts/test/README.md).

---

## Regole obbligatorie

| Azione | Consentito |
|--------|------------|
| Test auth / multi-account / messaggistica su stack **locale** con `ci-agent*` | ✅ Sì |
| `signUp` su live con email inventate / fake | ❌ **Mai** (bounce — vedi incidente 2026-07-09) |
| Modificare password, email o profilo di `test1`–`test4` | ❌ **Mai** |
| `UPDATE auth.users` su account non elencati qui | ❌ **Mai** (salvo istruzione esplicita dell'utente) |
| Ricreare `alfredagent*` sul live senza conferma | ❌ **Mai** |

---

## Account utente live (non modificare)

Presenti nel DB live dell'utente — **non** usare per esperimenti che cambiano credenziali o dati.

| Username | Email (nota) |
|----------|----------------|
| `test1` | `agadriel.sexpositive+1@gmail.com` |
| `test2` | `agadriel.sexpositive+2@gmail.com` |
| `test3` | `agadriel.sexpositive+3@gmail.com` |
| `test4` | `agadriel.sexpositive+4@gmail.com` |

---

## Incidenti (da non ripetere)

### 2026-06-29 — password `test1` / `test2` su live

Un agente ha eseguito `UPDATE auth.users` con nuove password su `test1` e `test2` senza autorizzazione. Password originali **non recuperabili**.

**Lezione:** account dedicati solo su stack locale; mai toccare account dell'utente.

### 2026-07-09 — signup probe su live

`signUp` con email inventate (`redirect-probe-*@gmail.com`) → bounce e avviso deliverability.

**Lezione:** test signup su locale; su live solo con indirizzo reale dell'utente o SQL di conferma senza invio mail.

### 2026-07-12 / 2026-08-08 — account agente su live

Account `alfredagent*` creati o ricreati sul live nonostante policy «solo locale». Rimossi su richiesta utente.

**Lezione:** debug agente = `ci-agent*` locale; se servono account live dedicati, **chiedere** all'utente prima di crearli.

---

**Ultimo aggiornamento:** 2026-08-08
