# Changelog Tecnico

Modifiche rilevanti al progetto per tracciare evoluzione tecnica e decisioni implementative. Questo documento è per riferimento interno AI, non per utenti esterni.

---

## [3.0.0-alpha] - 2026-06-24

### Aggiunto
- **ADR bridge stateless** (D-051): bridge senza stato di business; verità su Supabase — `docs/decisions/bridge-stateless.md`
- **Client Flutter** (`client/`): UI mock chat, tema Alfred, layout responsive
- **Deploy GitHub Pages**: workflow Flutter, URL https://alfred-im.github.io/XmppTest/
- **Scaffold multi-piattaforma**: web, Android, iOS, Linux, macOS, Windows

### Rimosso
- **`web-client/`** React da `main` (recuperabile: tag `legacy/web-client-final` @ `6e792eb`)
- Workflow Pages per build React (sostituito da Flutter)

### Documentazione
- Aggiornati PROJECT_MAP, README, INDICE, discovery doc, client/README

---

## [Unreleased]

### Documentazione (2026-07-03 — Spec-Driven Development)

- **`docs/specs/`**: metodo SDD (`README.md`, `_template.md`, `index.md`)
- **Capability specs** `implemented`: MSG-INBOX (#130), MSG-SEND (#115/#126/#153), AUTH-MULTI (#140/#147/#152)
- **Contratto RPC**: `docs/specs/contracts/rpc.md`
- `INDICE.md`, `AGENTS.md`, `alpha-pr-registry.md` (colonna Spec); header verso spec su doc implementation/design

### Documentazione (2026-07-03 — revisione sync)

- Allineamento PR **#108–#153** in `PROJECT_MAP`, `README`, `INDICE`, `alpha-pr-registry`
- Fix stato obsoleto: `auth-bootstrap-gotrue-revoke`, `conversations-empty-diagnosis`, `SESSION_HANDOFF`
- RPC canonica `send_message_to_profile` in doc voice/spunte; location in ADR messaging
- Rimossi ADR legacy React/XMPP: `no-message-deletion`, `no-modify-source-data`, `TEST_CREDENTIALS.md`
- Gate test: **70** test unit/widget in `verify.sh`

### Alpha Flutter — PR #153 (condivisione posizione statica)

- **`content_type=location`**: colonne `latitude`/`longitude` in `messages`; RPC `send_message_to_profile` a 10 parametri
- **Invio**: pin in `ChatInputBar` → overlay full-screen → stream GPS → anteprima mappa OSM (`flutter_map`) → conferma **Invia posizione**
- **Ricezione**: `LocationMessageContent` — tile OSM in bolla, tap apre OpenStreetMap
- **Inbox**: preview `📍 Posizione` (`format_location_preview`)
- **Coda**: `OutboundContentKind.location` con coordinate in retry
- **CI**: retry deploy GitHub Pages (fino a 3 tentativi su errori transitori)
- **Doc**: `docs/implementation/location-sharing.md`; `alpha-full-stack.md` §2.13
- **Migrazioni**: `20260702120000`, `20260702120100`

### Alpha Flutter — PR #152 (multi-account: una GoTrue attiva)

- **Runtime**: al massimo una `AccountSession` GoTrue in RAM (account in focus); manifest elenca tutti gli account aperti
- **`setFocus`**: dispose sessione corrente (conserva `alfred_auth_{userId}`), restore nuovo account da manifest, `inbox.load()`
- **Fix web**: evita collisioni `BroadcastChannel` auth tra client GoTrue paralleli (inbox JWT sbagliato al switch)
- **Doc**: `docs/fixes/multi-account-single-active-gotrue-pr152.md`; ADR e implementation multi-account aggiornati
- **E2E**: `multi-account-messages.spec.ts` — gate DB + ricezione UI dopo switch

### Alpha Flutter — PR #147 (persistenza dichiarativa multi-account)

- **`AccountSession.persistOpenAccount`**: token dalla risposta HTTP / evento auth, non da `currentSession` globale
- **`AccountManager`**: niente `_persistAllOpenAccounts`; `upsertAccount` / `removeAccount` per entry
- **F5**: manifest = unica verità; restore solo account in focus (completato con #152 per runtime)
- **Doc**: `docs/implementation/multi-account-persistence-redesign.md` — implementato

### Alpha Flutter — PR #143 (multi-account: logout locale, chat, persistenza)

- **Logout locale**: `AccountSession.close()` senza `signOut` GoTrue — solo `alfred_auth_{userId}`
- **View per account**: `Map<userId, AccountViewState>`; `sanitizedForAccount()`; niente reset globale su `setFocus`
- **Inbox lifecycle**: `ListenableProxyProvider` con dispose noop — `InboxController` owned da `AccountSession`
- **Persistenza**: `_persistAllOpenAccounts()` + `saveAllAccounts` atomico; write lock storage; restore solo errori auth definitivi
- **Test**: 9 casi regressione multi-account (mock); gate attuale **70** test in `verify.sh`
- **Harness**: `integration-multi-account.sh`, `diagnose-test-env.sh`, `reset-chrome-cdp.sh`
- **Doc**: `docs/fixes/multi-account-chat-persistence-pr143.md`
- **Follow-up**: persistenza (#147) e switch web (#152) + e2e multi-account

### Alpha Flutter — PR #142 (auth bootstrap + PKCE)

- **Rimosso** `bootstrap.auth.signOut()` dopo login/signup — non revoca più il refresh token condiviso con il client dedicato
- **`EphemeralPkceStorage`**: PKCE su client bootstrap effimero (recupero password senza crash null)
- **Test**: `password_reset_live_test.dart` (tag `live`), `account_session_bootstrap_test.dart`
- **Doc**: `docs/fixes/auth-bootstrap-gotrue-revoke.md`, `docs/SESSION_HANDOFF.md`, `docs/AGENT_DEBUG_ACCOUNTS.md`
- **Logout locale**: `docs/decisions/single-device-logout-open.md` (implementato in #143)

### Alpha Flutter — PR #141 (add-account parziale, superseded da #142 su signOut)

- **`_sessionFromAuthResponse`**: adozione sessione dedicata con access+refresh senza `restore()` immediato
- **Residuo pre-#142**: `signOut` bootstrap nel `finally` ancora presente su main fino a merge #142

### Alpha Flutter — PR #140 (multi-account sessioni parallele)

- **Modello**: account aperto = sessione Supabase viva + realtime inbox; non bookmark + `setSession`
- **`AccountManager` / `AccountSession`**: un `SupabaseClient` per account; servizi dati per-client
- **`OpenAccount`**: sostituisce `SavedAccount` (stesso payload storage)
- **Shell**: `HomeScreen` sempre visibile; `AuthOverlay` semi-trasparente (0 account = obbligatorio; aggiungi = chiudibile)
- **Focus**: `setFocus` — switch istantaneo, nessuna ri-autenticazione
- **Rimossi**: `AuthService`, gate `AppShell` auth vs home, `switchAccount` con `setSession`
- **ADR**: `docs/decisions/multi-account-parallel-sessions.md`
- **Design**: `docs/design/auth-overlay-shell.md`
- **Implementazione**: `docs/implementation/multi-account-client.md`

### Documentazione (2026-06-28 — rimozione legacy React/XMPP)

- Eliminati doc architettura/implementazione/fix relativi al client React rimosso da `main`
- `PROJECT_MAP.md` riscritto — solo stack Flutter + Supabase attivo
- Codice storico recuperabile solo via tag git `legacy/web-client-final` (non documentato nel repo)

### Documentazione (2026-06-28 — sync post-merge #126–#132)

- Allineati `PROJECT_MAP.md`, `README.md`, `docs/INDICE.md`, `alpha-full-stack.md` — stato PR e date (tutto mergiato su `main`)

### Alpha Flutter — PR #132 (ricerca on-demand inbox)

- **`InboxPanel`**: barra «Cerca messaggi» nascosta di default; icona lente apre con focus; chiusura via `dismissSearch()` (toggle lente + `TapRegion.onTapOutside`); filtro azzerato alla chiusura
- **Layout**: mobile = lente in header accanto a Contatti; desktop = riga «Conversazioni» + lente
- **`HomeScreen`**: `ValueKey(userId)` su `InboxPanel` — reset stato ricerca al cambio account
- **Design**: `docs/design/inbox-search-toggle.md`

### Alpha Flutter — PR #131 (sidebar logout)

- **`AccountSidebar`**: rimossa spunta verde fissa sull'account attivo; logout spostato in card profilo (icona a destra del nome)
- Rimossa voce «Esci» in fondo alla sidebar (logout unico punto di uscita nella card)

### Alpha Flutter — PR #130 (inbox solo messaggi)

- **Drop `inbox_threads`**: inbox = `list_inbox()` aggregazione on-read su `messages` (non vista materializzata, non cache con FK)
- **RPC peer-based**: `list_peer_messages`, `mark_peer_read` (no `thread_id`)
- **Client**: `ChatPeer` per account; niente bozza/ComposeTarget/InboxThread
- Migrazione `20260627230000_messages_only_inbox.sql`

### Alpha Flutter — PR #129 (messaggistica per indirizzo, iterazione precedente)
- **Modello message-centric**: `inbox_threads`, messaggi con `sender_id` + `recipient_profile_id`; drop `conversations`
- **RPC**: `list_inbox`, `list_thread_messages`, `send_message_to_profile`, `find_profile_by_username`, `mark_thread_read`
- **Client**: `InboxController`, bozza compose (FAB → username), invio senza rubrica
- **Fix invio**: rimosso overload duplicato `send_message_to_profile(uuid,text,text)` — PostgREST HTTP 300
- **ADR**: `docs/decisions/address-based-messaging.md`

### CI / deploy Alpha (2026-06-27)
- **Workflow unificato `deploy-alpha`**: ogni PR su `main` (path `client/**`) e ogni push a `main` pubblicano su https://alfred-im.github.io/XmppTest/ — ambiente **sviluppo**, non produzione
- Rimossi job `deploy-preview` / `deploy-prod`; concurrency `pages-alpha`
- **Vincolo GitHub**: Environment `github-pages` → *Deployment branches: All branches* (default solo `main` → errore `environment protection rules` su PR)

### Alpha Flutter — PR #126 (note vocali in chat)
- **`content_type=voice`**: `duration_seconds`, `media_mime`, `media_size_bytes`, `media_url` — formato canonico **WebM/Opus** (`audio/webm`)
- Migrazioni `20260627120000` + `20260627120100` — applicate su progetto cloud
- Client: `VoiceRecordingService`, transcode IO (FFmpeg), `VoiceMessageContent` (waveform + `just_audio`), gesti hold/swipe in `ChatInputBar`
- **`OutboundMessageQueue`**: retry client unificato per testo, GIF e voice (persistenza + «Riprova invio»)
- Bucket `chat-media`: esteso a `audio/webm`, limite 15 MB
- Preview inbox: `🎤 m:ss`

### Alpha Flutter — PR #127 (processo analyze, branch separata)
- **`client/scripts/verify.sh`**: `pub get` → `analyze` → `test` (opzionale `--build`)
- Allineamento `.cursor-rules.md` e CI al gate `flutter analyze` (zero issue, incluso livello `info`)

### Documentazione (2026-06-27)
- **ADR** [no-internal-external-chat-distinction.md](docs/decisions/no-internal-external-chat-distinction.md) — vietata distinzione chat interna/esterna a tutti i livelli (PR #124)
- **Design** [conversation-bottom-anchor.md](docs/design/conversation-bottom-anchor.md) — specifica aggancio al fondo conversazione

### Alpha Flutter — PR #125 (aggancio al fondo)
- **`AnchoredMessageList`**: `ListView` `reverse: true`, soglia aggancio 48 px, pulsante riaggancio + badge
- **`ConversationScrollAnchor`**: logica pura in `utils/conversation_scroll_anchor.dart`
- Integrato in `ChatPanel` — comportamento unico per tutte le conversazioni (ADR chat unificate)
- Rimosso sottotitolo header dipendente da `protocol`
- Test: `conversation_scroll_anchor_test.dart`, `anchored_message_list_test.dart`

### Documentazione (2026-06-24 — sync PR Alpha #108–#114)
- **`docs/architecture/alpha-pr-registry.md`**: registro PR → feature → documenti da aggiornare
- **`docs/fixes/flutter-inbox-stability.md`**: fix PR #113/#114 (race auth + ChangeNotifierProxyProvider)
- Allineati PROJECT_MAP, CHANGELOG, INDICE, README, `alpha-full-stack.md`, discovery doc

### Alpha Flutter — PR #115 (GIF in chat)
- **Messaggi GIF**: `messages.content_type` (`text`|`gif`), `messages.media_url`
- Migrazione `20260624230000_message_gif_support.sql` — applicata su progetto cloud
- Storage bucket `chat-media` (solo `image/gif`, 10 MB, RLS per cartella utente)
- Client: `MessageMediaService`, picker GIF in `ChatInputBar`, rendering in `MessageBubble`

### Alpha Flutter — PR #114 (fix provider listen)
- **`ChangeNotifierProxyProvider`** al posto di `ProxyProvider` per Conversations/Contacts/Profile
- Test widget `conversations_provider_listen_test.dart` + e2e `inbox-load.spec.ts`

### Alpha Flutter — PR #113 (fix inbox auth race)
- **`waitForSupabaseSessionReady()`** dopo `Supabase.initialize` prima delle RPC
- `ConversationsController`: realtime dopo primo load; timeout 30s; UI errore + Riprova
- Gate `sessionReady` su `ChangeNotifierProxyProvider` in `main.dart`

### Alpha Flutter — PR #112 (inbox performance)
- **RPC `list_conversations()`**: inbox completa in un round-trip (display name server-side)
- Migrazione `20260624220000_list_conversations_rpc.sql` — applicata su progetto cloud
- Client: `ConversationService` usa RPC; `Conversation.fromListRpcRow`

### Alpha Flutter — PR #111 (multi-account)
- Switch account: persist refresh token; `tokenRefreshed`; flusso **Aggiungi account**
- Ripristino sessione se switch fallisce

### Alpha Flutter — PR #110 (GitHub Pages)
- Script passkeys `bundle.js` in `client/web/index.html` — fix schermo bianco

### Alpha Flutter — PR #109 (app completa + piattaforma)
- Client Flutter collegato a Supabase: auth, contatti, chat realtime, profilo
- Schema dominio `20260624200000_alfred_domain_schema.sql` + RLS + RPC base
- Documentazione: `docs/architecture/alpha-full-stack.md`

### Alpha Flutter — PR #108 (UI chat base)
- Layout conversazioni + chat, tema Alfred, workflow deploy Pages

---

## Storico pre-Flutter (tag `legacy/web-client-final`)

Il client **React + XMPP** (IndexedDB, Stanza.js, MAM) è stato rimosso da `main` con **3.0.0-alpha** (2026-06-24).

- **Codice e documentazione completa**: tag git `legacy/web-client-final` @ `6e792eb`
- **Non documentato su `main`**: ADR/fix/architettura del vecchio stack non vanno replicati qui
- **Changelog dettagliato 0.1.0–2.x**: disponibile nella history git del tag legacy, non mantenuto in questo file

---

**Ultimo aggiornamento**: 2026-07-03
