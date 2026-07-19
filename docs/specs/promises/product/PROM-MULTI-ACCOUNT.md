# PROM-MULTI-ACCOUNT — Sessioni parallele e focus account

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-MULTI-ACCOUNT` |
| **Classe** | PRODUCT |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-19 |
| **PR origine** | #140 (UX/shell), #147 (persistenza), #152 (single-active GoTrue) |

Promessa di prodotto: una o più identità messaggistica sulla stessa shell, focus istantaneo, una sessione GoTrue attiva in RAM, overlay auth non invasivo.

---

## 1. Problema / obiettivo

L'utente opera Alfred con più account senza re-login al cambio focus. Le credenziali sono overlay temporaneo sulla shell sempre visibile; inbox, chat e stato UI per account persistono al cambio focus.

---

## 2. Promesse

### MUST — shell e manifest

| ID | Promessa |
|----|----------|
| **PROM-MULTI-ACCOUNT-001** | Shell `HomeScreen` **sempre** visibile (sidebar + inbox + chat) — mai sostituita da auth full-screen |
| **PROM-MULTI-ACCOUNT-002** | Account in lista sidebar = account **aperti** nel manifest — non bookmark disconnessi |
| **PROM-MULTI-ACCOUNT-003** | Storage manifest: `alfred_saved_accounts` (JSON `OpenAccount[]`) — verità dopo F5 |
| **PROM-MULTI-ACCOUNT-004** | Focus: `alfred_focus_user_id` — quale account mostra inbox/chat |
| **PROM-MULTI-ACCOUNT-005** | Auth per account: `alfred_auth_{userId}` — sessione GoTrue dedicata; non ricostruisce il manifest |

### MUST — sessione e servizi

| ID | Promessa |
|----|----------|
| **PROM-MULTI-ACCOUNT-006** | **Una** `AccountSession` / connessione GoTrue attiva in RAM; al `setFocus`: dispose sessione corrente (`clearAuthStorage: false`), restore nuovo account da manifest |
| **PROM-MULTI-ACCOUNT-007** | Bootstrap app: `bootstrapApp()` — nessun `Supabase.initialize` globale per utente |
| **PROM-MULTI-ACCOUNT-008** | Servizi dati usano `session.client` della sessione in focus, non singleton globale |
| **PROM-MULTI-ACCOUNT-009** | `InboxController` + realtime inbox solo sul focus — vedi [PROM-REALTIME-OWNER](./PROM-REALTIME-OWNER.md) |
| **PROM-MULTI-ACCOUNT-010** | `AccountViewState` per `userId`: `activePeer` e stato mobile inbox/chat **persistono** al cambio focus |
| **PROM-MULTI-ACCOUNT-011** | Token refresh: sessione attiva aggiorna propria entry manifest su `tokenRefreshed` |

### MUST — overlay auth

| ID | Promessa |
|----|----------|
| **PROM-MULTI-ACCOUNT-012** | 0 account → `AuthOverlay` obbligatorio, non dismissibile |
| **PROM-MULTI-ACCOUNT-013** | ≥1 account → overlay solo da «Aggiungi account», dismissibile |
| **PROM-MULTI-ACCOUNT-014** | Login e registrazione sulla stessa card (`AuthScreen`); toggle Accedi/Registrati |
| **PROM-MULTI-ACCOUNT-015** | «Chiudi account» (`removeAccount`): rimuove manifest + `alfred_auth_{userId}`; se ultimo account → overlay obbligatorio |

### SHOULD

| ID | Promessa |
|----|----------|
| **PROM-MULTI-ACCOUNT-020** | Switch focus senza loading auth visibile (restore in background) |
| **PROM-MULTI-ACCOUNT-021** | `NoAccountPlaceholder` in area inbox quando nessun account/focus |
| **PROM-MULTI-ACCOUNT-022** | Dopo round-trip focus (A→B→A), invio messaggio sulla chat già aperta usa la sessione **viva** — nessun «Sessione scaduta» spurio |

### MUST NOT

| ID | Promessa |
|----|----------|
| **PROM-MULTI-ACCOUNT-030** | `AuthScreen` a tutto schermo che sostituisce `HomeScreen` (eccetto card in overlay) |
| **PROM-MULTI-ACCOUNT-031** | N client GoTrue paralleli in RAM su web (BroadcastChannel collision) |
| **PROM-MULTI-ACCOUNT-032** | `switchAccount` legacy con `setSession` tra account già in RAM |
| **PROM-MULTI-ACCOUNT-033** | Overlay dismissibile con 0 account |
| **PROM-MULTI-ACCOUNT-034** | Rotella globale che nasconde shell durante switch |

### Fuori scope

- Realtime inbox per account non in focus (trade-off PR #152).
- Badge/anteprima messaggi su account in background.
- Encryption refresh token (post-federazione).

---


## 3. Modello (riferimento)

| Elemento | Artefatto |
|----------|-----------|
| Glossario / comandi | [docs/domain/multi-account/](../../../domain/multi-account/), [docs/domain/auth/](../../../domain/auth/) |
| UML | [docs/model/uml/multi-account/](../../model/uml/multi-account/), [docs/model/uml/auth/](../../model/uml/auth/) |
| Statechart client | [client/lib/machines/multi-account/](../../../client/lib/machines/multi-account/), [client/lib/machines/auth/](../../../client/lib/machines/auth/) |
| Focus account | `FocusAccount` · [seq-focus-switch.puml](../../model/uml/multi-account/seq-focus-switch.puml) |

**Implementazione (non vincolante):** [docs/domain/multi-account/README.md](../../../domain/multi-account/README.md) · [docs/guides/multi-account.md](../../../guides/multi-account.md)


## 4. Superfici conformi

| Superficie | Stato | File |
|------------|-------|------|
| SURF-AUTH | `implemented` | [SURF-AUTH.md](../../surfaces/SURF-AUTH.md) |
| Shell globale | `implemented` | `client/lib/screens/app_shell.dart`, `home_screen.dart`, `account_sidebar.dart` |

---

## 5. Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| PROM-MULTI-ACCOUNT-001 | `client/lib/screens/app_shell.dart`; `guides/multi-account.md` |
| PROM-MULTI-ACCOUNT-002–004 | `account_storage_test.dart` |
| PROM-MULTI-ACCOUNT-005–006 | `account_manager_persistence_test.dart` |
| PROM-MULTI-ACCOUNT-010 | `account_manager_view_state_test.dart` |
| PROM-MULTI-ACCOUNT-012–015, 033 | `auth_controller_test.dart`; `auth_overlay_shell.md` |
| PROM-MULTI-ACCOUNT-009 | `inbox_provider_lifecycle_test.dart` |
| PROM-MULTI-ACCOUNT-010, 020 | `multi_account_chat_scenario_test.dart` |
| PROM-MULTI-ACCOUNT-022 | `composition/messaging_session_scope_test.dart` (COMP-001, COMP-002) |
| PROM-MULTI-ACCOUNT-011 | `auth_service_multi_account_test.dart` |
| PROM-MULTI-ACCOUNT-030, 034 | `guides/multi-account.md` |


Gate: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh` (include `check-composition-sync`) · Integrazione: `bash scripts/test.sh integration` · E2E: `bash scripts/test.sh e2e-multi` · Strategia: [docs/testing/strategy.md](../../../testing/strategy.md)

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [registry.md](../../registry.md) | Indice promesse |
| [SURF-AUTH](../../surfaces/SURF-AUTH.md) | Overlay autenticazione |
| [SURF-ACCOUNT-SIDEBAR](../../surfaces/SURF-ACCOUNT-SIDEBAR.md) | Sidebar multi-account |
| [multi-account-parallel-sessions.md](../../../decisions/multi-account-parallel-sessions.md) | ADR |
| [PROM-REALTIME-OWNER](./PROM-REALTIME-OWNER.md) | Realtime scoped al focus |
| [PROM-SHAREABLE-LINK](./PROM-SHAREABLE-LINK.md) | Link in ingresso con 0 account → auth poi risorsa |
