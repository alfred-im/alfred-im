# Fix stabilità inbox Flutter (PR #113 + #114)

**Data**: 2026-06-24  
**Client**: Flutter web (`client/`) + Supabase  
**Documento per AI** — non per utenti.

---

## Sintomo 1 — Inbox bloccata su rotella (PR #113)

> **Nota storica**: i file citati in questa sezione (`ConversationsController`, `conversations_controller.dart`) sono stati **sostituiti** da `InboxController` / `inbox_controller.dart` nel refactor multi-account (PR #140). La causa e il pattern `sessionReady` restano validi.

**Comportamento**: All'apertura dell'app la lista conversazioni restava in caricamento infinito finché l'utente non navigava su un'altra schermata (es. contatti) e tornava.

**Causa radice**: Race tra `Supabase.initialize` e la prima RPC. Su web, `recoverSession` parte in background; le RPC partivano prima che la sessione fosse idratata.

**Fix**:
- `waitForSupabaseSessionReady()` in `supabase_bootstrap.dart` dopo `Supabase.initialize`
- `AuthController.sessionReady` — i `ProxyProvider` creano `InboxController` solo se `sessionReady && userId`
- `InboxController`: realtime dopo primo `load()`; timeout 30s; UI errore + Riprova

**File (storico PR #113)**: `client/lib/services/supabase_bootstrap.dart`, `client/lib/providers/auth_controller.dart`, `client/lib/providers/conversations_controller.dart` (→ `inbox_controller.dart`), `client/lib/main.dart`

---

## Sintomo 2 — Inbox aggiornata solo dopo interazione (PR #114)

**Comportamento**: Dopo il fix #113, i dati arrivavano dal server ma la UI restava sulla rotella finché l'utente non interagiva (es. digitava nella ricerca).

**Causa radice**: `ProxyProvider` non si sottoscrive a `notifyListeners()` del `ChangeNotifier` figlio. `ConversationsController.load()` completava ma la UI non rebuildava.

**Fix**: Sostituire `ProxyProvider` con **`ChangeNotifierProxyProvider`** per:
- `ConversationsController`
- `ContactsController`
- `ProfileController`

**File**: `client/lib/main.dart`  
**Test**: `client/test/widget/conversations_provider_listen_test.dart`, `client/e2e/inbox-load.spec.ts`

---

## Lezione architetturale

| Pattern | Quando usare |
|---------|--------------|
| `ProxyProvider` | Valori derivati statici, senza `notifyListeners` |
| `ChangeNotifierProxyProvider` | Controller figlio che estende `ChangeNotifier` e deve aggiornare la UI |

---

**Riferimenti**: PR #113, #114; `docs/architecture/full-stack.md` §2.2–2.3; `docs/architecture/pr-registry.md`

---

## Evoluzione post PR #140 (multi-account)

**Data**: 2026-06-29 (PR #140) · **aggiornato** 2026-07-02 (PR #152)

Il bootstrap **non** usa più `Supabase.initialize` + sessione globale unica.

| Aspetto | Prima (#113) | PR #140 | PR #152 (attuale) |
|---------|--------------|---------|-------------------|
| Sessione | Singleton `Supabase.instance` | N client in RAM | **Una** GoTrue in RAM (focus) |
| Gate UI | `AuthScreen` se `!isAuthenticated` | `HomeScreen` + `AuthOverlay` | Invariato |
| `sessionReady` | Attende auth globale | Restore sessioni | Restore **solo focus** |
| Inbox al switch | Ricrea controller + race | Riusa controller per account | `ListenableBuilder` + restore + `load()` |

**Lezione #114**: `ChangeNotifierProxyProvider` per contatti/profilo; inbox legata in `HomeScreen` con `ListenableBuilder`.

**Fix race #113**: ogni `AccountSession.restore` idrata auth prima di `InboxController.load()`.

**PR #152**: N client GoTrue paralleli su web corrompevano JWT via `BroadcastChannel` — vedi `multi-account-single-active-gotrue-pr152.md`.

**File attuali**: `account_manager.dart`, `account_session.dart`, `home_screen.dart`, `auth_controller.dart`

**Riferimenti**: PR #140, #152; `docs/implementation/multi-account-client.md`; `docs/decisions/multi-account-parallel-sessions.md`
