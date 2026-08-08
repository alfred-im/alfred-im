# Inbox e liste

**Regole prodotto:** [PROM-LIST-FILTER](../specs/promises/product/PROM-LIST-FILTER.md), [SURF-INBOX](../specs/surfaces/SURF-INBOX.md), [PROM-REALTIME-OWNER](../specs/promises/product/PROM-REALTIME-OWNER.md)

**Ultima revisione:** 2026-08-08

---

## Stabilità auth → inbox

L'inbox carica solo dopo `sessionReady` e restore sessione del focus.  
`HomeScreen` usa `ListenableBuilder` su `focusedSession?.inboxController` con `ValueKey(userId)`.

Provider contatti/profilo: `ChangeNotifierProxyProvider` legati ad `AuthController.focusedSession` — non provider globali scollegati dal focus.

---

## Ricerca on-demand

`CollapsibleListSearch` — lente toggle, dismiss tap-outside.

| Superficie | Filtro |
|------------|--------|
| Inbox | `InboxController.filteredPeers` |
| Rubrica | `filterByQueryFields` su nome/username |
| Persone consentite | idem |

Anteprima inbox (`last_message_preview` da `list_inbox`) allineata alla finestra iniziale chat — vedi [SURF-CHAT-015](../specs/surfaces/SURF-CHAT.md).

---

## Test

`inbox_panel_test.dart`, `contacts_screen_test.dart`, `inbox_provider_lifecycle_test.dart`
