# Federation — contesto dominio

**Bounded context:** `federation`  
**Ultima revisione:** 2026-09-08

Federazione **nativa Gotham** tra istanze Alfred. Non esistono altri protocolli federativi nel prodotto.

---

## Stato

| Componente | Stato |
|------------|-------|
| Spec wire + Protobuf | ✅ |
| Schema DB (outbox, `peer_external_address`, rubrica federata) | ✅ |
| Gateway + worker runtime | ❌ pianificato |

---

## Documenti

| File | Contenuto |
|------|-----------|
| [glossary.md](./glossary.md) | Termini |
| [commands-and-events.md](./commands-and-events.md) | Comandi/eventi dominio |
| [../../architecture/gotham-protocol.md](../../architecture/gotham-protocol.md) | Contratto wire |
