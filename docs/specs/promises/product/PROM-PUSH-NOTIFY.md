# PROM-PUSH-NOTIFY — Notifiche push multi-device e multi-account

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-PUSH-NOTIFY` |
| **Classe** | PRODUCT |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-28 |
| **Amend** | Politica sync multi-account (post-incidente foto PWA #229) |

Promessa di prodotto: notifiche Web Push su tutti i dispositivi attivi per account e per tutti gli account aperti sullo stesso dispositivo; anteprima testo; soppressione in chat attiva.

Infrastruttura server: [SYS-PUSH](../system/SYS-PUSH.md). Superficie client/SW: [SURF-NOTIFICATIONS](../../surfaces/SURF-NOTIFICATIONS.md).

---

## 1. Problema / obiettivo

Con [PROM-MULTI-ACCOUNT](./PROM-MULTI-ACCOUNT.md) e [PROM-REALTIME-OWNER](./PROM-REALTIME-OWNER.md), solo l'account in focus riceve aggiornamenti live. Le push colmano il gap: l'utente viene avvisato di messaggi su account in background e su altri browser/dispositivi.

**Amend 2026-07-28:** la registrazione push non deve violare l'invariante «una GoTrue attiva in RAM» ([PROM-MULTI-ACCOUNT-006](./PROM-MULTI-ACCOUNT.md)). Sync al resume PWA con restore di tutti gli account (pre-#229) invalidava il JWT in focus durante upload media. Questo amend definisce **trigger, scope e confini** di `RegisterDeviceForPush` senza rifare l'infrastruttura VAPID/SW.

---

## 2. Promesse

### MUST — registrazione device e account

| ID | Promessa |
|----|----------|
| **PROM-PUSH-NOTIFY-001** | `device_id` stabile in `localStorage` (`alfred_device_id`), condiviso tra tutti gli account sullo stesso browser |
| **PROM-PUSH-NOTIFY-002** | Ogni account nel manifest, dopo permesso browser `granted`, registra UPSERT `push_subscriptions` per `(user_id, device_id)` |
| **PROM-PUSH-NOTIFY-003** | Login e «Aggiungi account» → registrazione subscription per il nuovo `user_id` sul `device_id` corrente |
| **PROM-PUSH-NOTIFY-004** | «Chiudi account» → DELETE `push_subscriptions` WHERE `user_id` AND `device_id` corrente |
| **PROM-PUSH-NOTIFY-005** | Messaggio recapitato a account **non in focus** → push su quel device (se subscription attiva) |
| **PROM-PUSH-NOTIFY-006** | Messaggio recapitato a account su **altro device** → push su tutti i device con subscription per quel `user_id` |

### MUST — politica sync (amend 2026-07-28)

Ogni invocazione di `RegisterDeviceForPush` dichiara **scope** e **reason** espliciti — vedi [docs/domain/notifications/commands-and-events.md](../../../domain/notifications/commands-and-events.md) § Policy sync.

| ID | Promessa |
|----|----------|
| **PROM-PUSH-NOTIFY-048** | Al cambio focus completato (`FocusChanged`): registrazione push per l'account **destinazione** se permesso `granted` e riga assente o chiavi device ruotate |
| **PROM-PUSH-NOTIFY-049** | Quando il permesso notifiche passa a `granted` (`NotificationPermissionGranted`): registrazione push per **tutti** gli account aperti nel manifest nella stessa sessione app — senza richiedere riavvio |
| **PROM-PUSH-NOTIFY-053** | Ogni sync dichiara scope esplicito: `AllOpenAccounts` \| `FocusedAccount` \| `NewAccount` \| `Unregister` — nessun default implicito «tutti» su lifecycle generico |

#### Tabella trigger → scope (vincolante)

| Trigger | Scope | PROM-ID |
|---------|-------|---------|
| Bootstrap (`SessionBecameReady`) | `AllOpenAccounts` | 002, 053 |
| Login / «Aggiungi account» | `NewAccount` (minimo); SHOULD anche `AllOpenAccounts` | 003, 053 |
| `removeAccount` | `Unregister` | 004 |
| Cambio focus (`FocusChanged`) | `FocusedAccount` | 048, 053 |
| Permesso `default`/`denied` → `granted` | `AllOpenAccounts` | 049, 053 |
| Resume PWA (`AppResumed`) | `FocusedAccount` | 053 |
| Resume con upload media / picker attivo | **nessun sync** | 047 |

### MUST — contenuto notifica

| ID | Promessa |
|----|----------|
| **PROM-PUSH-NOTIFY-010** | Titolo notifica multi-account: `{username o display_name account destinatario} · da {display_name peer}`; se etichetta account assente, solo display name peer |
| **PROM-PUSH-NOTIFY-011** | Corpo: anteprima testo messaggio troncata come preview inbox ([SURF-CHAT](../../surfaces/SURF-CHAT.md) SURF-CHAT-008) |
| **PROM-PUSH-NOTIFY-012** | Media: etichette `[GIF]`, `🎤`, `📍 Posizione`, `📷 Foto`, `🎬 Video` (+ didascalia se presente) — stesse regole inbox |
| **PROM-PUSH-NOTIFY-013** | Chat gruppo (`peer` con `profile_kind = group`): stesso formato 1:1; corpo può prefissare autore (`PROM-GROUP-AUTHOR-DISPLAY`) prima dell'anteprima |
| **PROM-PUSH-NOTIFY-014** | Nessuna distinzione o esclusione notifiche per account gruppo vs utente |

### MUST — identità conversazione (account + peer)

| ID | Promessa |
|----|----------|
| **PROM-PUSH-NOTIFY-033** | Identità push = coppia **`(recipient_user_id, peer_profile_id)`** — stessa semantica di archivio `(owner_id, peer_profile_id)`; **mai** interpretare target, soppressione, tap o tag come «solo peer» |
| **PROM-PUSH-NOTIFY-034** | Chiave canonica client/SW: `recipient_user_id|peer_profile_id`; payload incompleto → nessuna UI, nessuna apertura chat |
| **PROM-PUSH-NOTIFY-035** | Tag notifica browser = `recipient_user_id|peer_profile_id|logical_message_id` — distinto per account anche con stesso peer o stesso messaggio logico su altro account |

### MUST — soppressione e permesso

| ID | Promessa |
|----|----------|
| **PROM-PUSH-NOTIFY-020** | Permesso browser: con stato `default`, richiesto tramite `pushManager.subscribe` (`userVisibleOnly: true`); se `denied`, app senza push e nessun retry invasivo |
| **PROM-PUSH-NOTIFY-021** | Stato `denied` → app funziona senza push; nessun retry invasivo |
| **PROM-PUSH-NOTIFY-022** | Soppressione: **nessuna** notifica visibile se app in foreground + account destinatario in focus + chat con quel `peer_profile_id` aperta |
| **PROM-PUSH-NOTIFY-023** | Soppressione: account in focus ma chat diversa o inbox → push consentita |
| **PROM-PUSH-NOTIFY-024** | Stato soppressione sincronizzato client Flutter → service worker via `postMessage` (`alfred_push_suppression`); stato in RAM nel SW |

### MUST — interazione

| ID | Promessa |
|----|----------|
| **PROM-PUSH-NOTIFY-030** | Tap notifica → focus account destinatario + apre chat con `peer_profile_id`; **non** mostrare chat precedente con altro peer su quell'account |
| **PROM-PUSH-NOTIFY-031** | Deep link coerente con [PROM-SHAREABLE-LINK](./PROM-SHAREABLE-LINK.md) dove applicabile |
| **PROM-PUSH-NOTIFY-036** | Tap notifica: prima di aprire, azzera `activePeer` stale sull'account destinatario; se il peer non è ancora in inbox → retry caricamento + `profile_fallback` sul `peer_profile_id` del payload (messaggio già recapitato) |

### SHOULD

| ID | Promessa |
|----|----------|
| **PROM-PUSH-NOTIFY-054** | `last_seen_at` aggiornato su sync `FocusedAccount` (focus change, resume) |
| **PROM-PUSH-NOTIFY-055** | Sync `AllOpenAccounts` concorrenti debounced (max uno in volo per sessione app) |

### MUST NOT

| ID | Promessa |
|----|----------|
| **PROM-PUSH-NOTIFY-040** | Notifica per messaggio non recapitato (allow list rifiutata) |
| **PROM-PUSH-NOTIFY-041** | Notifica duplicata visibile in chat già aperta e visibile (soppressione) |
| **PROM-PUSH-NOTIFY-042** | Subscription di un account associata al `user_id` di un altro |
| **PROM-PUSH-NOTIFY-043** | Handler push che apre chat o sopprime notifica usando solo `peer_profile_id` senza `recipient_user_id` |
| **PROM-PUSH-NOTIFY-044** | Tap notifica che lascia visibile chat con peer diverso da `peer_profile_id` del payload (stale UI) |
| **PROM-PUSH-NOTIFY-045** | Resume PWA generico che innesca `RegisterDeviceForPush` con scope `AllOpenAccounts` |
| **PROM-PUSH-NOTIFY-046** | `RegisterDeviceForPush` che invoca switch identità (`SessionAuthority.requestFocusSwitch` / dispose sessione in focus) o restore parallelo di account non in focus tramite `AccountSession.restore` nel percorso caldo |
| **PROM-PUSH-NOTIFY-047** | Sync push durante upload media attivo (picker galleria/fotocamera aperto o coda outbound con allegato in invio) |

### Fuori scope (v1)

| ID | Nota |
|----|------|
| **PROM-PUSH-NOTIFY-050** | Push native Android/iOS (FCM/APNs) — solo Web Push VAPID |
| **PROM-PUSH-NOTIFY-051** | Notifiche per sola propagazione spunte (`read_receipt`) senza nuovo messaggio |
| **PROM-PUSH-NOTIFY-052** | iOS Safari tab (non PWA installata): limite piattaforma documentato in SURF-NOTIFICATIONS |

---

## 3. Modello (riferimento)

| Elemento | Artefatto |
|----------|-----------|
| Glossario / comandi | [docs/domain/notifications/](../../../domain/notifications/) |
| UML | [docs/model/uml/notifications/](../../model/uml/notifications/) |
| Statechart client | [client/lib/machines/notifications/](../../../client/lib/machines/notifications/) |
| Tap → chat | `OpenChatFromNotification` → [seq-notification-click.puml](../../model/uml/notifications/seq-notification-click.puml) → contesto `navigation` |

**Implementazione (non vincolante):** [docs/domain/notifications/README.md](../../../domain/notifications/README.md) · payload: [contracts/push-payload.md](../../contracts/push-payload.md)

---

## 4. Superfici conformi

| Superficie | Stato | File |
|------------|-------|------|
| SURF-NOTIFICATIONS | `implemented` | [SURF-NOTIFICATIONS.md](../../surfaces/SURF-NOTIFICATIONS.md) |
| SURF-APP-SHELL | `implemented` | Bootstrap permesso + registrazione |
| SURF-AUTH | `implemented` | Registrazione post-login |

---

## 5. Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| PROM-PUSH-NOTIFY-001–004 | `client/test/unit/push_subscription_service_test.dart` |
| PROM-PUSH-NOTIFY-010–014 | `client/test/unit/push_preview_test.dart` |
| PROM-PUSH-NOTIFY-033–035 | `client/test/unit/push_conversation_key_test.dart`; `client/test/unit/push_suppression_test.dart` |
| PROM-PUSH-NOTIFY-020–021 | `client/test/unit/notification_permission_test.dart` |
| PROM-PUSH-NOTIFY-022–024 | `client/test/unit/push_suppression_test.dart` |
| PROM-PUSH-NOTIFY-005–006 | `client/e2e/push-full.spec.ts` (stack locale) |
| PROM-PUSH-NOTIFY-002–003 | `client/e2e/push-full.spec.ts` |
| PROM-PUSH-NOTIFY-030 | `client/test/widget/push_notification_listener_test.dart`; `client/test/unit/push_tap_stale_chat_verification_test.dart`; `client/e2e/push-full.spec.ts` |
| PROM-PUSH-NOTIFY-022 | Scenario manuale §6 |
| **PROM-PUSH-NOTIFY-045–047** | `client/e2e/photo-resume-session-repro.spec.ts` (`flusso-reale`); test unit sync scope (da implementare) |
| **PROM-PUSH-NOTIFY-048–049, 053** | `e2e-push-local` multi-account esteso; `push-permission-grant-multi-account` (da implementare) |
| **PROM-PUSH-NOTIFY-047** | `flusso-reale`; gate upload+picker (da implementare) |

**Gate**: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh` + smoke SQL + `bash scripts/test.sh e2e-push-local`

---

## 6. Scenario manuale (accettazione)

1. Browser A: login `alfredagent1` + `alfredagent2` (multi-account); concedi permesso notifiche.
2. Browser B: solo `alfredagent2`.
3. Da B invia messaggio ad agent1 → A mostra push (account agent1 in background).
4. Su A: focus agent1, apri chat con agent2 → invio da B → **nessuna** push visibile.
5. Su A: focus agent1, torna inbox (chat chiusa) → invio da B → push visibile con anteprima testo.
6. Messaggio a gruppo in allow list → push con titolo gruppo e anteprima come 1:1.

**Amend — scenari aggiuntivi (da automatizzare):**

7. Tre account aperti, permesso concesso da impostazioni OS → tutti e tre hanno riga `push_subscriptions` senza riavvio app.
8. Switch A→B → riga B aggiornata (`last_seen_at` o chiavi se ruotate).
9. Galleria → resume → foto inviata: nessun errore sessione/RLS; push su account non in focus ancora funzionante (riga da bootstrap).

---

## 7. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [PROM-MULTI-ACCOUNT](./PROM-MULTI-ACCOUNT.md) | Manifest, focus, una GoTrue in RAM |
| [PROM-CHAT-MEDIA](./PROM-CHAT-MEDIA.md) | Upload media — percorso caldo protetto da sync push |
| [PROM-REALTIME-OWNER](./PROM-REALTIME-OWNER.md) | Realtime solo focus |
| [SYS-PUSH](../system/SYS-PUSH.md) | Infrastruttura server |
| [registry.md](../../registry.md) | Indice promesse |
