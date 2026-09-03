# Inbox e liste

**Regole prodotto:** [PROM-LIST-FILTER](../specs/promises/product/PROM-LIST-FILTER.md), [SURF-INBOX](../specs/surfaces/SURF-INBOX.md), [PROM-REALTIME-ARCHIVE](../specs/promises/product/PROM-REALTIME-ARCHIVE.md)

**Ultima revisione:** 2026-09-03

---

## Stabilità auth → inbox

`sessionReady` abilita la shell (`AppShell` → `HomeScreen`) **prima** che l'inbox abbia finito di caricare.

| Fase | Comportamento |
|------|---------------|
| **Boot** | `switchToAccount(deferInboxLoad: true)` → restore sessione focus; `completeBootstrap()` imposta `sessionReady`; poi `refreshFocusedInboxSilently()` in background |
| **Cambio focus** | `switchToAccount` → `refreshFocusedInbox()` (await) |
| **Ingresso chat** | `refreshFocusedInboxSilently()` — non blocca navigazione ([PROM-CONVERSATION-SCOPE-010](../specs/promises/product/PROM-CONVERSATION-SCOPE.md)) |

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
