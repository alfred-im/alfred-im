# Decisioni architetturali (ADR)

Architecture Decision Records. Documento per AI.

## Decisioni vincolanti

| ADR | Summary |
|-----|---------|
| [address-based-messaging.md](./address-based-messaging.md) | Messaggistica per indirizzo; inbox on-read; archivio per-owner |
| [no-internal-external-chat-distinction.md](./no-internal-external-chat-distinction.md) | Nessuna distinzione chat interna/esterna |
| [bridge-stateless.md](./bridge-stateless.md) | Bridge senza stato di business; verità su Supabase |
| [server-as-reception.md](./server-as-reception.md) | Ricezione sul server; gate allow list nel worker delivery |
| [multi-account-parallel-sessions.md](./multi-account-parallel-sessions.md) | Multi-account: manifest + focus; una GoTrue attiva |
| [single-device-logout-open.md](./single-device-logout-open.md) | Logout locale; futuro «Disconnetti ovunque» |

Modello caselle: [architecture/mailbox-inbox-outbox-spec.md](../architecture/mailbox-inbox-outbox-spec.md) → [SYS-MAILBOX](../specs/promises/system/SYS-MAILBOX.md).
