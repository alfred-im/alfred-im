# Alfred Alpha — Architettura completa (client + piattaforma)

**Data**: 2026-06-27  
**Scope**: App completa **senza bridge** (XMPP/Matrix restano stub Fly.io)  
**Stato**: PR #109–#125 su `main`; #126 (voice + deploy-alpha) aperta  
**Registro PR**: [alpha-pr-registry.md](./alpha-pr-registry.md)

---

## 1. Panoramica sistema

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter Web (`client/`)                                   │
│  Auth · Contatti · Conversazioni · Chat (testo/GIF/voice) · Profilo · Multi-account │
└───────────────────────────┬─────────────────────────────────┘
                            │ HTTPS (REST + Realtime + Auth)
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Supabase — Piattaforma Alfred                               │
│  Postgres · RLS · RPC · Realtime · GoTrue                    │
└───────────────────────────┬─────────────────────────────────┘
                            │ (futuro: service_role)
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Bridge XMPP / Matrix — **FUORI SCOPE** (stub health only)   │
│  Leggeranno `outbox`, `sync_cursors`, `bridge_jobs`          │
└─────────────────────────────────────────────────────────────┘
```

### Decisioni vincolanti rispettate

| ADR | Scelta |
|-----|--------|
| D-008 | Flutter parla **solo** con Supabase |
| D-051 | Stato bridge in piattaforma (`outbox`, `sync_cursors`, `bridge_jobs`) |
| D-034 | Protocollo **mai** visibile in UI contatti/inbox |
| D-024 | Multi-account Alfred (Thunderbird) via `shared_preferences` |
| D-031 | Web **online-only** (no cache offline) |

---

## 2. Layer client Flutter

### 2.1 Struttura directory

```
client/lib/
├── config/           # URL Supabase, publishable key (--dart-define override)
├── models/           # DTO UI ↔ JSON Supabase
├── services/         # Accesso API (thin layer, no business logic duplicata)
├── providers/        # ChangeNotifier + Provider (stato UI)
├── screens/          # Shell, auth, home, contatti, profilo
├── widgets/          # Componenti presentazionali (AnchoredMessageList, ChatPanel, …)
└── utils/            # Formattazione date, colori avatar, ConversationScrollAnchor
```

### 2.2 Perché Provider (e non Riverpod/BLoC)

- Scope Alpha: pochi controller globali (`Auth`, `Inbox`, `Contacts`, `Profile`)
- `ProxyProvider` ricrea controller al cambio `userId` (switch account) senza boilerplate
- **`ChangeNotifierProxyProvider`** (non `ProxyProvider`) per inbox/contatti/profilo — altrimenti `notifyListeners()` del controller non aggiorna la UI (fix PR #114; vedi `docs/fixes/flutter-inbox-stability.md`)

### 2.3 Flusso bootstrap

1. `main()` → `Supabase.initialize(publishableKey)` → `waitForSupabaseSessionReady()` (attende idratazione auth; fix race PR #113)
2. `MultiProvider` registra controller; `AuthController.initialize()` imposta `sessionReady`
3. `ChangeNotifierProxyProvider` crea `InboxController` solo se `sessionReady && userId`
4. `AppShell` → `AuthScreen` se non autenticato, altrimenti `HomeScreen`

### 2.4 Multi-account

| Componente | Ruolo |
|------------|-------|
| `AuthIdentity` | Validazione username (identità IM) ed email (auth/recupero) |
| `AccountStorageService` | Persiste lista `{userId, username, refreshToken, displayName}` in `SharedPreferences` |
| `AuthService.switchAccount()` | Salva sessione corrente → `setSession(refreshToken)` → aggiorna storage |
| `AuthService.persistCurrentSession()` | Su `tokenRefreshed` e prima di switch/login add-account |
| `AuthScreen` (`addingAccount: true`) | Login secondo account senza `signOut` sul primo |
| Menu account in `HomeScreen` | Switch, **Aggiungi account**, Esci (solo account attivo) |

**Scelta identità**: login e recupero via **email reale** (GoTrue). L’**username** è l’identità pubblica nell’app (profilo, ricerca, multi-account `@username`) — non compare l’email agli altri utenti.

**Scelta**: refresh token in locale (web) — accettabile per Alpha; encryption pianificata post-Alpha.

**Fix switch**: non usare **Esci** per aggiungere un secondo account (revoca sessione server); usare **Aggiungi account**.

### 2.5 Caricamento inbox (lista chat)

**Regola vincolante**: [address-based-messaging.md](../decisions/address-based-messaging.md) — inbox = **query su `messages`** raggruppata per `peer_profile_id`; **nessuna tabella metadati inbox**.

1. `InboxController.load()` → RPC `list_inbox()` (**un round-trip**, derivato da messaggi)
2. Payload UI: `peer_profile_id`, `display_name`, `last_message_preview`, `last_message_at`, `unread_count`, `protocol`
3. Realtime (`inbox-messages-{userId}`) su `messages` (sender o recipient = io) → `load()`

**Nuova chat**: FAB o rubrica → indirizzo → `ChatPeer` → stessa chat per `profile_id` (vuota finché non ci sono messaggi).

**Scelta**: niente `inbox_threads`, `thread_id`, bozza, né trigger che creano record inbox.

### 2.6 Realtime

| Canale | Tabelle | Scopo |
|--------|---------|-------|
| `inbox-messages-{userId}` | `messages` | Aggiorna lista inbox |
| `messages-peer-{me}-{peer}` | `messages` INSERT/UPDATE | Chat live (coppia sender/recipient) |

### 2.7 Invio messaggi

1. RPC `send_message_to_profile(recipient_profile_id, …)` — unico punto invio
2. UI optimistic con `client_message_id` (UUID v4)
3. Trigger `on_message_inserted`: solo `delivered` (interno) o `outbox` (federato)
4. **Retry client**: `OutboundMessageQueue` (testo, GIF, voice)

### 2.8 GIF in chat

1. Utente seleziona file `.gif` (`ChatInputBar` + `file_picker`)
2. `MessageMediaService.uploadGif` → bucket Supabase `chat-media` (`{userId}/{uuid}.gif`)
3. RPC `send_message_to_profile` con `content_type=gif` e `media_url` pubblico
4. `MessageBubble` renderizza `Image.network` (placeholder durante upload ottimistico)
5. Preview inbox: `[GIF]` (trigger `on_message_inserted`)

**Scelte**:
- Storage pubblico per URL semplici in Realtime (Alpha); signed URL post-Alpha se serve
- Solo `image/gif`, max 10 MB — bucket RLS: upload solo in cartella `auth.uid()`
- `body` può essere vuoto per GIF; `mark_thread_read` include `content_type=gif`

### 2.9 Spunte lettura

**Concept vincolante**: [server-as-reception.md](../decisions/server-as-reception.md) — in un client cloud multidispositivo con fonte di verità sul server, la **ricezione coincide con la ricezione sul server**. Oggi il recapito in piattaforma può sembrare sincrono; con bridge la tempistica si disaccoppia — stessa semantica per **tutte** le chat ([no-internal-external-chat-distinction.md](../decisions/no-internal-external-chat-distinction.md)).

| Livello | UI | Meccanismo Alpha |
|---------|-----|------------------|
| Inviato | ✓ grigia | `send_message_to_profile` → `delivery_status = 'sent'` |
| Consegnato | ✓✓ grigie | `on_message_inserted` → `delivered` quando in fonte di verità |
| Lettura | ✓✓ blu | `mark_peer_read` → `read` |

- `mark_peer_read(peer_profile_id)` all'apertura chat
- UI: `MessageStatus` → ✓ / ✓✓ / ✓✓ blu (`message_bubble.dart`)
- Migrazione `20260626100000_internal_delivered_on_server.sql`: promozione a `delivered` — **debito tecnico** (nome/branch «internal»; da unificare)

**Nota**: recapito via bridge (XEP-0184/0333) mappa su `delivered`/`read`; schema supporta `marker_type`/`marker_for`. La semantica ✓✓ grigia **non** è «arrivato sul device del destinatario» (legacy XMPP diretto) ma «arrivato nella fonte di verità».

### 2.10 Aggancio al fondo conversazione

**Specifica**: [conversation-bottom-anchor.md](../design/conversation-bottom-anchor.md) — vincolante, identica per **tutte** le chat ([no-internal-external-chat-distinction.md](../decisions/no-internal-external-chat-distinction.md)).

| Stato | Comportamento |
|-------|---------------|
| Agganciato (≤48 px dal fondo) | Nuovi messaggi → auto-scroll al fondo |
| Staccato | Messaggi altrui non spostano la vista; badge + pulsante freccia |
| Invio proprio | Riaggancio forzato |
| Riaggancio | Tap pulsante o scroll manuale al fondo |

| Componente | Ruolo |
|------------|-------|
| `AnchoredMessageList` | `ListView.builder(reverse: true)` + UI riaggancio |
| `ConversationScrollAnchor` | Soglia e regole `shouldAutoScrollOnAppend` |
| `ChatPanel` | Integra lista ancorata + `ChatInputBar` |

**Scelta tecnica**: lista `reverse: true` (pattern chat Flutter); messaggi cronologici nel modello, indice invertito in build. Cambio conversazione: `ValueKey(conversation.id)` su `_ChatWithMessages` resetta lo scroll.

**PR**: #125

### 2.11 Note vocali (WebM/Opus)

**Dettaglio**: [voice-notes.md](../implementation/voice-notes.md)

1. Campo messaggio vuoto → pulsante microfono (`ChatInputBar`)
2. Registrazione hold-to-send; swipe ↑ blocca, ↓ annulla; blocco → anteprima
3. Web: WebM/Opus nativo; IO: transcode FFmpeg → unico formato in upload
4. `MessageMediaService.uploadVoice` → bucket `chat-media` (max 15 MB)
5. RPC `send_message` con `content_type=voice`, `duration_seconds`, `media_mime`, `media_size_bytes`
6. `VoiceMessageContent` in bolla — play/pausa, waveform (`just_audio`)
7. Preview inbox: `🎤 m:ss` (`format_voice_preview`)

**Scelte**:
- Formato canonico unico (`audio/webm`) — bridge futuri ricevono sempre lo stesso blob
- Coda retry client unificata con testo/GIF (`OutboundMessageQueue`)
- Migrazioni enum in due file (commit enum prima del CHECK/RPC)

**PR**: #126 (aperta al 2026-06-27)

---

## 3. Layer piattaforma Supabase

### 3.1 Migrazioni

| File | Contenuto |
|------|-----------|
| `20260624200000_alfred_domain_schema.sql` | Schema dominio, RLS, trigger, RPC base |
| `20260624210000_rpc_grants_hardening.sql` | Grant EXECUTE RPC solo `authenticated` |
| `20260624220000_list_conversations_rpc.sql` | RPC inbox un round-trip |
| `20260627220000_fix_send_message_to_profile_overload.sql` | Fix PostgREST HTTP 300 |
| `20260627230000_messages_only_inbox.sql` | Drop `inbox_threads`; inbox query-only |
| `20260624230000_message_gif_support.sql` | GIF — `content_type`, `media_url`, bucket `chat-media` |
| `20260626100000_internal_delivered_on_server.sql` | Spunte — `delivered` su insert (debito nome «internal») |
| `20260627120000_message_voice_support.sql` | Enum `voice` (step 1) |
| `20260627120100_message_voice_support.sql` | Voice — colonne media, RPC 8 arg, bucket `audio/webm` |

### 3.2 Modello dati

```
auth.users 1──1 profiles
profiles 1──* contacts (owner)
profiles *──* conversations (via conversation_participants)
conversations 1──* messages (content_type, media_url, duration_seconds, media_mime opzionali)
messages 1──* message_read_receipts
messages 1──0..1 outbox (se federato; payload include content_type/media_url/duration per voice)
profiles 1──* sync_cursors
bridge_jobs (coda generica bridge)
storage.chat-media (GIF + voice WebM, path `{userId}/{uuid}.gif|.webm`)
```

### 3.3 Enum

| Tipo | Valori | Uso |
|------|--------|-----|
| `contact_protocol` | internal, xmpp, matrix | Routing interno (invisibile UI) |
| `message_content_type` | text, gif, voice | Tipo contenuto messaggio |
| `message_delivery_status` | pending…failed | Spunte + outbox |
| `queue_status` | queued…failed | Outbox / bridge_jobs |

### 3.4 Contatti unificati

| `protocol` | `linked_profile_id` | `external_address` |
|------------|---------------------|--------------------|
| `internal` | obbligatorio | null |
| `xmpp` | null | JID |
| `matrix` | null | Matrix ID |

**Vincolo CHECK** in tabella — impossibile stato ibrido incoerente.

### 3.5 Inbox (solo messaggi)

- **`messages`**: unica fonte di verità
- **`list_inbox()`**: GROUP BY `peer_profile_id` — preview, unread, ordine
- **Nessuna** tabella `inbox_threads`, `conversations`, `conversation_participants`

### 3.6 RPC (business logic server)

| RPC | Responsabilità |
|-----|----------------|
| `search_profiles` | Trova utenti Alfred |
| `list_inbox` | Inbox da messaggi |
| `find_profile_by_username` | Username → profilo |
| `send_message_to_profile` | Invio testo, GIF, voice |
| `list_peer_messages` | Storico con un account |
| `mark_peer_read` | Lettura messaggi da peer |

### 3.7 Trigger

| Trigger | Evento | Azione |
|---------|--------|--------|
| `messages_after_insert` | INSERT `messages` | `delivered` interno o `outbox` federato |

### 3.8 RLS

| Tabella | Policy client |
|---------|---------------|
| `profiles` | SELECT tutti; UPDATE proprio |
| `contacts` | CRUD `owner_id = auth.uid()` |
| `messages` | SELECT/INSERT se parte del messaggio |
| `outbox`, `sync_cursors`, `bridge_jobs` | DENY authenticated |

### 3.9 Punti integrazione bridge (non implementati)

```
Client → send_message_to_profile → messages
                                 → outbox (status=queued)  ← bridge worker poll/claim
Bridge → aggiorna messages.external_id, delivery_status
       → sync_cursors (MAM/Matrix token)
       → bridge_jobs (handshake, sync batch)
```

**PostgREST**: `send_message_to_profile` deve restare **un solo overload** — due firme compatibili con gli stessi tre argomenti client causano HTTP 300 e invio fallito.

Vedi `docs/decisions/bridge-stateless.md`.

---

## 4. Sicurezza Alpha

- Password solo via GoTrue (mai in Postgres)
- RLS su tutte le tabelle dominio
- Publishable key nel client (standard Supabase SPA)
- Bridge tables inaccessibili ad `anon`/`authenticated`

---

## 5. Testing

| Livello | Path | Cosa verifica |
|---------|------|---------------|
| Unit | `client/test/unit/` | Modelli, utils, account storage, parsing RPC |
| Widget | `client/test/widget/` | MessageBubble, AlfredLogo, provider listen, voice UI |
| E2E | `client/e2e/` | Playwright — inbox load senza interazione (`inbox-load.spec.ts`) |
| SQL smoke | `supabase/tests/schema_smoke.sql` | Tabelle + RPC presenti |
| SQL smoke invio | `supabase/tests/send_message_to_profile_smoke.sql` | Invio a profilo non in rubrica, un solo overload RPC |
| Build | `flutter build web` | Compilazione release GitHub Pages |
| CI | `.github/workflows/deploy-pages.yml` | `client/scripts/verify.sh` (analyze + test, zero issue) + build; job `deploy-alpha` |
| Analyze | `flutter analyze` | Fallisce su qualsiasi issue, incluso livello `info` |

---

## 6. Deploy

| Target | Meccanismo |
|--------|------------|
| Web Alpha (sviluppo) | GitHub Pages `/XmppTest/` — **non è produzione** |
| Supabase | Migrazioni in repo → MCP/dashboard |
| Bridge | **Non toccati** — health Fly.io invariato |

### CI `deploy-alpha`

| Evento | Job | URL aggiornato |
|--------|-----|----------------|
| Pull request su `main` (path `client/**`) | `build` → `deploy-alpha` | https://alfred-im.github.io/XmppTest/ |
| Push su `main` | idem | idem |

**Non deducibile**: ambiente GitHub `github-pages` deve permettere *All branches* per il deploy da PR. Default (solo `main`) → errore `environment protection rules`. Rimosso `deploy-preview` / `deploy-prod` — un solo job `deploy-alpha` per ambiente sviluppo condiviso.

Concurrency: `pages-alpha` (ultimo build vince).

### Override config build

```bash
flutter build web \
  --dart-define=SUPABASE_URL=https://... \
  --dart-define=SUPABASE_ANON_KEY=...
```

### Web: script Passkeys obbligatorio

`supabase_flutter` include `passkeys_web`. Senza `bundle.js` in `client/web/index.html` l'app crasha a schermo bianco su GitHub Pages.

```html
<script src="https://github.com/corbado/flutter-passkeys/releases/download/2.5.0/bundle.js"></script>
```

Vedi README ufficiale `supabase_flutter`. Test E2E: `client/e2e/pages-smoke.spec.ts` (Playwright).

---

## 7. Limitazioni Alpha (senza bridge)

| Funzionalità | Stato |
|--------------|-------|
| Chat tra utenti Alfred stessa istanza | ✅ Testo + GIF + **voice** (PR #126) |
| Aggiunta contatti XMPP/Matrix in rubrica | ✅ |
| Invio verso contatti federati | ⏸ Messaggio in `outbox`, status `pending` |
| Ricezione da XMPP/Matrix | ❌ Richiede bridge |
| Push, E2EE | ❌ Fuori scope |

---

## 8. Prossimi passi (post-bridge)

1. Worker bridge: claim `outbox` con lock, invio slixmpp/matrix-nio
2. Ingestione inbound → insert `messages` + Realtime
3. Spunte XEP-0184/0333 via `marker_type`/`marker_for`
4. Edge Function opzionale per webhook bridge

---

**Riferimenti**: `PROJECT_MAP.md`, `docs/architecture/alpha-pr-registry.md`, `docs/decisions/project-revolution-discovery.md`, `docs/decisions/bridge-stateless.md`
