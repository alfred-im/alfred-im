# Registro PR Alpha Flutter (main)

**Ultimo aggiornamento**: 2026-07-06 (GROUP-CORE/DELIVERY #162; RECEPTION-ALLOWLIST #161)  
**Scope**: PR mergiate su `main` dopo migrazione Flutter — riferimento per allineamento documentazione.

Documento per AI. Ogni PR deve riflettersi in: `PROJECT_MAP.md`, `CHANGELOG.md`, `docs/architecture/alpha-full-stack.md` (e fix dedicato se applicabile).

> Alcune PR (#115, #124–#125, #142, #152) sono entrate su `main` via merge branch o commit diretti — il numero PR resta il riferimento canonico in doc/CHANGELOG.

---

## Tabella PR → feature → documentazione

| PR | Titolo / commit | Cosa introduce | Spec | Dove documentato |
|----|-----------------|----------------|------|------------------|
| **#108** | UI chat Flutter | Layout conversazioni + chat, tema Alfred, deploy Pages | — | `CHANGELOG` [3.0.0-alpha], `PROJECT_MAP` |
| **#109** | App completa senza bridge | Auth, contatti, chat realtime Supabase, profilo, schema dominio | CONTACTS, AUTH-MULTI | `alpha-full-stack.md`, `PROJECT_MAP` |
| **#110** | Passkeys bundle.js | Fix schermo bianco GitHub Pages | — | `alpha-full-stack.md` §6 |
| **#111** | Multi-account switch (legacy) | `AccountStorageService`, `setSession` — **sostituito da #140** | — | storico `CHANGELOG` |
| **#112** | `list_conversations` RPC | Inbox un round-trip — **sostituito da `list_inbox` #130** | — | migrazione `20260624220000` |
| **#113** | Fix race auth inbox | `waitForSupabaseSessionReady`, `sessionReady` | — | `fixes/flutter-inbox-stability.md` |
| **#114** | Fix provider listen | `ChangeNotifierProxyProvider` contatti/profilo | — | `fixes/flutter-inbox-stability.md` |
| **#115** | GIF in chat | `content_type`, `media_url`, bucket `chat-media` | MAILBOX-SEND | `voice-notes.md`, migrazioni `20260624230000` |
| **#118** | Login email reale | Auth GoTrue con email; username come identità pubblica | PROFILE | migrazioni auth `202606251*` |
| **#119** | Review refactoring | Ciclo revisione codice client | — | — |
| **#120** | Sidebar profilo | Layout card profilo in sidebar | — | `PROJECT_MAP` § layout |
| **#122** | Spunte `delivered` | Promozione `delivered` su insert server | MAILBOX-READ | `server-as-reception.md`, migrazione `20260626100000` |
| **#123** | Spec caselle (bozza) | Prima stesura `mailbox-inbox-outbox-spec.md` | (target) | `mailbox-inbox-outbox-spec.md` storico |
| **#124** | ADR chat unificate | Nessuna distinzione interna/esterna | MAILBOX-INBOX | `no-internal-external-chat-distinction.md` |
| **#125** | Aggancio al fondo | `AnchoredMessageList`, scroll ancorato | — | `conversation-bottom-anchor.md` |
| **#126** | Note vocali | WebM/Opus, `OutboundMessageQueue` | MAILBOX-SEND | `voice-notes.md` |
| **#127** | Gate `flutter analyze` | `client/scripts/verify.sh` | — | `.cursor-rules.md`, `client/scripts/test/README.md` |
| **#130** | Inbox solo messaggi | Drop `inbox_threads`; `ChatPeer`; RPC peer-based | MAILBOX-INBOX, MAILBOX-READ | `address-based-messaging.md` |
| **#131** | Sidebar logout | Logout in card profilo | AUTH-MULTI | `PROJECT_MAP` § layout |
| **#132** | Ricerca on-demand inbox | Barra ricerca toggle + `TapRegion` | INBOX-SEARCH | `inbox-search-toggle.md` |
| **#133** | Sync doc post-merge | Allineamento doc dopo #126–#132 | — | `CHANGELOG`, `INDICE` |
| **#134** | Profilo arricchito | Avatar, pronomi, `ProfileSummary`, inbox peer fields | PROFILE, MAILBOX-INBOX | `PROJECT_MAP` § profilo, migrazioni `202606280*` |
| **#135** | `AGENTS.md` | Istruzioni Cloud Agent / toolchain | — | `AGENTS.md` |
| **#136** | Spec caselle (aggiorn.) | Target mailbox — direzione confermata | (target) | `mailbox-inbox-outbox-spec.md` |
| **#139** | Redirect email confirm | `AuthRedirectUrl` → GitHub Pages | AUTH-MULTI | `PROJECT_MAP` § redirect auth |
| **#140** | Multi-account UX | `AccountManager`, overlay shell, focus UI | AUTH-MULTI | `multi-account-parallel-sessions.md`, `auth-overlay-shell.md` |
| **#141** | Fix add-account (parziale) | `_sessionFromAuthResponse` — **completato #142** | AUTH-MULTI | `auth-bootstrap-gotrue-revoke.md` |
| **#142** | Auth bootstrap | No `signOut` post-login; `EphemeralPkceStorage` | AUTH-MULTI | `auth-bootstrap-gotrue-revoke.md`, `AGENT_DEBUG_ACCOUNTS.md` |
| **#143** | Multi-account fix | Logout locale; view per account; test mock | AUTH-MULTI | `multi-account-chat-persistence-pr143.md` |
| **#145** | Pulizia doc | Merge documentazione legacy | — | `INDICE` |
| **#146** | Design persistenza | Design persistenza multi-account | AUTH-MULTI | `multi-account-client.md` §3.5 → #147 |
| **#147** | Persistenza dichiarativa | `persistOpenAccount`; manifest = verità F5 | AUTH-MULTI | `multi-account-client.md` §3.5 |
| **#148** | Fix typo doc | «principio cardine» in doc architettura | — | — |
| **#149** | Regole DRY/KISS | Sezione in `.cursor-rules.md` | — | `.cursor-rules.md` |
| **#150** | Regole conferma agente | Conferma scrittura solo dopo domanda esplicita | — | `.cursor-rules.md` |
| **#152** | Una GoTrue attiva | Fix BroadcastChannel web; `setFocus` swap | AUTH-MULTI | `multi-account-single-active-gotrue-pr152.md` |
| **#153** | Posizione statica | `content_type=location`; mappa OSM in bolla | MAILBOX-SEND | `location-sharing.md` |
| **#154** | Revisione sync + SDD Phase 0+1 | Allineamento #108–#153; spec SDD, AUTH-MULTI | MAILBOX-*, AUTH-MULTI | `CHANGELOG` [Unreleased], `docs/specs/` |
| **#155** | MAILBOX-READ spec | Capability spunte delivered/read | MAILBOX-READ | `MAILBOX-READ.spec.md`, `server-as-reception.md` |
| **#158** | Spec MAILBOX-* (SDD) | Spec capability `MAILBOX-CORE/SEND/INBOX/READ` approved | MAILBOX-* | `docs/specs/capabilities/MAILBOX-*.spec.md` — **incorporata in #159** |
| **#159** | Modello caselle mailbox | Drop/recreate `messages` per-owner; outbox sempre; `delivered_at`/`read_at`; client + test | MAILBOX-* | `mailbox-inbox-outbox-spec.md`, `contracts/rpc.md`, `contracts/schema.md`, migrazione `20260704120000` |
| **#160** | Regole consenso esplicito | Conferma verbale prima di scrittura repo; SDD gate unico | — | `.cursor-rules.md`, `AGENTS.md` |
| **#161** | RECEPTION-ALLOWLIST | Allow list ricezione; gate `send_message_to_profile`; UI «Persone consentite»; rifiuto silenzioso | RECEPTION-ALLOWLIST | `RECEPTION-ALLOWLIST.spec.md`, `contracts/schema.md`, `contracts/rpc.md`, migrazione `20260704130000` |
| **#162** | GROUP-CORE + GROUP-DELIVERY | Account `profile_kind = group`; shell senza inbox; erogazione automatica; broadcast singola riga; `original_author_id`; UI autore avatar+nome | GROUP-CORE, GROUP-DELIVERY | `GROUP-*.spec.md`, `groups-client.md`, `contracts/rpc.md`, `contracts/schema.md`, migrazioni `20260706120000`–`20260706140000` |

---

## Checklist allineamento doc (post-PR)

Dopo ogni merge su `main`:

1. **`PROJECT_MAP.md`** — stato corrente, caratteristiche
2. **`CHANGELOG.md`** — voce in `[Unreleased]` con numero PR
3. **`docs/specs/`** — spec capability (`approved` → `implemented`); REQ-ID + tracciabilità; `contracts/schema.md` / `rpc.md` se piattaforma
4. **`docs/architecture/alpha-full-stack.md`** — sezione client o piattaforma interessata
5. **`docs/INDICE.md`** — data ultimo aggiornamento
6. **`README.md`** / **`client/README.md`** — se cambia stato dev
7. **Fix dedicato** (`docs/fixes/`) — solo per bug/regressioni non ovvie
8. **Questo registro** — nuova riga in tabella (colonna Spec)
9. **`scripts/check-spec-sync.sh`** — se toccate spec o migrazioni

---

## Migrazioni Supabase (cloud `tvwpoxxcqwphryvuyqzu`)

| File | PR correlata | Contenuto |
|------|--------------|-----------|
| `20260624000000_alfred_bootstrap.sql` | pre-#109 | Bootstrap piattaforma |
| `20260624180000_platform_agent_smoke.sql` | pre-#109 | Smoke test agente |
| `20260624200000_alfred_domain_schema.sql` | #109 | Schema dominio, RLS, RPC base |
| `20260624210000_rpc_grants_hardening.sql` | #109 | Grant RPC authenticated |
| `20260624220000_list_conversations_rpc.sql` | #112 | RPC inbox (storico — sostituito) |
| `20260624230000_message_gif_support.sql` | #115 | GIF — `content_type`, `media_url`, bucket `chat-media` |
| `20260625100000_username_only_auth.sql` | #118 | Username obbligatorio registrazione |
| `20260625120000_username_availability_rpc.sql` | #118 | RPC disponibilità username |
| `20260625130000_fix_internal_auth_email_domain.sql` | #118 | Fix dominio email auth |
| `20260625140000_gotrue_allowlist_auth_email.sql` | #118 | Allowlist email GoTrue |
| `20260625150000_real_email_auth.sql` | #118 | Email reale per login |
| `20260626100000_internal_delivered_on_server.sql` | #122 | Spunte — `delivered` su insert (debito nome) |
| `20260627120000_message_voice_support.sql` | #126 | Enum `voice` (step 1) |
| `20260627120100_message_voice_support.sql` | #126 | Voice — colonne media, RPC 8 arg |
| `20260627200000_address_based_messaging.sql` | #130 | `find_profile_by_username` |
| `20260627210000_message_centric_messaging.sql` | #130 | (storico) `inbox_threads` — rimosso in `20260627230000` |
| `20260627220000_fix_send_message_to_profile_overload.sql` | #130 | Fix PostgREST HTTP 300 |
| `20260627230000_messages_only_inbox.sql` | #130 | Drop `inbox_threads`; inbox query-only |
| `20260628000000_profile_pronouns_avatars.sql` | #134 | Pronouns, bucket `avatars` |
| `20260628100000_inbox_peer_profile_fields.sql` | #134 | Avatar/pronouns peer in `list_inbox` |
| `20260702120000_message_location_support.sql` | #153 | Enum `location` (step 1) |
| `20260702120100_message_location_support.sql` | #153 | Lat/lng, RPC 10 arg, preview inbox |
| `20260704120000_mailbox_per_owner_archive.sql` | #159 | Modello caselle: archivio per `owner_id`, outbox sempre, spunte date |
| `20260704130000_reception_allowlist.sql` | #161 | Allow list ricezione; gate recapito in `send_message_to_profile` |
| `20260706120000_group_accounts.sql` | #162 | `profile_kind`, `original_author_id`, RPC gruppo, erogazione |
| `20260706130000_list_inbox_peer_profile_kind.sql` | #162 | `peer_profile_kind` in `list_inbox` |
| `20260706140000_group_broadcast_and_content_author.sql` | #162 | Broadcast singola riga; `original_author_id` sempre valorizzato |

---

**Riferimenti**: `PROJECT_MAP.md`, `docs/architecture/alpha-full-stack.md`, `CHANGELOG.md`
