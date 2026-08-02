# SessionAuthority — servizio di dominio (enforcement identità)

**Bounded context:** `multi-account` (servizio interno al contesto)  
**Ultima revisione:** 2026-08-02  
**Stato:** `documented` — contratto target; runtime attuale: `AccountManager` + guard sparse  
**UML:** [session-authority-state.puml](../../model/uml/multi-account/session-authority-state.puml) · [seq-run-as-owner.puml](../../model/uml/multi-account/seq-run-as-owner.puml) · [seq-identity-lease-media.puml](../../model/uml/multi-account/seq-identity-lease-media.puml)

---

## Problema

Gli invarianti multi-account (una GoTrue in RAM, niente restore parallelo, lease durante media) sono **documentati** in [invariants.md](invariants.md) e nei contesti `navigation` / `notifications`, ma l’**enforcement** è spalmato su `AccountManager`, navigation effects, messaging effects, guard push.

Ogni feature nuova deve «ricordare» le regole. Violazioni → bug in produzione (es. incidente foto PWA #229).

## Soluzione

**SessionAuthority** è l’unico modulo runtime autorizzato a:

1. possedere quale `ownerUserId` ha JWT valido in RAM;
2. serializzare dispose + restore GoTrue;
3. emettere `identityGeneration` (oggi `sessionEpoch` su `ConversationScope`);
4. rilasciare **lease** che bloccano lo switch durante operazioni lunghe;
5. autorizzare sync push per scope (`FocusedAccount`, `AllOpenAccounts`, …) senza toccare focus.

Tutti gli altri contesti (**navigation**, **messaging**, **notifications**) invocano comandi su SessionAuthority — **non** chiamano `executeFocus`, `consolidateSession`, `dispose` o `restore` direttamente.

---

## Relazione con MultiAccountMachine

| Livello | Ruolo |
|---------|--------|
| **MultiAccountMachine** | Intent utente: manifest, focus UI persistito, overlay auth |
| **SessionAuthority** | Identità viva in RAM: JWT, generazione, lease, coda switch |
| **AccountManager** (legacy) | Implementazione attuale — da rifattorare come adapter interno di SessionAuthority |

`FocusAccount` sulla macchina multi-account **delega** a `RequestFocusSwitch` su SessionAuthority.  
`OpenConversation` su navigation **delega** a `RunAsOwner` prima di commit scope e RPC.

---

## Comandi

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `RequestFocusSwitch` | `MultiAccountMachine` / `NavigationMachine` | Cambio focus UI: dispose sessione corrente + restore `ownerUserId` da manifest. Serializzato. |
| `RunAsOwner` | navigation, messaging, notifications, profile, … | Garantisce JWT per `ownerUserId`, esegue operazione, opzionalmente ripristina owner precedente. |
| `AcquireIdentityLease` | messaging (upload), media (picker), policy | Blocca `RequestFocusSwitch` e `RunAsOwner` verso altro owner fino a `ReleaseIdentityLease`. |
| `ReleaseIdentityLease` | messaging, media | Fine lease; elabora switch in coda se presente. |
| `AuthorizePushSync` | `NotificationsMachine` | Valuta scope + reason; esegue registrazione **senza** violare invarianti (client effimero per account non in focus). |
| `ReconnectActiveOwner` | `MultiAccountMachine` | Ritenta restore per owner già in focus (`FocusedAwaitingSession`). |

### `RunAsOwner` — parametri

```
RunAsOwner {
  ownerUserId: string
  operation: () => Future<T>
  restorePreviousOwner: boolean   // default true se caller non è focus switch
}
```

**Policy:**

- Se `activeOwnerId == ownerUserId` e JWT valido → esegui `operation` senza switch.
- Altrimenti → enqueue switch → restore → `IdentityActivated` → `operation`.
- Se lease attivo su **altro** owner e caller richiede switch → `IdentitySwitchDeferred` o errore esplicito (mai restore parallelo).
- Dopo `operation`, se `restorePreviousOwner` → ripristina owner precedente (solo percorsi espliciti; il focus UI resta su `MultiAccountMachine`).

### `AcquireIdentityLease` — parametri

```
AcquireIdentityLease {
  ownerUserId: string
  reason: MediaUpload | MediaPicker | Other(string)
}
```

Ritorna `leaseId`. Contatore per owner — più lease sullo stesso owner sono ammessi; switch verso altro owner è bloccato finché `count > 0` per l’owner attivo.

### `AuthorizePushSync` — parametri

```
AuthorizePushSync {
  scope: AllOpenAccounts | FocusedAccount | NewAccount | Unregister
  reason: SessionReady | AccountOpened | FocusChanged | PermissionGranted | AppResumed | SubscriptionRotated
}
```

Implementa tabella policy in [notifications/commands-and-events.md](../notifications/commands-and-events.md) § Policy sync.

| Scope | SessionAuthority MUST |
|-------|----------------------|
| `FocusedAccount` | Usa sessione attiva o restore solo focus |
| `AllOpenAccounts` | UPSERT per ogni manifest entry con **client auth effimero** per account ≠ activeOwner — **mai** `restore` parallelo in RAM |
| `AppResumed` + lease attivo | `PushSyncDeferred` — nessuna operazione auth |

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `IdentityActivated` | `ownerUserId` ha JWT valido in RAM; `identityGeneration` incrementato. |
| `IdentityDeactivated` | Sessione precedente disposed (`clearAuthStorage: false`). |
| `IdentitySwitchCompleted` | Fine transizione; focus UI può proseguire. |
| `IdentitySwitchFailed` | Restore fallito → `FocusedAwaitingSession` su macchina multi-account. |
| `IdentitySwitchDeferred` | Switch richiesto ma bloccato da lease attivo. |
| `IdentityLeaseAcquired` | `leaseId`, `ownerUserId`, `reason`. |
| `IdentityLeaseReleased` | `leaseId`; eventuale drain coda switch. |
| `PushSyncAuthorized` | Scope approvato — notifications può procedere. |
| `PushSyncDeferred` | Lease o policy bloccano sync (alias dominio notifications). |

---

## Stati (SessionAuthority)

| Stato | Descrizione |
|-------|-------------|
| `NoActiveIdentity` | Nessun JWT in RAM (bootstrap, tra dispose e restore). |
| `OwnerActive` | `activeOwnerId` con JWT; `leaseCount == 0`. |
| `OwnerActiveLeased` | `activeOwnerId` con JWT; `leaseCount > 0` — switch verso altro owner vietato. |
| `SwitchingOwner` | Transitorio: dispose + restore serializzato. |

Vedi [session-authority-state.puml](../../model/uml/multi-account/session-authority-state.puml).

---

## `identityGeneration`

- Unico contatore emesso da SessionAuthority a ogni `IdentityActivated`.
- Sostituisce concettualmente `sessionEpoch` su `ConversationScope` — stesso significato: «sotto quale generazione identità è stato commesso questo scope?»
- `NavigationMachine.commitScope` registra `(owner, peer, identityGeneration)`.
- Messaging verifica `identityGeneration` prima di fetch/send/upload.

---

## Invarianti (enforcement)

SessionAuthority **deve** garantire:

1. Al massimo una `AccountSession` GoTrue in RAM ([invariants.md](invariants.md) §1).
2. Ogni `RunAsOwner` e RPC account-scoped: `auth.uid() == ownerUserId` ([navigation/invariants.md](../navigation/invariants.md) § Account session).
3. Nessun `restore` parallelo — coda switch unica.
4. `AuthorizePushSync(AllOpenAccounts)` non invoca `RequestFocusSwitch` né dispose sessione focus ([notifications/invariants.md](../notifications/invariants.md) §6–7).
5. Lease attivo su upload/picker → `AuthorizePushSync` → `PushSyncDeferred` ([notifications/invariants.md](../notifications/invariants.md) §8).
6. `identityGeneration` monotono per owner tra dispose/restore.

---

## Mapping dominio → implementazione (target)

| Dominio | Codice attuale | Codice target |
|---------|----------------|---------------|
| `RequestFocusSwitch` | `AccountManager.executeFocus` | `SessionAuthority.requestFocusSwitch` |
| `RunAsOwner` | `consolidateSessionForAccount` + RPC sparse | `SessionAuthority.runAsOwner` |
| `AcquireIdentityLease` | `PushMediaSyncGuard` (parziale) | `SessionAuthority.acquireLease` |
| `AuthorizePushSync` | `PushCoordinator` + policy sparse | `SessionAuthority.authorizePushSync` |
| `identityGeneration` | `AccountSession.epoch` / `ConversationScope.sessionEpoch` | `SessionAuthority.generation` |

---

## Migrazione (incrementale)

1. Introdurre `SessionAuthority` come facade su `AccountManager` (stesso comportamento).
2. Spostare consumer: notifications → navigation ingress → messaging send.
3. Deprecare chiamate dirette a `executeFocus` / `consolidateSession` fuori da SessionAuthority — **fatto**: metodi privati su `AccountManager`, `part session_authority.dart`.
4. Alias `sessionEpoch` → `identityGeneration`; rimuovere guard duplicate.
5. Test: unit su stati SessionAuthority + composition esistenti (COMP-*) contro authority.

**Nessun amend SDD** finché il comportamento osservabile resta invariato (refactor enforcement).

---

## Riferimenti

- [invariants.md](invariants.md) — invarianti multi-account
- [commands-and-events.md](commands-and-events.md) — comandi macchina focus
- [PROM-MULTI-ACCOUNT](../../specs/promises/product/PROM-MULTI-ACCOUNT.md) — confine prodotto invariato
- Incidente #229 — motivazione lease + `AuthorizePushSync`
