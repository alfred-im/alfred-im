# Strategia test client Alfred

Piano a livelli allineato a **dominio → UML → statechart → composition root** (`client/lib/screens/`, Provider, chiavi di scope sessione).

**Hub comandi:** `client/scripts/test.sh` · **Gate CI:** `client/scripts/verify.sh`

---

## Piramide

| Tier | Dove | Quando gira | Cosa dimostra |
|------|------|-------------|---------------|
| **1a Machine** | `client/test/unit/*_machine_test.dart` | Ogni PR (gate) | Transizioni stato, coordinator senza I/O |
| **1b Wiring** | `client/test/wiring/*_wiring_test.dart` | Ogni PR (gate) | Controller → effects **live**; mock solo al confine RPC |
| **1c Composition** | `client/test/composition/` | Ogni PR (gate) | `setFocus` round-trip + chiavi scope + binding servizi sessione |
| **1d Unit / widget** | `client/test/unit/`, `widget/` | Ogni PR (gate) | Logica pura, widget isolati, promesse UI puntuali |
| **2 Integration** | `scripts/integration-multi-account.sh` | Manuale / pre-release | RPC Supabase multi-account (no Provider) |
| **★ Flusso reale** | `scripts/test.sh flusso-reale` | **Pre-release obbligatorio** (media/multi-account) | Browser + DB + lifecycle picker — **non** sostituibile da unit |
| **3 E2E** | `client/e2e/` | Manuale / nightly | Browser, DB, tap compose |
| **Diagnostic** | `client/test/diagnostic/` (tag `diagnostic`) | Su richiesta agente | Log `[alfred]` con `ALFRED_DIAGNOSTIC_LOG=true` |

Gate: `check-spec-sync` + `check-model-sync` + `check-composition-sync` + `flutter analyze` + `flutter test` (esclusi tag `live`, `diagnostic`).

**Nota:** `flutter test` senza `--exclude-tags` include i test `diagnostic` (4 test che falliscono by design senza define). Il gate usa `verify.sh` — **377** test al 2026-07-19.

---

## Invarianti composition (catalogo COMP)

Test in `client/test/composition/` — harness in `client/test/support/composition_harness.dart` (`createCompositionAuth`, `roundTripFocus`; widget mirror opzionale per scenari UI futuri). Gate attuale: test unit veloci su auth wired reale.

| ID | Invariante | Contesto | File |
|----|-----------|----------|------|
| **COMP-001** | Dopo round-trip focus A→B→A, controller messaggi usa servizi della sessione **viva** (non istanza dispose) | messaging | `messaging_session_scope_test.dart` |
| **COMP-002** | `hasValidSession` legato a `auth.focusedSession` live; chiave scope include identità sessione (`messagesSessionKey`) | messaging | stesso |
| **COMP-003** | Inbox resta in RAM al focus switch (non dispose nel Provider) | multi-account | `widget/inbox_provider_lifecycle_test.dart` |
| **COMP-004** | Push / deep link con sessione stale → focus + chat corretta | navigation, notifications | `unit/push_tap_stale_chat_verification_test.dart` (estendere a widget) |

Estensioni future: **COMP-005** groups (`groupSessionKey` + `GroupMessagesController` dopo focus).

---

## Regole wiring (tier 1b)

1. **Vietato** `hasValidSession: () => true` in `test/wiring/` salvo riga con commento `// wiring-jwt-bypass-ok` (gate: `check-composition-sync.sh`).
2. Sessioni di test: **un `FakeMessageService` (o equivalente) per `AccountSession`**, non singleton conmotionato tra restore.
3. Almeno un test negativo per contesti con JWT: operazione fallisce se la sessione diventa invalida dopo il load.

---

## Scenari E2E (tier 3 — catalogo)

| Scenario | File | Stato |
|----------|------|-------|
| **★ Foto dopo galleria + resume (4 user + gruppo)** | `e2e/photo-resume-session-repro.spec.ts` | **`flusso-reale`** — implementato |
| Persistenza manifest + F5 | `e2e/multi-account-persist.spec.ts` | Implementato |
| Invio + DB + ricezione UI (live) | `e2e/multi-account-messages.spec.ts` | Implementato (override Pages) |
| Testo, foto, switch e spunte (locale) | `e2e/multi-account-messages.spec.ts` | Implementato (`e2e-multi` default) |
| **Invio dopo round-trip focus con chat aperta** | `e2e/multi-account-send-after-focus-roundtrip.spec.ts` | Da implementare (tier 2) |
| Tap push multi-account | `e2e/push-tap-multi-account.spec.ts` | Locale (`e2e-push-local`) |

Lo scenario «Sessione scaduta» / `StorageException` foto PWA (2026-07) non era coperto perché `e2e-multi-messages` invia da A **prima** dello switch, non simula resume dal picker, e i ~400 test gate non esercitano JWT+RLS+`syncPushSubscriptions` al resume. **`bash scripts/test.sh flusso-reale`** copre quel percorso.

---

## Tracciabilità promessa → test minimo

| Promessa | Test gate minimo |
|----------|------------------|
| PROM-MULTI-ACCOUNT-006 | `account_manager_persistence_test.dart` |
| PROM-MULTI-ACCOUNT-009 | `inbox_provider_lifecycle_test.dart` (COMP-003) |
| PROM-MULTI-ACCOUNT-010, 020 | `multi_account_chat_scenario_test.dart` |
| **PROM-MULTI-ACCOUNT-022** | `composition/messaging_session_scope_test.dart` (COMP-001, COMP-002) |

---

## Perché il bug «Sessione scaduta» (2026-07) è sfuggito

- **Wiring** dimostrava il percorso coordinator, ma bypassava JWT e condivideva un solo service.
- **Scenario unit** costruiva `MessagesController` a mano ad ogni focus (pattern corretto, diverso da `HomeScreen`).
- **Composition** non esisteva come tier obbligatorio.
- **E2E** non eseguiva invio dopo A→B→A con chat già aperta; inoltre non è in gate PR.

---

## Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [client/scripts/test/README.md](../../client/scripts/test/README.md) | Catalogo comandi |
| [PROM-MULTI-ACCOUNT](../specs/promises/product/PROM-MULTI-ACCOUNT.md) | Promesse multi-account |
| [docs/domain/README.md](../domain/README.md) | Modello e gate `check-model-sync` |
