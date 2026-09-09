# Federation — contesto dominio

**Bounded context:** `federation`  
**Stato modellazione:** `documented`  
**Ultima revisione:** 2026-09-09

Messaggistica **tra istanze Alfred** (`user@server`). Il prodotto è federato per definizione; il nome del protocollo wire compare solo nel contratto tecnico.

---

## Stato

| Componente | Stato |
|------------|-------|
| Contratto wire + Protobuf | ✅ |
| Schema DB (outbox, `peer_external_address`, rubrica federata) | ✅ |
| Gateway Gotham + worker runtime | ❌ pianificato |

---

## Documenti

| File | Contenuto |
|------|-----------|
| [glossary.md](./glossary.md) | Termini |
| [commands-and-events.md](./commands-and-events.md) | Comandi/eventi dominio |
| [../../architecture/gotham-protocol.md](../../architecture/gotham-protocol.md) | Contratto wire (§ 5.4 allow list locale + esterna; § 7 runtime da implementare) |

Demo paritarie Arkham / Blackgate: [client/deploy/README.md](../../../client/deploy/README.md#istanze-demo).
