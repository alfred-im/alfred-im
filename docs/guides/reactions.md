# Reazioni emoji su messaggi

**Contratto:** [PROM-MESSAGE-REACTIONS](../specs/promises/product/PROM-MESSAGE-REACTIONS.md) · [SURF-CHAT](../specs/surfaces/SURF-CHAT.md)

Regole prodotto (picker, append-only, overlay): solo nei file promessa/superficie sopra — non duplicate qui.

---

## Backend

| Elemento | Dettaglio |
|----------|-----------|
| RPC | `apply_message_reaction` / `withdraw_message_reaction` — accodano outbox `reaction_fact`; worker INSERT append-only su `message_reaction_facts` |
| Lettura | `list_message_reactions` / join in `list_peer_messages` |
| Migrazione | `supabase/migrations/*message_reaction*` |

Contratto: [contracts/rpc.md](../specs/contracts/rpc.md)

---

## Client

| File | Ruolo |
|------|--------|
| `message_bubble.dart` | Overlay reazioni su tap messaggio |
| `message_reactions_merge.dart` | Merge aggregati su lista messaggi |
| `models/reaction_summary.dart` | Modello aggregato UI |
| `data/emoji_catalog.dart` | Catalogo emoji picker |
| `machines/messaging/messaging_effects.dart` | Fetch/merge reazioni realtime |

Test gate: `client/test/widget/message_bubble_test.dart` (overlay reazioni)
