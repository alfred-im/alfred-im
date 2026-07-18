# Changelog Tecnico

Modifiche rilevanti al progetto per tracciare evoluzione tecnica e decisioni implementative. Questo documento è per riferimento interno AI, non per utenti esterni.

---

## [Unreleased] - 2026-07-18

### Aggiunto

- **Metodo modello** — `notifications`, `multi-account`, `navigation` convertiti; macchine cablate
- **#194** — `diagnostic_log.dart`: log console `[alfred][categoria]` con `--dart-define=ALFRED_DIAGNOSTIC_LOG=true`; prima categoria `push` (tap notifica, focus, peer). Documentato in `AGENTS.md` e `client/scripts/test/README.md`. Build Pages senza define = silenzio.
- Fix tap push: listener `navigator.serviceWorker` `message` per `Client.postMessage` dal SW (prima solo `window.message`, percorso sbagliato).

---

## [Unreleased] - 2026-07-14

### Aggiunto

- **#192** — `SYS-PUSH` + `PROM-PUSH-NOTIFY` + `SURF-NOTIFICATIONS`: Web Push VAPID (migrazioni, Edge Function `send-push`, client, SW); e2e completo `e2e-push-local`; subscribe-first
- **#190** — `PROM-CHAT-MEDIA`: foto e video in chat 1:1 e gruppo (picker, fotocamera, didascalia, HEIC→JPEG, bolla ottimistica, coda outbound)
- **#191** — Copertura test media: `messages_controller_media_test.dart`, `group_messages_controller_media_test.dart`, `chat_media_support_test.dart`; fixture/fake test; tracciabilità SDD aggiornata

### Documentazione

- Post-merge **#192**: registry `implemented` per SYS-PUSH, PROM-PUSH-NOTIFY, SURF-NOTIFICATIONS
- Revisione post-#191: `PROM-CHAT-MEDIA`, `SURF-CHAT-013`, `SURF-GROUP-CONVERSATION-006`, `guides/media.md`, `rpc.md`; gate **192** test

---

## [Unreleased] - 2026-07-12

### Aggiunto

- CI `docker-bridges.yml` + `scripts/docker-smoke.sh`: build immagine bridge e verifica `/health` (8080/8081)
- **#184** — Migrazione naming legacy `XmppTest` / `xmpptest` → `alfred-im` (GitHub Pages URL/base-href, Fly.io app, auth redirect, spec SURF-AUTH)
- **#184** — Ingresso OSS su GitHub: `README.md` (consent-first, web/PWA, feminist-informed), `SECURITY.md`, `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1); badge CI + spec-sync
- **#179** — `SYS-ACCOUNT-BOUNDARY` + `SYS-DELIVERY`: schema `alfred_delivery`, RPC account solo confine proprio; worker outbox (`deliver`, `read_receipt`, `group_erogate`); migrazione `20260711190000`
- Test contratto spunte: `delivery_ticks_smoke.sql`, `bash scripts/test.sh integration-ticks`
- **#178** — Link condivisibili stabili (`PROM-SHAREABLE-LINK`): fragment `#indirizzo` / `#indirizzo/chat`; share di sistema da scheda profilo peer e sidebar account; `ShareableLinkController` + test gate

### Corretto

- Fly deploy: `Dockerfile` usa `/bin/sh /start.sh`; shebang in riga 1 in `start-bridges.sh` (regressione header SPDX `b423637` → `exec format error`)
- `scripts/add-spdx-headers.py`: header SPDX dopo shebang nei file `.sh`

### Documentazione

- Allineamento post-#184: migrazione URL/path `alfred-im`; `docs/INDICE.md`, `PROJECT_MAP.md`, `client/README.md`, `docs/architecture/full-stack.md`, `docs/architecture/README.md`, `docs/decisions/README.md`, `docs/guides/README.md`, `docs/specs/README.md`, `docs/specs/promises/system/README.md`, `AGENTS.md`, `.cursor/rules/main.mdc`, `client/scripts/test/README.md`
- Ristrutturazione doc (2026-07-12): catalogo unico `registry.md`; `docs/guides/`; stato in `PROJECT_MAP.md`; cronologia in `CHANGELOG.md`
- Allineamento delivery plane: hub + spec PRODUCT spunte/ricezione
- Feature shareable link: `guides/shareable-link.md`, `full-stack`, `peer-profile`
- Audit doc: link morti; contratti `rpc.md` / `schema.md`; test gate 161

---

## Storico dettagliato (2026-07-03 — 2026-07-07)

### Aggiunto (2026-07-07 — review design-first batch 6, PR #169)

- **Test**: `auth_controller_test.dart` — gate overlay `SURF-AUTH` / `PROM-MULTI-ACCOUNT`, validazione sign-in/sign-up
- **Test**: `account_sidebar_test.dart` — badge «Gruppo» nel manifest (`SURF-ACCOUNT-SIDEBAR`)
- **Helper test**: `AccountManager.syncManifestFromStorageForTest()`
- **Tracciabilità SDD**: `PROM-MULTI-ACCOUNT`, `SYS-GROUP` aggiornate
- **Gate**: **130** test

### Aggiunto (2026-07-07 — PEER-PROFILE, PR #163)

- **Client**: overlay fullscreen al tap avatar peer (`showPeerProfileOverlay`, `PeerProfileOverlay`) — identità pubblica, switch Allow (`reception_allowlist`), pulsante rubrica add/remove (`contacts`); azioni **immediate** senza dialog di conferma
- **Punti attivazione**: tile inbox (solo avatar), header chat, autore messaggio gruppo, lista «Persone consentite», rubrica internal
- **Controller**: `ContactsController.contactForProfileId`, `removeInternalByProfileId`; `ReceptionAllowlistController.removeByProfileId`; `ProfileAvatar.onTap`
- **Spec SDD**: `PEER-PROFILE` → `implemented`
- **Test**: `peer_profile_overlay_test.dart`, `contacts_controller_test.dart`; gate **108** test
- **Doc**: hub, `peer-profile-overlay.md`, registro PR #163, `PROJECT_MAP`, `SESSION_HANDOFF`

### Aggiunto (2026-07-06 — GROUP-CORE + GROUP-DELIVERY, PR #162)

- **Migrazioni** `20260706120000`–`20260706140000`: `profile_kind` (`user`/`group`), `original_author_id`, RPC gruppo (`send_message_to_profile` destinatario gruppo, `broadcast_message_to_allowlist`, `list_owner_messages`, `erogate_group_message`), `peer_profile_kind` in `list_inbox`
- **Semantica**: gruppo = account Alfred; partecipazione solo allow list bidirezionale; erogazione automatica verso allow list del gruppo; broadcast = una riga storico + fan-out proxy; `original_author_id` sempre valorizzato nei flussi gruppo
- **Client**: registrazione tipo account; shell gruppo (`GroupConversationScreen`, no inbox); etichette autore con avatar + nome leggibile (`MessageAuthorHeader`, `author_display.dart`); badge «Gruppo» in manifest; broadcast multimediale (GIF, voice, location)
- **Spec SDD**: `GROUP-CORE`, `GROUP-DELIVERY` → `implemented`
- **Test**: `group_schema_smoke.sql`, `group_delivery_smoke.sql`, `group_broadcast_smoke.sql`; `group_shell_test.dart`, `group_message_display_test.dart`, `message_bubble_test.dart` (header autore); gate **103** test
- **Doc**: hub, contratti, registro PR, `groups-client.md`, revisione completa post-gruppi

### Aggiunto (2026-07-04 — RECEPTION-ALLOWLIST, PR #161)

- **Migrazione** `20260704130000_reception_allowlist.sql`: tabella `reception_allowlist`, helper `is_sender_allowed_for_reception`, gate in `send_message_to_profile`
- **Semantica**: lista vuota = nessun recapito; rifiuto silenzioso (RPC ok, `delivered_at` null → ✓ senza ✓✓); messaggi rifiutati non materializzati in archivio destinatario
- **Client**: schermata «Persone consentite», `ReceptionAllowlistController`, icona in `InboxPanel`
- **Spec SDD**: `RECEPTION-ALLOWLIST` → `implemented`; delta `MAILBOX-SEND` REQ-004
- **Test**: `reception_allowlist_schema_smoke.sql`, `reception_allowlist_gate_smoke.sql`; smoke mailbox con setup allowlist; `reception_allowlist_controller_test.dart`
- **Doc**: hub (`INDICE`, `SESSION_HANDOFF`, `full-stack`, registro PR); semantica spunte a due livelli in spec + ADR

### Documentazione (2026-07-04 — rimozione contenuto obsoleto)

- Eliminati spec superseded `MSG-INBOX`/`MSG-SEND`/`MSG-READ` e doc storici (`messages-only-inbox`, `multi-account-persistence-redesign`, `conversations-empty-diagnosis`)
- Rimosso «Storico pre-mailbox» da contratti operativi (`rpc.md`, `schema.md`) e ADR
- Pulizia riferimenti in `INDICE`, `specs/index.md`, spec `MAILBOX-*`, ADR, registro PR, implementazione/fix README

### Documentazione (2026-07-04 — rimozione riferimenti pre-Flutter)

- Eliminato `docs/decisions/project-revolution-discovery.md` e tutti i link al client React/tag legacy
- Pulizia `CHANGELOG`, `INDICE`, `PROJECT_MAP`, `.cursor-rules.md`

### Aggiunto (2026-07-04 — tracciabilità MAILBOX test)

- **Smoke SQL**: `mailbox_idempotency`, `mailbox_delivery`, `mailbox_read`, `mailbox_inbox`, `mailbox_send_media`; `mailbox_send_smoke` e `send_message_to_profile_smoke` allineati al modello mailbox
- **Client**: `mailbox_message_filter.dart`; test `mailbox_message_filter_test`, `inbox_realtime_owner_filter_test`; estensioni `message_bubble_test`
- **Gate**: `check-spec-sync.sh` esteso (contratti mailbox, smoke SQL tracciati)
- **Doc**: tracciabilità MAILBOX-* senza «da creare»; `multi-account-client.md` test table

### Documentazione (2026-07-04 — revisione sync post-mailbox)

- Allineamento post-#159: `INDICE`, `README`, `SESSION_HANDOFF`, `architecture/README`, `decisions/README`
- Contratti `contracts/rpc.md` e `contracts/schema.md` promossi a modello mailbox
- ADR `address-based-messaging`, `no-internal-external-chat-distinction`, `server-as-reception` aggiornati
- Spec MAILBOX-*: PR #159, tracciabilità smoke; `INBOX-SEARCH` → `MAILBOX-INBOX`
- Registro PR: #154, #155, #160; fix riferimenti sezioni `full-stack` slim

### Aggiunto (2026-07-04 — modello caselle mailbox, PR #159)

- **Migrazione** `20260704120000_mailbox_per_owner_archive.sql`: drop/recreate `messages` con archivio per `owner_id`, `author_id`, `peer_profile_id`, `logical_message_id`, `delivered_at`/`read_at`; rimozione `message_read_receipts` e enum `delivery_status`
- **RPC**: `send_message_to_profile` (outbox sempre + copie mittente/destinatario in transazione), `list_inbox`, `list_peer_messages`, `mark_peer_read` riscritti per mailbox
- **Spec SDD**: `MAILBOX-CORE`, `MAILBOX-SEND`, `MAILBOX-INBOX`, `MAILBOX-READ` → `implemented`; `MSG-INBOX`/`MSG-SEND`/`MSG-READ` → `superseded`
- **Client**: modelli e servizi allineati (`owner_id` realtime, spunte da date); integrazione multi-account estesa (delivered/read pipeline)
- **Test SQL**: `mailbox_schema_smoke.sql`, `mailbox_send_smoke.sql`; aggiornato `schema_smoke.sql`
- **Doc**: `PROJECT_MAP`, `full-stack`, `pr-registry`, `mailbox-inbox-outbox-spec`, `contracts/schema.md` / `rpc.md`

### Documentazione (2026-07-03 — REQ-ID MSG-INBOX + MSG-READ)

- Tabella REQ-ID + tracciabilità in `MSG-INBOX.spec.md`, `MSG-READ.spec.md`
- `check-spec-sync` in `verify.sh`; workflow CI `.github/workflows/spec-sync.yml`

### Documentazione (2026-07-03 — SDD v1 canonico)

- **REQ-ID** nel template + pilota `MSG-SEND.spec.md` (tabella tracciabilità)
- **`contracts/schema.md`**: tabelle, enum, RLS, storage
- **`full-stack.md` slim**: panoramica + link spec (niente duplicazione requisiti)
- **`.github/PULL_REQUEST_TEMPLATE.md`** + `scripts/check-spec-sync.sh`
- `docs/specs/README.md` aggiornato a SDD v1

### Documentazione (2026-07-03 — CONTACTS spec)

- **`CONTACTS.spec.md`**: rubrica personale, `search_profiles`, isolamento da messaggistica
- Header ADR `address-based-messaging.md`; `contracts/rpc.md`; registro PR #109
- **Catalogo SDD message-centric completo** (8 capability + rpc)

### Documentazione (2026-07-03 — PROFILE spec)

- **`PROFILE.spec.md`**: profilo utente, avatar, pronomi, `ProfileSummary`, esposizione inbox
- `PROJECT_MAP`, `contracts/rpc.md` (`find_profile_by_username`); registro PR #118, #134

### Documentazione (2026-07-03 — INBOX-SEARCH spec)

- **`INBOX-SEARCH.spec.md`**: ricerca on-demand inbox, filtro client-side, `_dismissSearch`
- Header `design/inbox-search-toggle.md`; registro PR #132

### Documentazione (2026-07-03 — MSG-READ spec)

- **`MSG-READ.spec.md`**: spunte delivered/read, `mark_peer_read`, semantica cloud
- Header ADR `server-as-reception.md`; colonna Spec registro PR (#122, #130)

### Documentazione (2026-07-03 — Spec-Driven Development)

- **`docs/specs/`**: metodo SDD (`README.md`, `_template.md`, `index.md`)
- **Capability specs** `implemented`: MSG-INBOX (#130), MSG-SEND (#115/#126/#153), AUTH-MULTI (#140/#147/#152)
- **Contratto RPC**: `docs/specs/contracts/rpc.md`
- `INDICE.md`, `AGENTS.md`, `merge-doc-index.md` (colonna Spec); header verso spec su doc implementation/design

### Documentazione (2026-07-03 — revisione sync)

- Allineamento PR **#108–#153** in `PROJECT_MAP`, `README`, `INDICE`, `pr-registry`
- Fix stato obsoleto: `auth-bootstrap-gotrue-revoke`, `conversations-empty-diagnosis`, `SESSION_HANDOFF`
- RPC canonica `send_message_to_profile` in doc voice/spunte; location in ADR messaging
- Gate test: **70** test unit/widget in `verify.sh`

### Flutter — PR #153 (condivisione posizione statica)

- **`content_type=location`**: colonne `latitude`/`longitude` in `messages`; RPC `send_message_to_profile` a 10 parametri
- **Invio**: pin in `ChatInputBar` → overlay full-screen → stream GPS → anteprima mappa OSM (`flutter_map`) → conferma **Invia posizione**
- **Ricezione**: `LocationMessageContent` — tile OSM in bolla, tap apre OpenStreetMap
- **Inbox**: preview `📍 Posizione` (`format_location_preview`)
- **Coda**: `OutboundContentKind.location` con coordinate in retry
- **CI**: retry deploy GitHub Pages (fino a 3 tentativi su errori transitori)
- **Doc**: `docs/implementation/location-sharing.md`; `full-stack.md` §2.13
- **Migrazioni**: `20260702120000`, `20260702120100`

### Flutter — PR #152 (multi-account: una GoTrue attiva)

- **Runtime**: al massimo una `AccountSession` GoTrue in RAM (account in focus); manifest elenca tutti gli account aperti
- **`setFocus`**: dispose sessione corrente (conserva `alfred_auth_{userId}`), restore nuovo account da manifest, `inbox.load()`
- **Fix web**: evita collisioni `BroadcastChannel` auth tra client GoTrue paralleli (inbox JWT sbagliato al switch)
- **Doc**: `docs/fixes/multi-account-single-active-gotrue-pr152.md`; ADR e implementation multi-account aggiornati
- **E2E**: `multi-account-messages.spec.ts` — gate DB + ricezione UI dopo switch

### Flutter — PR #147 (persistenza dichiarativa multi-account)

- **`AccountSession.persistOpenAccount`**: token dalla risposta HTTP / evento auth, non da `currentSession` globale
- **`AccountManager`**: niente `_persistAllOpenAccounts`; `upsertAccount` / `removeAccount` per entry
- **F5**: manifest = unica verità; restore solo account in focus (completato con #152 per runtime)
- **Doc**: `docs/implementation/multi-account-persistence-redesign.md` — implementato

### Flutter — PR #143 (multi-account: logout locale, chat, persistenza)

- **Logout locale**: `AccountSession.close()` senza `signOut` GoTrue — solo `alfred_auth_{userId}`
- **View per account**: `Map<userId, AccountViewState>`; `sanitizedForAccount()`; niente reset globale su `setFocus`
- **Inbox lifecycle**: `ListenableProxyProvider` con dispose noop — `InboxController` owned da `AccountSession`
- **Persistenza**: `_persistAllOpenAccounts()` + `saveAllAccounts` atomico; write lock storage; restore solo errori auth definitivi
- **Test**: 9 casi regressione multi-account (mock); gate attuale **70** test in `verify.sh`
- **Harness**: `integration-multi-account.sh`, `diagnose-test-env.sh`, `reset-chrome-cdp.sh`
- **Doc**: `docs/fixes/multi-account-chat-persistence-pr143.md`
- **Follow-up**: persistenza (#147) e switch web (#152) + e2e multi-account

### Flutter — PR #142 (auth bootstrap + PKCE)

- **Rimosso** `bootstrap.auth.signOut()` dopo login/signup — non revoca più il refresh token condiviso con il client dedicato
- **`EphemeralPkceStorage`**: PKCE su client bootstrap effimero (recupero password senza crash null)
- **Test**: `password_reset_live_test.dart` (tag `live`), `account_session_bootstrap_test.dart`
- **Doc**: `docs/fixes/auth-bootstrap-gotrue-revoke.md`, `docs/SESSION_HANDOFF.md`, `docs/AGENT_DEBUG_ACCOUNTS.md`
- **Logout locale**: `docs/decisions/single-device-logout-open.md` (implementato in #143)

### Flutter — PR #141 (add-account parziale, superseded da #142 su signOut)

- **`_sessionFromAuthResponse`**: adozione sessione dedicata con access+refresh senza `restore()` immediato
- **Residuo pre-#142**: `signOut` bootstrap nel `finally` ancora presente su main fino a merge #142

### Flutter — PR #140 (multi-account sessioni parallele)

- **Modello**: account aperto = sessione Supabase viva + realtime inbox; non bookmark + `setSession`
- **`AccountManager` / `AccountSession`**: un `SupabaseClient` per account; servizi dati per-client
- **`OpenAccount`**: sostituisce `SavedAccount` (stesso payload storage)
- **Shell**: `HomeScreen` sempre visibile; `AuthOverlay` semi-trasparente (0 account = obbligatorio; aggiungi = chiudibile)
- **Focus**: `setFocus` — switch istantaneo, nessuna ri-autenticazione
- **Rimossi**: `AuthService`, gate `AppShell` auth vs home, `switchAccount` con `setSession`
- **ADR**: `docs/decisions/multi-account-parallel-sessions.md`
- **Design**: `docs/design/auth-overlay-shell.md`
- **Implementazione**: `docs/implementation/multi-account-client.md`

### Documentazione (2026-06-28 — sync post-merge #126–#132)

- Allineati `PROJECT_MAP.md`, `README.md`, `docs/INDICE.md`, `full-stack.md` — stato PR e date (tutto mergiato su `main`)

### Flutter — PR #132 (ricerca on-demand inbox)

- **`InboxPanel`**: barra «Cerca messaggi» nascosta di default; icona lente apre con focus; chiusura via `dismissSearch()` (toggle lente + `TapRegion.onTapOutside`); filtro azzerato alla chiusura
- **Layout**: mobile = lente in header accanto a Contatti; desktop = riga «Conversazioni» + lente
- **`HomeScreen`**: `ValueKey(userId)` su `InboxPanel` — reset stato ricerca al cambio account
- **Design**: `docs/design/inbox-search-toggle.md`

### Flutter — PR #131 (sidebar logout)

- **`AccountSidebar`**: rimossa spunta verde fissa sull'account attivo; logout spostato in card profilo (icona a destra del nome)
- Rimossa voce «Esci» in fondo alla sidebar (logout unico punto di uscita nella card)

### Flutter — PR #130 (inbox solo messaggi)

- **Drop `inbox_threads`**: inbox = `list_inbox()` aggregazione on-read su `messages` (non vista materializzata, non cache con FK)
- **RPC peer-based**: `list_peer_messages`, `mark_peer_read` (no `thread_id`)
- **Client**: `ChatPeer` per account; niente bozza/ComposeTarget/InboxThread
- Migrazione `20260627230000_messages_only_inbox.sql`

### Flutter — PR #129 (messaggistica per indirizzo, iterazione precedente)
- **Modello message-centric**: `inbox_threads`, messaggi con `sender_id` + `recipient_profile_id`; drop `conversations`
- **RPC**: `list_inbox`, `list_thread_messages`, `send_message_to_profile`, `find_profile_by_username`, `mark_thread_read`
- **Client**: `InboxController`, bozza compose (FAB → username), invio senza rubrica
- **Fix invio**: rimosso overload duplicato `send_message_to_profile(uuid,text,text)` — PostgREST HTTP 300
- **ADR**: `docs/decisions/address-based-messaging.md`

### CI / deploy demo di sviluppo (2026-06-27)
- **Workflow unificato `deploy-pages`**: ogni PR su `main` (path `client/**`) e ogni push a `main` pubblicano su https://alfred-im.github.io/alfred-im/
- Rimossi job `deploy-preview` / `deploy-prod`; concurrency `pages-dev-demo`
- **Vincolo GitHub**: Environment `github-pages` → *Deployment branches: All branches* (default solo `main` → errore `environment protection rules` su PR)

### Flutter — PR #126 (note vocali in chat)
- **`content_type=voice`**: `duration_seconds`, `media_mime`, `media_size_bytes`, `media_url` — formato canonico **WebM/Opus** (`audio/webm`)
- Migrazioni `20260627120000` + `20260627120100` — applicate su progetto cloud
- Client: `VoiceRecordingService`, transcode IO (FFmpeg), `VoiceMessageContent` (waveform + `just_audio`), gesti hold/swipe in `ChatInputBar`
- **`OutboundMessageQueue`**: retry client unificato per testo, GIF e voice (persistenza + «Riprova invio»)
- Bucket `chat-media`: esteso a `audio/webm`, limite 15 MB
- Preview inbox: `🎤 m:ss`

### Flutter — PR #127 (processo analyze, branch separata)
- **`client/scripts/verify.sh`**: `pub get` → `analyze` → `test` (opzionale `--build`)
- Allineamento `.cursor-rules.md` e CI al gate `flutter analyze` (zero issue, incluso livello `info`)

### Documentazione (2026-06-27)
- **ADR** [no-internal-external-chat-distinction.md](docs/decisions/no-internal-external-chat-distinction.md) — vietata distinzione chat interna/esterna a tutti i livelli (PR #124)
- **Design** [conversation-bottom-anchor.md](docs/design/conversation-bottom-anchor.md) — specifica aggancio al fondo conversazione

### Flutter — PR #125 (aggancio al fondo)
- **`AnchoredMessageList`**: `ListView` `reverse: true`, soglia aggancio 48 px, pulsante riaggancio + badge
- **`ConversationScrollAnchor`**: logica pura in `utils/conversation_scroll_anchor.dart`
- Integrato in `ChatPanel` — comportamento unico per tutte le conversazioni (ADR chat unificate)
- Rimosso sottotitolo header dipendente da `protocol`
- Test: `conversation_scroll_anchor_test.dart`, `anchored_message_list_test.dart`

### Documentazione (2026-06-24 — sync PR su main #108–#114)
- **`docs/architecture/merge-doc-index.md`**: registro PR → feature → documenti da aggiornare
- **`docs/fixes/flutter-inbox-stability.md`**: fix PR #113/#114 (race auth + ChangeNotifierProxyProvider)
- Allineati PROJECT_MAP, CHANGELOG, INDICE, README, `full-stack.md`

### Flutter — PR #115 (GIF in chat)
- **Messaggi GIF**: `messages.content_type` (`text`|`gif`), `messages.media_url`
- Migrazione `20260624230000_message_gif_support.sql` — applicata su progetto cloud
- Storage bucket `chat-media` (solo `image/gif`, 10 MB, RLS per cartella utente)
- Client: `MessageMediaService`, picker GIF in `ChatInputBar`, rendering in `MessageBubble`

### Flutter — PR #114 (fix provider listen)
- **`ChangeNotifierProxyProvider`** al posto di `ProxyProvider` per Conversations/Contacts/Profile
- Test widget `inbox_provider_listen_test.dart` + e2e `inbox-load.spec.ts`

### Flutter — PR #113 (fix inbox auth race)
- **`waitForSupabaseSessionReady()`** dopo `Supabase.initialize` prima delle RPC
- `ConversationsController`: realtime dopo primo load; timeout 30s; UI errore + Riprova
- Gate `sessionReady` su `ChangeNotifierProxyProvider` in `main.dart`

### Flutter — PR #112 (inbox performance)
- **RPC `list_conversations()`**: inbox completa in un round-trip (display name server-side)
- Migrazione `20260624220000_list_conversations_rpc.sql` — applicata su progetto cloud
- Client: `ConversationService` usa RPC; `Conversation.fromListRpcRow`

### Flutter — PR #111 (multi-account)
- Switch account: persist refresh token; `tokenRefreshed`; flusso **Aggiungi account**
- Ripristino sessione se switch fallisce

### Flutter — PR #110 (GitHub Pages)
- Script passkeys `bundle.js` in `client/web/index.html` — fix schermo bianco

### Flutter — PR #109 (app completa + piattaforma)
- Client Flutter collegato a Supabase: auth, contatti, chat realtime, profilo
- Schema dominio `20260624200000_alfred_domain_schema.sql` + RLS + RPC base
- Documentazione: `docs/architecture/full-stack.md`

### Flutter — PR #108 (UI chat base)
- Layout conversazioni + chat, tema Alfred, workflow deploy Pages


---

**Ultimo aggiornamento**: 2026-07-09
