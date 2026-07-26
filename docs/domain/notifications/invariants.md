# Invarianti — notifications

**Bounded context:** `notifications`  
**Implementazione:** `client/lib/models/push_conversation_key.dart`, `client/lib/utils/message_preview.dart`  
**Confine prodotto:** [PROM-PUSH-NOTIFY](../../specs/promises/product/PROM-PUSH-NOTIFY.md)

---

## Chiave conversazione push

1. Ogni notifica/intent 1:1 identifica **(owner, peer)** — formato `owner|peer` (`PushConversationKey.canonicalKey`).
2. Stesso formato di outbound queue e scope messaggistica — mai «solo peer» senza account.

## Tap push

3. `OpenConversation` con focus sul **destinatario** notifica — vedi [navigation/invariants.md § No stale chat](../navigation/invariants.md#no-stale-chat).

## Preview

4. Testo anteprima push = stessa logica inbox (`message_preview.dart`).
