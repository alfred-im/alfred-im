# Registro PR Alpha Flutter (main)

**Ultimo aggiornamento**: 2026-06-27 (PR #126 voice, #127 verify script)  
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
| **#127** | Processo `flutter analyze` | `client/scripts/verify.sh`, gate analyze in CI/doc (branch separata) | `.cursor-rules.md`, `alpha-full-stack.md` §5, `client/README.md` |

**PR aperte (2026-06-27)**: #126 (voice + deploy-alpha workflow), #127 (verify script — non ancora su branch voice).

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

---

## Documenti legacy (non aggiornare per PR Flutter)

I file sotto descrivono il **client React** (`legacy/web-client-final`). Non vanno estesi per feature Flutter — usare `alpha-full-stack.md`.

- `docs/implementation/*` (eccetto note storiche)
- `docs/architecture/message-states.md`, `mam-*.md`, `strategy-comparison.md`
- `docs/fixes/account-storage-isolation.md` (IndexedDB XMPP)

---

**Riferimenti**: `PROJECT_MAP.md`, `docs/architecture/alpha-full-stack.md`, `CHANGELOG.md`
