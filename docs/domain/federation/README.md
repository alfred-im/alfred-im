# Contesto: federation

**Stato modellazione:** `documented` (modello documentato; runtime bridge stub)

Vedi [bounded-contexts.md](../bounded-contexts.md) e [metodo dominio](../README.md).

## Artefatti

| File | Stato |
|------|-------|
| [glossary.md](./glossary.md) | compilato |
| [commands-and-events.md](./commands-and-events.md) | compilato |
| [seq-federation-stub](../../model/uml/federation/seq-federation-stub.puml) | compilato |
| Statechart client | **no** — client parla solo con Supabase |

## Implementazione runtime (attuale)

| Componente | Stato |
|------------|-------|
| `bridge-xmpp/main.py` | Stub — `GET /health` su porta 8080 |
| `bridge-matrix/main.py` | Stub — `GET /health` su porta 8081 |
| Outbox `protocol = xmpp\|matrix` | Schema presente; consumer non implementato |
| `sync_cursors`, `bridge_jobs` | Schema piattaforma; RLS deny authenticated |
| Rubrica contatti esterni | Salvataggio `contact_protocol` ✅ |

## Modello target

Stesso pipeline caselle di internal:

1. Account RPC → copia mittente + outbox `queued`
2. Bridge stateless claim job da piattaforma
3. Traduzione protocollo ↔ archivio Alfred (λ, `external_id`)
4. Ack esterni → UPDATE spunte copia mittente

ADR vincolante: [bridge-stateless.md](../../decisions/bridge-stateless.md)

## SDD (confine prodotto)

[SYS-DELIVERY](../../specs/promises/system/SYS-DELIVERY.md) (outbox conmotione) · [SYS-CONTACTS](../../specs/promises/system/SYS-CONTACTS.md) (protocol routing)

## Contesti correlati

- **delivery** — bus outbox condiviso
- **messaging** — invio sempre via piattaforma
- **contacts** — indirizzi XMPP/Matrix in rubrica
