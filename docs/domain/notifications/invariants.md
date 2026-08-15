# Invarianti — notifications

**Bounded context:** `notifications`  
**Implementazione:** `client/lib/models/push_conversation_key.dart`, `client/lib/utils/message_preview.dart`  
**Enforcement sync auth:** [multi-account/session-authority.md](../multi-account/session-authority.md) (`AuthorizePushSync`)  
**Confine prodotto:** [PROM-PUSH-NOTIFY](../../specs/promises/product/PROM-PUSH-NOTIFY.md)

---

## Chiave conversazione push

1. Ogni notifica/intent 1:1 identifica **(archive_user, peer)** — formato `recipient|peer` (`PushConversationKey.canonicalKey`).
2. Stesso formato di outbound queue e scope messaggistica — mai «solo peer» senza account.

## Tap push

3. `OpenConversation` con focus sul **destinatario** notifica — vedi [navigation/invariants.md § No stale chat](../navigation/invariants.md#no-stale-chat).

## Preview

4. Testo anteprima push = stessa logica inbox (`message_preview.dart`).

## Sync push multi-account (amend 2026-07-28)

5. `RegisterDeviceForPush` dichiara **scope** esplicito — nessun default «tutti gli account» su lifecycle generico.
6. Resume PWA (`AppResumed`) → scope `FocusedAccount` al massimo — **mai** `AllOpenAccounts`.
7. Registrazione push **non** invoca `RequestFocusSwitch`, dispose sessione in focus, né `AccountSession.restore` parallelo — gate: `SessionAuthority.AuthorizePushSync`.
8. Durante upload media o picker OS attivo → `AcquireIdentityLease` attivo → sync push **deferred** (`PushSyncDeferred`).
9. Cambio focus completato → scope `FocusedAccount` per l'account destinazione.
10. Permesso notifiche appena `granted` → scope `AllOpenAccounts` nella stessa sessione app.
