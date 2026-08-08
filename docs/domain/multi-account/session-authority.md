# SessionAuthority — servizio di dominio (enforcement identità)

**Bounded context:** `multi-account` (servizio interno al contesto)  
**Ultima revisione:** 2026-08-08  
**Stato:** `wired` — `client/lib/services/session_authority.dart` (`part of account_manager.dart`)  
**UML:** [session-authority-state.puml](../../model/uml/multi-account/session-authority-state.puml) (profilo **service** — stati logici, non enum Dart) · [seq-run-as-owner.puml](../../model/uml/multi-account/seq-run-as-owner.puml) · [seq-identity-lease-media.puml](../../model/uml/multi-account/seq-identity-lease-media.puml)

---

## Problema (risolto)

Gli invarianti multi-account (una GoTrue in RAM, niente restore parallelo, lease durante media) erano documentati ma l’enforcement era spalmato su `AccountManager`, navigation effects, guard push. Violazioni → incidente foto PWA #229.

## Ruolo

**SessionAuthority** è l’unico modulo runtime autorizzato a:

1. possedere quale `ownerUserId` ha JWT valido in RAM;
2. serializzare dispose + restore GoTrue;
3. esporre `identityGeneration` (allineata a `AccountSession.epoch`);
4. rilasciare **lease** che bloccano lo switch durante operazioni lunghe;
5. autorizzare sync push per scope senza violare focus/lease.

Tutti gli altri contesti (**navigation**, **messaging**, **notifications**) invocano comandi su SessionAuthority — **non** chiamano switch identità, `dispose` o `restore` su `AccountManager` direttamente.

---

## Relazione con MultiAccountMachine e AccountManager

| Livello | Ruolo |
|---------|--------|
| **MultiAccountMachine** | Intent utente: manifest, focus UI persistito, overlay auth |
| **SessionAuthority** | Identità viva in RAM: JWT, generazione, lease, coda switch |
| **AccountManager** | Manifest, storage, view-state, `AccountSession` in RAM; switch GoTrue **privato** (`_executeFocus`, `_consolidateSessionForAccount`) — solo SessionAuthority |

`FocusAccount` **delega** a `RequestFocusSwitch`.  
Ingresso chat (fase B) **delega** a `EnsureOwnerReady` (oggi); `RunAsOwner` è API prevista per unificare il wrapper (vedi § Gap).

---

## Comandi

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `RequestFocusSwitch` | `MultiAccountMachine` / `NavigationMachine` | Cambio focus: dispose + restore serializzato. |
| `EnsureOwnerReady` | navigation (ingresso chat) | JWT allineato a `ownerUserId` prima di fetch/send. |
| `RunAsOwner` | *(previsto)* | Garantisce JWT + esegue `operation` in un wrapper. |
| `AcquireIdentityLease` | media (picker/upload) via `PushMediaSyncGuard` | Blocca switch verso altro owner. |
| `ReleaseIdentityLease` | media | Fine lease. |
| `AuthorizePushSync` | `PushCoordinator` | Gate scope/reason push. |
| `ReconnectActiveOwner` | `MultiAccountMachine` / UI reconnect | Retry restore focus corrente. |

### `AuthorizePushSync`

Implementa tabella policy in [notifications/commands-and-events.md](../notifications/commands-and-events.md) § Policy sync.

| Condizione | Esito |
|------------|--------|
| Lease attivo | `deferred` — nessun sync auth |
| `AppResumed` + `AllOpenAccounts` | rifiutato (policy) |
| Altrimenti (scope ammesso) | `authorized` — `PushCoordinator` procede |

Per `AllOpenAccounts`: account ≠ focus usano **client auth effimero** — mai `restore` parallelo in RAM.

---

## Eventi (dominio)

| Evento | Descrizione |
|--------|-------------|
| `IdentityActivated` | JWT valido per `ownerUserId`; `identityGeneration` incrementato (`AccountSession.epoch`). |
| `IdentitySwitchDeferred` | Switch bloccato da lease attivo. |
| `IdentityLeaseAcquired` / `IdentityLeaseReleased` | Lease media/upload. |

Eventi statechart multi-account (`AccountFocused`, `SessionRestoreFailed`) restano sulla macchina focus — vedi [commands-and-events.md](commands-and-events.md).

---

## Stati (SessionAuthority)

Diagramma UML = **specifica logica** osservabile (`activeOwnerId`, lease, transitorio switch). L'implementazione Dart è un **servizio imperativo** senza enum stato — non va confuso con `MultiAccountMachine` né con un file in `client/lib/machines/multi-account/`.

| Stato logico | Osservabile in codice |
|--------------|------------------------|
| `NoActiveIdentity` | `activeOwnerId == null` |
| `OwnerActive` | JWT attivo, `hasActiveLease == false` |
| `OwnerActiveLeased` | JWT attivo, `hasActiveLease == true` |
| `SwitchingOwner` | durante `_executeFocus` / `_consolidateSessionForAccount` |

| Stato | Descrizione |
|-------|-------------|
| `NoActiveIdentity` | Nessun JWT in RAM (bootstrap, tra dispose e restore). |
| `OwnerActive` | `activeOwnerId` con JWT; nessun lease. |
| `OwnerActiveLeased` | JWT attivo + lease — switch verso altro owner vietato. |
| `SwitchingOwner` | Transitorio: dispose + restore serializzato. |

Vedi [session-authority-state.puml](../../model/uml/multi-account/session-authority-state.puml).

---

## `identityGeneration`

- Esposta da `SessionAuthority.identityGeneration` (= `focusedSession?.epoch`).
- `ConversationScope.sessionEpoch` + getter `identityGeneration` — stesso valore.
- `NavigationMachine.commitScope` / `reconcileSessionEpoch` usano epoch sessione.

---

## Mapping dominio → codice

| Comando dominio | Dart |
|-----------------|------|
| `RequestFocusSwitch` | `SessionAuthority.requestFocusSwitch` → `AccountManager._executeFocus` |
| `EnsureOwnerReady` | `SessionAuthority.ensureOwnerReady` → `_executeFocus` / `_consolidateSessionForAccount` |
| `RunAsOwner` | `SessionAuthority.runAsOwner` *(definito, non ancora usato in `lib/`)* |
| `AcquireIdentityLease` | `SessionAuthority.acquireLease` / `runWithLease` ← `PushMediaSyncGuard` |
| `AuthorizePushSync` | `SessionAuthority.authorizePushSync` ← `PushCoordinator` |
| `ReconnectActiveOwner` | `SessionAuthority.reconnectActiveOwner` |

File: `client/lib/services/session_authority.dart` · test: `client/test/unit/session_authority_test.dart`

---

## Gap residuo (non blocca merge)

| Item | Stato |
|------|--------|
| `runAsOwner` in tutti i percorsi navigation/messaging | API presente; oggi si usa `ensureOwnerReady` + RPC separate |
| Eventi dominio `IdentityActivated` come eventi macchina | Solo diagnostica/log; non ancora eventi statechart |
| `authorizeAndSyncPush` helper | Definito; `PushCoordinator` chiama `authorizePushSync` direttamente |

---

## Invarianti (enforcement)

Vedi [invariants.md](invariants.md), [navigation/invariants.md](../navigation/invariants.md), [notifications/invariants.md](../notifications/invariants.md).

**Nessun amend SDD** — refactor enforcement, comportamento utente invariato.

---

## Riferimenti

- [PROM-MULTI-ACCOUNT](../../specs/promises/product/PROM-MULTI-ACCOUNT.md)
- [PROM-PUSH-NOTIFY](../../specs/promises/product/PROM-PUSH-NOTIFY.md) — amend lease/resume
- Incidente #229
