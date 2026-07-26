# Contesto: delivery

**Stato modellazione:** `documented`

## Mapping dominio → implementazione

| Dominio | Implementazione |
|---------|-----------------|
| `QueueDelivery` | outbox `event_kind = deliver` |
| `QueueReadReceipt` | outbox `event_kind = read_receipt` |
| `QueueGroupFanOut` | outbox `event_kind = group_erogate` |
| `QueuePushNotification` | outbox `event_kind = push_notify` |
| `ProcessDeliveryQueue` | `alfred_delivery.process_outbox` |
| `DeliverInternal` | `alfred_delivery.deliver_internal` |
| `PropagateReadReceipt` | `alfred_delivery.propagate_read_receipt` |
| `GroupErogate` | `alfred_delivery.group_erogate` |
| `ErogateGroupMessage` | `alfred_delivery.erogate_group_message` |
| `ProcessPushNotification` | `alfred_delivery.process_push_notify` |
| `RecipientNotified` | INSERT copia destinatario + `delivered_at` mittente |
| `DeliverySilentlyBlocked` | outbox `completed` + flag reception; nessuna copia destinatario |

Schema: `alfred_delivery` · Migrazioni: `20260711190000_account_boundary_delivery.sql`, `20260714100000_push_subscriptions.sql`, `20260725100000_delivery_internal_helpers.sql`
