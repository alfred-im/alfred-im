# Aggancio al fondo conversazione

**Regole prodotto:** [PROM-BOTTOM-ANCHOR](../specs/promises/product/PROM-BOTTOM-ANCHOR.md), [SURF-CHAT-015](../specs/surfaces/SURF-CHAT.md) (caricamento storico verso l'alto).

**Ultima revisione:** 2026-08-08

---

## Implementazione

`AnchoredMessageList` — `ListView` reverse in `anchored_message_list.dart`.

| Concetto | File / costante |
|----------|-----------------|
| Soglia aggancio | `ConversationScrollAnchor.defaultThreshold` = 48 px |
| Caricamento storico | `onLoadOlder` → `list_peer_messages` con `p_before_created_at` |
| Prepend senza salto | `prependOlderMessages` / `fetchAndPrependOlderMessages` in `MessagesController` |
| Pulsante ↓ + badge | `_JumpToBottomButton` in `anchored_message_list.dart` (`_pendingBelow`, cap `99+`) |

### Pulsante salta al fondo

Quando la lista è **staccata** (`!_isAttached`), FAB circolare in basso a destra. Tap → `animateTo(0)`, riaggancio e azzeramento badge.

File: `anchored_message_list.dart` (`_JumpToBottomButton`, `_onJumpTap`, `didUpdateWidget`)
