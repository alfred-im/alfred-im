# Invarianti — messaging

**Bounded context:** `messaging`  
**Implementazione:** `client/lib/machines/messaging/`, `MessagingCoordinator`  
**Confine prodotto:** [SYS-MAILBOX](../../specs/promises/system/SYS-MAILBOX.md), [PROM-OUTBOUND-SEND](../../specs/promises/product/PROM-OUTBOUND-SEND.md), [PROM-CHAT-PEER-KEY](../../specs/promises/product/PROM-CHAT-PEER-KEY.md)

---

## Conversazione 1:1

1. Chiave conversazione = `peer_profile_id` — mai `thread_id` separato dal peer.
2. Fetch/send/upload solo con [scope navigation](../navigation/invariants.md) commesso e `SessionAuthority.ensureOwnerReady` riuscito.
3. `OutboundMessageQueue` keyed `userId|peerProfileId` — retry non mescola account o peer.
4. Realtime subscribe filtrato su `owner_id` del focus ([PROM-REALTIME-OWNER](../../specs/promises/product/PROM-REALTIME-OWNER.md)).

## Invio e archivio

1. Copia mittente scritta via RPC account; destinatario materializzato solo dal worker ([SYS-ACCOUNT-BOUNDARY](../../specs/promises/system/SYS-ACCOUNT-BOUNDARY.md)).
2. Merge optimistic via `client_message_id` sulla copia mittente; spunte via `logical_message_id`.
3. Reazioni: append-only su `message_reaction_facts` — mai UPDATE distruttivo del fatto ([PROM-MESSAGE-REACTIONS](../../specs/promises/product/PROM-MESSAGE-REACTIONS.md)).

## Gruppi (chat con peer `profile_kind = group`)

1. UI autore obbligatoria su messaggi in chat 1:1 con account gruppo ([PROM-GROUP-AUTHOR-DISPLAY](../../specs/promises/product/PROM-GROUP-AUTHOR-DISPLAY.md)).
2. Spunte limitate al rapporto con il gruppo ([PROM-GROUP-TICKS](../../specs/promises/product/PROM-GROUP-TICKS.md)).
