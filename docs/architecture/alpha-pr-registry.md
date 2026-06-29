# Registro PR Alpha Flutter (main)

**Ultimo aggiornamento**: 2026-06-29 (PR #143 — multi-account logout/chat/persistenza)  
**Scope**: PR mergiate su `main` dopo migrazione Flutter — riferimento per allineamento documentazione.

Documento per AI. Ogni PR deve riflettersi in: `PROJECT_MAP.md`, `CHANGELOG.md`, `docs/architecture/alpha-full-stack.md` (e fix dedicato se applicabile).

---

## Tabella PR → feature → documentazione

| PR | Titolo / commit | Cosa introduce | Dove documentato |
|----|-----------------|----------------|------------------|
| **#108** | UI chat Flutter mock | Layout conversazioni + chat, tema Alfred, deploy Pages | `CHANGELOG` [3.0.0-alpha], `PROJECT_MAP` client Flutter |
| **#109** | App completa senza bridge | Auth, contatti, chat realtime Supabase, profilo, schema dominio, RPC base | `alpha-full-stack.md`, `PROJECT_MAP` stato Alpha |
| **#110** | Passkeys bundle.js | Fix schermo bianco GitHub Pages (`passkeys_web`) | `alpha-full-stack.md` §6, `client/web/index.html` |
| **#111** | Multi-account switch | `AccountStorageService`, switch senza logout, Aggiungi account | `alpha-full-stack.md` §2.4, `CHANGELOG` multi-account |
| **#112** | `list_conversations` RPC | Inbox un round-trip, nome peer lato server | `alpha-full-stack.md` §2.5, migrazione `20260624220000` |
| **#113** | Fix race auth inbox | `waitForSupabaseSessionReady`, `sessionReady` gate, timeout load | `alpha-full-stack.md` §2.3, `fixes/flutter-inbox-stability.md` |
| **#114** | Fix provider listen | `ChangeNotifierProxyProvider` per inbox/contatti/profilo | `alpha-full-stack.md` §2.2, `fixes/flutter-inbox-stability.md` |
| **#115** | GIF in chat | `content_type`, `media_url`, bucket `chat-media` | `alpha-full-stack.md` §2.8, migrazione `20260624230000` |
| **#124** | ADR chat unificate | Nessuna distinzione interna/esterna a tutti i livelli | `docs/decisions/no-internal-external-chat-distinction.md`, `PROJECT_MAP` |
| **#125** | Aggancio al fondo | `AnchoredMessageList`, scroll ancorato, pulsante riaggancio | `alpha-full-stack.md` §2.10, `docs/design/conversation-bottom-anchor.md` |
| **#126** | Note vocali in chat | WebM/Opus, `content_type=voice`, registrazione hold-to-send, player, `OutboundMessageQueue` | `alpha-full-stack.md` §2.11, `docs/implementation/voice-notes.md` |
| **#127** | Processo `flutter analyze` | `client/scripts/verify.sh`, gate analyze in CI/doc | `.cursor-rules.md`, `alpha-full-stack.md` §5, `client/README.md` |
| **#130** | Inbox solo messaggi | Drop `inbox_threads`; `ChatPeer`; `list_peer_messages`, `mark_peer_read`; fix HTTP 300 overload | `address-based-messaging.md`, `messages-only-inbox.md`, migrazioni `20260627200000`–`20260627230000` |
| **#131** | Sidebar logout in card profilo | Rimossa spunta verde account attivo; logout icona a destra del nome nella card profilo | `PROJECT_MAP.md` § layout inbox, `alpha-full-stack.md` §2.4 |
| **#132** | Ricerca on-demand inbox | Barra ricerca nascosta; lente + `TapRegion` tap-outside; `dismissSearch()` unico; `ValueKey(userId)` | `docs/design/inbox-search-toggle.md`, `PROJECT_MAP.md` § layout inbox, `alpha-full-stack.md` §2.12 |
| **#140** | Multi-account sessioni parallele | `AccountManager` / `AccountSession`; N×`SupabaseClient`; focus UI-only; overlay auth su shell; `OpenAccount` | `multi-account-parallel-sessions.md`, `multi-account-client.md`, `auth-overlay-shell.md`, `alpha-full-stack.md` §2.3–2.4 |
| **#141** | Fix add-account (parziale) | `_sessionFromAuthResponse` fast path access+refresh; bootstrap ancora con `signOut` nel `finally` | `auth-bootstrap-gotrue-revoke.md` § stato main |
| **#142** | Auth bootstrap completo | Rimosso `signOut` post-login; `EphemeralPkceStorage`; test live password reset; doc agente/handoff | `auth-bootstrap-gotrue-revoke.md`, `AGENT_DEBUG_ACCOUNTS.md`, `SESSION_HANDOFF.md` |
| **#143** | Multi-account fix + test | Logout locale; view per account; persistenza atomica F5; inbox provider lifecycle; test regressione mock | `multi-account-chat-persistence-pr143.md`, `multi-account-client.md` §6, `SESSION_HANDOFF.md` |

---

## Checklist allineamento doc (post-PR)

Dopo ogni merge su `main`:

1. **`PROJECT_MAP.md`** — stato corrente, caratteristiche, contraddizioni (no "mock" se produzione)
2. **`CHANGELOG.md`** — voce in `[Unreleased]` con numero PR
3. **`docs/architecture/alpha-full-stack.md`** — sezione client o piattaforma interessata
4. **`docs/INDICE.md`** — data ultimo aggiornamento
5. **`README.md`** / **`client/README.md`** — se cambia stato utente-dev
6. **Fix dedicato** (`docs/fixes/`) — solo per bug/regressioni non ovvie
7. **Questo registro** — nuova riga in tabella

---

## Migrazioni Supabase (cloud `tvwpoxxcqwphryvuyqzu`)

| File | PR correlata | Contenuto |
|------|--------------|-----------|
| `20260624000000_alfred_bootstrap.sql` | pre-#109 | Bootstrap piattaforma |
| `20260624180000_platform_agent_smoke.sql` | pre-#109 | Smoke test agente |
| `20260624200000_alfred_domain_schema.sql` | #109 | Schema dominio, RLS, RPC base |
| `20260624210000_rpc_grants_hardening.sql` | #109 | Grant RPC authenticated |
| `20260624220000_list_conversations_rpc.sql` | #112 | RPC inbox |
| `20260624230000_message_gif_support.sql` | #115 | GIF — `content_type`, `media_url`, bucket `chat-media` |
| `20260626100000_internal_delivered_on_server.sql` | — | Spunte — `delivered` su insert server |
| `20260627120000_message_voice_support.sql` | #126 | Enum `voice` (step 1) |
| `20260627120100_message_voice_support.sql` | #126 | Voice — colonne media, RPC 8 arg, bucket `audio/webm` |
| `20260627200000_address_based_messaging.sql` | #130 | `find_profile_by_username`, filtro inbox con messaggi |
| `20260627210000_message_centric_messaging.sql` | #130 | (storico) `inbox_threads` — rimosso in `20260627230000` |
| `20260627220000_fix_send_message_to_profile_overload.sql` | #130 | Fix PostgREST HTTP 300 — drop overload 3-arg |
| `20260627230000_messages_only_inbox.sql` | #130 | Drop `inbox_threads`; inbox query-only; `list_peer_messages`, `mark_peer_read` |

---

**Riferimenti**: `PROJECT_MAP.md`, `docs/architecture/alpha-full-stack.md`, `CHANGELOG.md`
