# Indice documentazione

Navigazione per AI.

**SSOT (fonti canoniche — evita duplicati):** [SSOT.md](./SSOT.md)

**Modello:** [domain/README.md](./domain/README.md) · **Promesse:** [specs/registry.md](./specs/registry.md) · **SDD:** [specs/README.md](./specs/README.md)

---

## Ingresso pubblico (GitHub)

| File | Uso |
|------|-----|
| [README.md](../README.md) | Porta d'ingresso del repository — consent-first, getting started |
| [SECURITY.md](../SECURITY.md) | Segnalazione vulnerabilità (Security Advisories) |
| [CODE_OF_CONDUCT.md](../CODE_OF_CONDUCT.md) | Contributor Covenant 2.1 |

---

## Ingresso sessione

| File | Uso |
|------|-----|
| [SSOT.md](./SSOT.md) | **Fonti canoniche** — evita duplicati in tutta la doc |
| [README.md](../README.md) | Panoramica pubblica e link rapidi |
| [PROJECT_MAP.md](../PROJECT_MAP.md) | Mappa progetto — leggere all'inizio di ogni sessione |
| [domain/README.md](./domain/README.md) | Metodo modello (DDD → UML → statechart) |
| [domain/bounded-contexts.md](./domain/bounded-contexts.md) | Bounded context Alfred |
| [specs/registry.md](./specs/registry.md) | Catalogo promesse SYSTEM / PRODUCT / SURFACE |
| [CHANGELOG.md](../CHANGELOG.md) | Cronologia merge e modifiche |

---

## Client e toolchain

- **Web client (Try it)**: https://alfred-im-web.fly.dev/ (Fly)
- **Project page**: https://alfred-im.github.io/ (`org-site/`)
- **Codice**: `client/` · `supabase/` · `bridge-xmpp/` · `bridge-matrix/`
- [client/README.md](../client/README.md) · [`.cursor/rules/cursor-rules.mdc`](../.cursor/rules/cursor-rules.mdc) · [AGENTS.md](../AGENTS.md)
- [AGENT_DEBUG_ACCOUNTS.md](./AGENT_DEBUG_ACCOUNTS.md) — account agente; non toccare test1–4
- [testing/strategy.md](./testing/strategy.md) — gate vs release; **riferimento test:** `client/e2e/release-snake.spec.ts`
- [client/scripts/test/README.md](../client/scripts/test/README.md) — catalogo suite (`e2e`)
- [client/deploy/fly/README.md](../client/deploy/fly/README.md) — deploy Fly, build web (`--pwa-strategy=none`), benchmark avvio demo

---

## Modello (DDD / UML / Statechart)

- [domain/README.md](./domain/README.md) — metodo, workflow, relazione con SDD
- [domain/bounded-contexts.md](./domain/bounded-contexts.md) — contesti e stato modellazione
- [model/uml/README.md](./model/uml/README.md) — convenzioni PlantUML
- `domain/<context>/` — glossario, comandi, eventi per contesto
- `model/uml/<context>/` — diagrammi stati e sequenza
- [../client/lib/machines/README.md](../client/lib/machines/README.md) — statechart client

---

## Architettura

- [architecture/full-stack.md](./architecture/full-stack.md) — client + Supabase
- [architecture/mailbox-inbox-outbox-spec.md](./architecture/mailbox-inbox-outbox-spec.md) — modello caselle
- [architecture/gotham-protocol.md](./architecture/gotham-protocol.md) — federazione Gotham (HTTP/3, Protobuf, id, mapping outbox)
- [specs/contracts/gotham.proto](./specs/contracts/gotham.proto) — contratto wire Gotham
- [architecture/README.md](./architecture/README.md)

---

## Decisioni (ADR)

- [decisions/address-based-messaging.md](./decisions/address-based-messaging.md)
- [decisions/no-internal-external-chat-distinction.md](./decisions/no-internal-external-chat-distinction.md)
- [decisions/server-as-reception.md](./decisions/server-as-reception.md)
- [decisions/bridge-stateless.md](./decisions/bridge-stateless.md)
- [decisions/multi-account-parallel-sessions.md](./decisions/multi-account-parallel-sessions.md)
- [decisions/single-device-logout-open.md](./decisions/single-device-logout-open.md)
- [decisions/README.md](./decisions/README.md)

---

## Guide operative

- [guides/README.md](./guides/README.md) — indice guide
- [guides/multi-account.md](./guides/multi-account.md)
- [guides/groups.md](./guides/groups.md)
- [guides/peer-profile.md](./guides/peer-profile.md)
- [guides/shareable-link.md](./guides/shareable-link.md)
- [guides/media.md](./guides/media.md)
- [guides/inbox.md](./guides/inbox.md)
- [guides/chat-scroll.md](./guides/chat-scroll.md)
- [guides/reactions.md](./guides/reactions.md)

---

## Altro

- [wishes/README.md](./wishes/README.md) — esplorazioni e wish non vincolanti
- [wishes/protected-evidence-vault.md](./wishes/protected-evidence-vault.md) — custodia asimmetrica / vault prove protette
- [WISHLIST.md](./WISHLIST.md) — backlog funzionalità (XMPP, UI)
- [specs/contracts/schema.md](./specs/contracts/schema.md) · [rpc.md](./specs/contracts/rpc.md)

**Ultimo aggiornamento**: 2026-09-03
