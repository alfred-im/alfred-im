# SSOT — Single Source of Truth (documentazione)

**Audience:** AI / maintainer  
**Ultima revisione:** 2026-08-08

Per ogni **tipo di informazione** esiste **un** documento canonico. Gli altri file **rimandano** al SSOT — non duplicano tabelle RPC, cataloghi promesse, comandi test, regole account o flussi delivery.

**Regola:** se aggiorni un fatto, modifica **solo** il SSOT della riga. Se lo stesso contenuto appare in due posti, il secondo deve diventare un link.

**Indice navigazione:** [INDICE.md](./INDICE.md) · ingresso sessione: [PROJECT_MAP.md](../PROJECT_MAP.md)

---

## Matrice SSOT

| Informazione | SSOT (solo qui) | Rimanda qui — non duplicare |
|--------------|----------------|-----------------------------|
| **Processo agente** (regola 0, SDD, modello) | [`.cursor/rules/cursor-rules.mdc`](../.cursor/rules/cursor-rules.mdc) | `AGENTS.md` (solo VM/toolchain) |
| **Mappa sessione** (stack, URL, dove sta il codice) | [`PROJECT_MAP.md`](../PROJECT_MAP.md) | `README.md` (solo teaser); `full-stack.md` |
| **Ingresso pubblico OSS** | [`README.md`](../README.md) | — |
| **Catalogo promesse** (ID, stato, binding) | [`specs/registry.md`](./specs/registry.md) | `full-stack.md` § aree; `WISHLIST.md` «Già» |
| **Testo promessa** (MUST/SHOULD, tracciabilità) | File in `specs/promises/` · `specs/surfaces/` | Guide (solo puntatori) |
| **Processo SDD** (lifecycle, classi) | [`specs/README.md`](./specs/README.md) | `README.md` Contributing (teaser) |
| **DDL, enum, RLS, tabelle** | [`specs/contracts/schema.md`](./specs/contracts/schema.md) | `SYS-*.md` §3 sintesi; ADR |
| **Firme RPC, semantica SQL** | [`specs/contracts/rpc.md`](./specs/contracts/rpc.md) | ADR; `SYS-*.md` §3 |
| **Payload push** (campi SW) | [`specs/contracts/push-payload.md`](./specs/contracts/push-payload.md) | `SYS-PUSH` · `SYS-PUSH-PAYLOAD` in [registry.md](./specs/registry.md) |
| **Modello mailbox** (archivio, outbox, worker, λ) | [`architecture/mailbox-inbox-outbox-spec.md`](./architecture/mailbox-inbox-outbox-spec.md) | `full-stack.md`; ADR (principi) |
| **Protocollo Gotham** (federazione wire, Protobuf, id) | [`architecture/gotham-protocol.md`](./architecture/gotham-protocol.md) · [`specs/contracts/gotham.proto`](./specs/contracts/gotham.proto) | `domain/federation/`; `full-stack.md` (teaser) |
| **Semantica spunte UI** (✓ / ✓✓ / blu = cloud) | [`decisions/server-as-reception.md`](./decisions/server-as-reception.md) | Mailbox (meccanica, non significato UI) |
| **Indirizzo + rubrica isolata** | [`decisions/address-based-messaging.md`](./decisions/address-based-messaging.md) | Guide compose |
| **Altri ADR** (bridge, multi-account, …) | [`decisions/`](./decisions/) | `full-stack.md` |
| **Metodo modello** (DDD → UML → statechart) | [`domain/README.md`](./domain/README.md) | `specs/README.md` (solo confine) |
| **Comandi/eventi per contesto** | `domain/<context>/` | Guide; promesse (link) |
| **Diagrammi UML** | `model/uml/<context>/` | Guide |
| **Statechart client** | `client/lib/machines/<context>/` | Guide |
| **Guida operativa feature** | [`guides/<topic>.md`](./guides/) | Promesse (regole); domain (significato) |
| **Gate vs release** (filosofia test) | [`testing/strategy.md`](./testing/strategy.md) | `README.md` (tabella breve) |
| **Comandi test** (catalogo suite) | [`client/scripts/test/README.md`](../client/scripts/test/README.md) | `AGENTS.md` (hub); `PROJECT_MAP` (teaser) |
| **Account debug agente** | [`AGENT_DEBUG_ACCOUNTS.md`](./AGENT_DEBUG_ACCOUNTS.md) | `AGENTS.md`; promesse (scenario manuale → `ci-agent*`) |
| **Credenziali CI locale** | [`scripts/ci-agents.env.sh`](../scripts/ci-agents.env.sh) | Solo stack `supabase start` |
| **Cronologia merge** (archeologia) | [`CHANGELOG.md`](../CHANGELOG.md) | Non SSOT per comportamento attuale |
| **Wish / federazione futura** | [`wishes/`](./wishes/) · [`WISHLIST.md`](./WISHLIST.md) | Registry `implemented` |
| **Log diagnostici agente** (`[alfred]`) | [`AGENTS.md`](../AGENTS.md) § Log diagnostici | Non promessa SDD |

---

## Torre (chi governa cosa)

```text
.cursor/rules/cursor-rules.mdc          processo (regola 0, SDD, modello)
        │
        ├─ domain/ + model/uml/ + machines/     significato + forma + transizioni
        │
        ├─ specs/registry.md + promises/        confine prodotto osservabile
        │
        ├─ specs/contracts/                       piattaforma (DDL + RPC)
        │
        ├─ architecture/mailbox-… + decisions/  architettura vincolante
        │
        └─ guides/ + testing/                   operativo (link ai SSOT sopra)
```

**SDD non duplica il modello.** **Guide non duplicano promesse.** **ADR non duplicano `contracts/`.**

---

## Per tipo di task

| Task | Leggi / aggiorna |
|------|----------------|
| Nuova RPC o colonna | `contracts/` → `SYS-*.md` tracciabilità → `registry.md` se nuova promessa |
| Nuovo comportamento UI | `domain/` + UML → `specs/` (PRODUCT/SURFACE) → `guides/` (opzionale, link) |
| Capire «cosa promette l'app» | `registry.md` → file promessa |
| Capire delivery post-#179 | `mailbox-inbox-outbox-spec.md` → `contracts/rpc.md` |
| Capire cosa significa ✓✓ | `server-as-reception.md` |
| Eseguire test | `client/scripts/test/README.md` · filosofia: `testing/strategy.md` |
| Debug account | `AGENT_DEBUG_ACCOUNTS.md` |
| Orientamento repo | `PROJECT_MAP.md` → questo file se dubbio su duplicati |

---

## Anti-pattern (da eliminare se trovati)

| Vietato | SSOT corretto |
|---------|----------------|
| Tabella RPC completa in ADR | `contracts/rpc.md` |
| Lista promesse aggiornata in `full-stack.md` | `registry.md` |
| Regole MUST duplicate in guide | File `PROM-*` / `SURF-*` |
| Credenziali test in più file | `ci-agents.env.sh` (locale) · niente credenziali live in repo |
| Comandi test copiati in 4 README | `client/scripts/test/README.md` |
| Flusso delivery diagrammato in 3 posti | `mailbox-inbox-outbox-spec.md` |

---

## Documenti indice (non SSOT di contenuto)

| File | Ruolo |
|------|--------|
| [INDICE.md](./INDICE.md) | Navigazione per area |
| [architecture/README.md](./architecture/README.md) | Ingresso architettura |
| [decisions/README.md](./decisions/README.md) | Indice ADR |
| [guides/README.md](./guides/README.md) | Indice guide → promesse |
| [specs/promises/system/README.md](./specs/promises/system/README.md) | Ingresso SYSTEM → `contracts/` |
