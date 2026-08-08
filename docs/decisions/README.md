# Decisioni architetturali (ADR)

Architecture Decision Records. **SSOT:** [SSOT.md](../SSOT.md)

| Tipo | SSOT |
|------|------|
| **Principio ADR** (questa cartella) | File `*.md` sotto — indirizzo, cloud reception, bridge, multi-account |
| **Meccanica mailbox / delivery** | [architecture/mailbox-inbox-outbox-spec.md](../architecture/mailbox-inbox-outbox-spec.md) |
| **DDL / RPC** | [specs/contracts/](../specs/contracts/) |
| **Promesse SYSTEM** | [specs/registry.md](../specs/registry.md) |

Contesto prodotto: [`README.md`](../../README.md).

## Decisioni vincolanti

| ADR | Summary |
|-----|---------|
| [address-based-messaging.md](./address-based-messaging.md) | Messaggistica per indirizzo; inbox on-read; rubrica isolata |
| [no-internal-external-chat-distinction.md](./no-internal-external-chat-distinction.md) | Nessuna distinzione chat interna/esterna |
| [bridge-stateless.md](./bridge-stateless.md) | Bridge senza stato di business; verità su Supabase |
| [server-as-reception.md](./server-as-reception.md) | **Semantica UI** spunte cloud (✓ / ✓✓ / blu) |
| [multi-account-parallel-sessions.md](./multi-account-parallel-sessions.md) | Multi-account: manifest + focus; una GoTrue attiva |
| [single-device-logout-open.md](./single-device-logout-open.md) | Logout locale; futuro «Disconnetti ovunque» |

Modello caselle (meccanica): [mailbox-inbox-outbox-spec.md](../architecture/mailbox-inbox-outbox-spec.md) → [SYS-MAILBOX](../specs/promises/system/SYS-MAILBOX.md).
