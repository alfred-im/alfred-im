# Inbox e liste

**Contratto**: [PROM-LIST-FILTER](../specs/promises/product/PROM-LIST-FILTER.md), [SURF-INBOX](../specs/surfaces/SURF-INBOX.md)

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

---

## Test

`inbox_panel_test.dart`, `contacts_screen_test.dart`, `inbox_provider_lifecycle_test.dart`
