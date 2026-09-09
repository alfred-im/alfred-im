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
| Messaggistica cross-istanza end-to-end | ❌ — **non testabile** finché §7 [gotham-protocol.md](../../architecture/gotham-protocol.md) non è implementato |

Le **due demo** Fly ([Arkham e Blackgate](../../../client/deploy/README.md#istanze-demo)) sono infrastruttura paritetica per il wire futuro — non sostituiscono test locali (`supabase start` + `ci-agent*`) e **non** abilitano federazione oggi.

---

## Ricezione e consenso (già documentato)

Il gate allow list vale **anche** per inbound federato — [SYS-RECEPTION-018](../../specs/promises/system/SYS-RECEPTION.md), [domain/reception](../reception/README.md), [gotham-protocol.md §5.2](../../architecture/gotham-protocol.md#52-inbound-peer--istanza-destinatario):

1. Il worker inbound risolve `from_address` / `to_address` dell'envelope → `profile_id` sulla piattaforma destinataria.
2. Applica lo **stesso** gate di recapito locale: mittente ∈ `reception_allowlist` del destinatario.
3. Su rifiuto: nessuna copia destinatario; silenzio verso il mittente esterno (✓ senza ✓✓).

Outbound (mittente verso `user@server`): stessa semantica consenso del locale — il destinatario deve essere nella allow list del mittente prima dell'accettazione invio. Dettaglio implementativo RPC compose: backlog [gotham-protocol §7.1](../../architecture/gotham-protocol.md#71-backlog-implementazione-ordine-suggerito).

---

## Documenti

| File | Contenuto |
|------|-----------|
| [glossary.md](./glossary.md) | Termini |
| [commands-and-events.md](./commands-and-events.md) | Comandi/eventi dominio |
| [../../architecture/gotham-protocol.md](../../architecture/gotham-protocol.md) | Contratto wire + backlog runtime |
