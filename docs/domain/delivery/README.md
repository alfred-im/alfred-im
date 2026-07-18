# Contesto: delivery

**Stato modellazione:** `documented`

Vedi [bounded-contexts.md](../bounded-contexts.md) e [metodo dominio](../README.md).

## Artefatti

| File | Stato |
|------|-------|
| [glossary.md](./glossary.md) | compilato |
| [commands-and-events.md](./commands-and-events.md) | compilato |
| [seq-process-outbox](../../model/uml/delivery/seq-process-outbox.puml) | compilato |
| [seq-reception-gate](../../model/uml/delivery/seq-reception-gate.puml) | compilato |
| Statechart client | **no** — infrastruttura server-only |

## Implementazione runtime

| Componente | Ruolo |
|------------|-------|
| Schema `alfred_delivery` | Worker SQL `SECURITY DEFINER` |
| `process_outbox` | Dispatcher per `event_kind` |
| `deliver_internal` | Recapito 1:1 e verso gruppo + gate reception |
| `group_erogate` / `erogate_group_message` | Broadcast ed erogazione gruppo |
| `process_read_receipt` / `propagate_read_receipt` | Spunte lette |
| Tabella `outbox` | Bus eventi; RLS deny authenticated |
| RPC account | Solo INSERT confine proprio + `perform process_outbox` |

Migrazione canonica: `supabase/migrations/20260711190000_account_boundary_delivery.sql`

## Modello

Internal: worker **sincrono** nella stessa transazione RPC account. Federato: stesso outbox, consumer bridge (stub) — vedi contesto **federation**.

## SDD (confine prodotto)

[SYS-DELIVERY](../../specs/promises/system/SYS-DELIVERY.md) · [SYS-ACCOUNT-BOUNDARY](../../specs/promises/system/SYS-ACCOUNT-BOUNDARY.md) · [mailbox-inbox-outbox-spec.md](../../architecture/mailbox-inbox-outbox-spec.md)

## Contesti correlati

- **messaging** — RPC che accodano outbox
- **reception** — policy gate nel worker
- **groups** — branch gruppo e `group_erogate`
- **federation** — outbox `protocol != internal`
