# Decisioni Architetturali (ADR)

Architecture Decision Records. Documento per AI.

## Decisioni vincolanti (Alpha)

| ADR | Summary |
|-----|---------|
| [address-based-messaging.md](./address-based-messaging.md) | Messaggistica per indirizzo; inbox = aggregazione on-read su `messages` |
| [no-internal-external-chat-distinction.md](./no-internal-external-chat-distinction.md) | Nessuna distinzione chat interna/esterna a tutti i livelli |
| [bridge-stateless.md](./bridge-stateless.md) | Bridge senza stato di business; verità su Supabase |
| [server-as-reception.md](./server-as-reception.md) | Ricezione = ricezione sul server (spunte cloud) |
| [multi-account-parallel-sessions.md](./multi-account-parallel-sessions.md) | Multi-account: N sessioni Supabase parallele; focus solo UI |

## Visione e proposte

| ADR | Summary |
|-----|---------|
| [project-revolution-discovery.md](./project-revolution-discovery.md) | Discovery migrazione Flutter + Supabase + bridge |
| [no-message-deletion.md](./no-message-deletion.md) | No cancellazione messaggi lato protocollo |
| [no-modify-source-data.md](./no-modify-source-data.md) | Non alterare la fonte dati; filtrare in lettura/UI |

Target modello caselle (direzione confermata): [../architecture/mailbox-inbox-outbox-spec.md](../architecture/mailbox-inbox-outbox-spec.md).
