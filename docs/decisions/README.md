# Decisioni Architetturali (ADR)

Architecture Decision Records. Documento per AI.

## Decisioni vincolanti (Alpha)

| ADR | Summary |
|-----|---------|
| [address-based-messaging.md](./address-based-messaging.md) | Messaggistica per indirizzo; inbox on-read; archivio per-owner (MAILBOX-*) |
| [no-internal-external-chat-distinction.md](./no-internal-external-chat-distinction.md) | Nessuna distinzione chat interna/esterna a tutti i livelli |
| [bridge-stateless.md](./bridge-stateless.md) | Bridge senza stato di business; verità su Supabase |
| [server-as-reception.md](./server-as-reception.md) | Ricezione = ricezione sul server (spunte cloud) |
| [multi-account-parallel-sessions.md](./multi-account-parallel-sessions.md) | Multi-account client Alpha: UX #140, una GoTrue attiva #152 |
| [single-device-logout-open.md](./single-device-logout-open.md) | ✅ Logout locale (`close()` senza revoca GoTrue); futuro: «Disconnetti ovunque» |
| [mailbox-inbox-outbox-spec.md](../architecture/mailbox-inbox-outbox-spec.md) | ✅ Modello caselle — archivio per owner, outbox sempre (PR #159) |
