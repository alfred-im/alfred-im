# PROM-PUSH-NOTIFY — Notifiche push multi-device e multi-account

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-PUSH-NOTIFY` |
| **Classe** | PRODUCT |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-18 |

Promessa di prodotto: notifiche Web Push su tutti i dispositivi attivi per account e per tutti gli account aperti sullo stesso dispositivo; anteprima testo; soppressione in chat attiva.

Infrastruttura server: [SYS-PUSH](../system/SYS-PUSH.md). Superficie client/SW: [SURF-NOTIFICATIONS](../../surfaces/SURF-NOTIFICATIONS.md).

---

## 1. Problema / obiettivo

Con [PROM-MULTI-ACCOUNT](./PROM-MULTI-ACCOUNT.md) e [PROM-REALTIME-OWNER](./PROM-REALTIME-OWNER.md), solo l'account in focus riceve aggiornamenti live. Le push colmano il gap: l'utente viene avvisato di messaggi su account in background e su altri browser/dispositivi.

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
| **PROM-PUSH-NOTIFY-034** | Chiave canonica client/SW: `recipient_user_id|peer_profile_id` ([`PushConversationKey`](../../../client/lib/models/push_conversation_key.dart)); payload incompleto → nessuna UI, nessun `open_chat` |
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

### MUST NOT

| ID | Promessa |
|----|----------|
| **PROM-PUSH-NOTIFY-040** | Notifica per messaggio non recapitato (allow list rifiutata) |
| **PROM-PUSH-NOTIFY-041** | Notifica duplicata visibile in chat già aperta e visibile (soppressione) |
| **PROM-PUSH-NOTIFY-042** | Subscription di un account associata al `user_id` di un altro |
| **PROM-PUSH-NOTIFY-043** | Handler push che apre chat o sopprime notifica usando solo `peer_profile_id` senza `recipient_user_id` |
| **PROM-PUSH-NOTIFY-044** | Tap notifica che lascia visibile chat con peer diverso da `peer_profile_id` del payload (stale UI) |

### Fuori scope (v1)

| ID | Nota |
|----|------|
| **PROM-PUSH-NOTIFY-050** | Push native Android/iOS (FCM/APNs) — solo Web Push VAPID |
| **PROM-PUSH-NOTIFY-051** | Notifiche per sola propagazione spunte (`read_receipt`) senza nuovo messaggio |
| **PROM-PUSH-NOTIFY-052** | iOS Safari tab (non PWA installata): limite piattaforma documentato in SURF-NOTIFICATIONS |

---

## 3. Contratto implementativo

| Elemento | Responsabilità |
|----------|----------------|
| `PushSubscriptionService` | `device_id`, register/unregister, sync manifest |
| `PushConversationKey` | Chiave univoca `owner|peer` — parse, tag, soppressione |
| `PushSuppressionState` | Espone focus + peer attivo al SW |
| `client/web/push_sw.js` o estensione SW | Handler `push`, `notificationclick` |
| JS interop | `registerPushSubscription`, permesso browser |

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
| PROM-PUSH-NOTIFY-002–003 | `client/e2e/push-registration.spec.ts`; `client/e2e/push-full.spec.ts` |
| PROM-PUSH-NOTIFY-030 | `client/test/widget/push_notification_listener_test.dart`; `client/test/unit/push_tap_stale_chat_verification_test.dart`; `client/e2e/push-full.spec.ts` |
| PROM-PUSH-NOTIFY-022 | Scenario manuale §6 |

**Gate**: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh` + smoke SQL + `bash scripts/test.sh e2e-push-local`

---

## 6. Scenario manuale (accettazione)

1. Browser A: login `alfredagent1` + `alfredagent2` (multi-account); concedi permesso notifiche.
2. Browser B: solo `alfredagent2`.
3. Da B invia messaggio ad agent1 → A mostra push (account agent1 in background).
4. Su A: focus agent1, apri chat con agent2 → invio da B → **nessuna** push visibile.
5. Su A: focus agent1, torna inbox (chat chiusa) → invio da B → push visibile con anteprima testo.
6. Messaggio a gruppo in allow list → push con titolo gruppo e anteprima come 1:1.

---

## 7. Modello (riferimento)

| Elemento | Artefatto |
|----------|-----------|
| Glossario / comandi | [docs/domain/notifications/](../../domain/notifications/) |
| UML | [docs/model/uml/notifications/](../../model/uml/notifications/) |
| Statechart client | [client/lib/machines/notifications/](../../../client/lib/machines/notifications/) |
| Tap → chat | `OpenFromPushTap` → `seq-notification-click.puml` → contesto `navigation` |

---

## 8. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [PROM-MULTI-ACCOUNT](./PROM-MULTI-ACCOUNT.md) | Manifest, focus |
| [PROM-REALTIME-OWNER](./PROM-REALTIME-OWNER.md) | Realtime solo focus |
| [SYS-PUSH](../system/SYS-PUSH.md) | Infrastruttura server |
| [registry.md](../../registry.md) | Indice promesse |
