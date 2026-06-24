# Alfred Alpha — Architettura completa (client + piattaforma)

**Data**: 2026-06-24  
**Scope**: App completa **senza bridge** (XMPP/Matrix restano stub Fly.io)  
**Stato**: Implementato su branch `cursor/full-app-no-bridges-3a6e`

---

## 1. Panoramica sistema

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter Web (`client/`)                                   │
│  Auth · Contatti · Conversazioni · Chat · Profilo · Multi-account │
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
├── widgets/          # Componenti presentazionali
└── utils/            # Formattazione date, colori avatar
```

### 2.2 Perché Provider (e non Riverpod/BLoC)

- Scope Alpha: pochi controller globali (`Auth`, `Conversations`, `Contacts`, `Profile`)
- `ProxyProvider` ricrea controller al cambio `userId` (switch account) senza boilerplate
- Coerente con dimensione progetto mock precedente

### 2.3 Flusso bootstrap

1. `main()` → `Supabase.initialize(publishableKey)`
2. `MultiProvider` registra controller
3. `AppShell` → `AuthScreen` se non autenticato, altrimenti `HomeScreen`

### 2.4 Multi-account

| Componente | Ruolo |
|------------|-------|
| `AccountStorageService` | Persiste lista `{userId, email, refreshToken, displayName}` in `SharedPreferences` |
| `AuthService.switchAccount()` | `supabase.auth.setSession(refreshToken)` |
| Menu account in `HomeScreen` | Lista account salvati + switch + logout |

**Scelta**: refresh token in locale (web) — accettabile per Alpha; encryption pianificata post-Alpha.

### 2.5 Realtime

| Canale | Tabelle | Scopo |
|--------|---------|-------|
| `conversations-{userId}` | `conversations`, `conversation_participants` | Aggiorna lista inbox |
| `messages-{conversationId}` | `messages` INSERT/UPDATE | Chat live + aggiornamento spunte |

**Scelta**: canali separati per inbox e chat attiva — riduce traffico rispetto a un unico firehose.

### 2.6 Invio messaggi

1. UI optimistic con `client_message_id` (UUID v4)
2. RPC `send_message` (validazione server-side)
3. Trigger `on_message_inserted` aggiorna preview/unread
4. Per protocollo `internal`: delivery immediata via Realtime
5. Per `xmpp`/`matrix`: status `pending` + riga `outbox` (bridge futuro)

### 2.7 Spunte lettura (Alpha interna)

- `mark_conversation_read` RPC apertura chat
- Aggiorna `unread_count`, inserisce `message_read_receipts`, promuove `delivery_status` a `read` per messaggi propri
- UI: `MessageStatus` → ✓ / ✓✓ / ✓✓ blu (`message_bubble.dart`)

**Nota**: XEP-0184/0333 arriveranno con bridge; schema supporta `marker_type`/`marker_for`.

---

## 3. Layer piattaforma Supabase

### 3.1 Migrazione

File: `supabase/migrations/20260624200000_alfred_domain_schema.sql`

### 3.2 Modello dati

```
auth.users 1──1 profiles
profiles 1──* contacts (owner)
profiles *──* conversations (via conversation_participants)
conversations 1──* messages
messages 1──* message_read_receipts
messages 1──0..1 outbox (se federato)
profiles 1──* sync_cursors
bridge_jobs (coda generica bridge)
```

### 3.3 Enum

| Tipo | Valori | Uso |
|------|--------|-----|
| `contact_protocol` | internal, xmpp, matrix | Routing interno (invisibile UI) |
| `message_delivery_status` | pending…failed | Spunte + outbox |
| `queue_status` | queued…failed | Outbox / bridge_jobs |

### 3.4 Contatti unificati

| `protocol` | `linked_profile_id` | `external_address` |
|------------|---------------------|--------------------|
| `internal` | obbligatorio | null |
| `xmpp` | null | JID |
| `matrix` | null | Matrix ID |

**Vincolo CHECK** in tabella — impossibile stato ibrido incoerente.

### 3.5 Conversazioni

- **Interna**: 2 partecipanti `profiles`, deduplicata da `get_or_create_direct_conversation`
- **Federata**: 1 partecipante Alfred + `contact_id` sul partecipante — titolo = `display_name` contatto

### 3.6 RPC (business logic server)

| RPC | Responsabilità |
|-----|----------------|
| `search_profiles` | Trova utenti Alfred per username/display_name |
| `get_or_create_direct_conversation` | Chat 1:1 interna idempotente |
| `get_or_create_conversation_from_contact` | Apre chat da rubrica (qualsiasi protocollo) |
| `send_message` | Validazione partecipante + body non vuoto |
| `mark_conversation_read` | Unread + read receipts |

**Scelta**: logica critica in RPC `SECURITY DEFINER` — il client non può bypassare RLS con insert diretti malformati.

### 3.7 Trigger

| Trigger | Evento | Azione |
|---------|--------|--------|
| `on_auth_user_created` | INSERT `auth.users` | Crea `profiles` da metadata signup |
| `messages_after_insert` | INSERT `messages` | Preview, unread, outbox se federato |

### 3.8 RLS

| Tabella | Policy client |
|---------|---------------|
| `profiles` | SELECT tutti autenticati; UPDATE solo proprio |
| `contacts` | CRUD solo `owner_id = auth.uid()` |
| `conversations` | SELECT se partecipante |
| `messages` | SELECT/INSERT se partecipante |
| `outbox`, `sync_cursors`, `bridge_jobs` | **DENY** authenticated — solo `service_role` (bridge) |

### 3.9 Punti integrazione bridge (non implementati)

```
Client → send_message → messages
                      → outbox (status=queued)  ← bridge worker poll/claim
Bridge → aggiorna messages.external_id, delivery_status
       → sync_cursors (MAM/Matrix token)
       → bridge_jobs (handshake, sync batch)
```

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
| Unit | `client/test/unit/` | Modelli, utils, account storage |
| Widget | `client/test/widget/` | MessageBubble, AlfredLogo |
| SQL smoke | `supabase/tests/schema_smoke.sql` | Tabelle + RPC presenti |
| Build | `flutter build web` | Compilazione release GitHub Pages |
| CI | `.github/workflows/deploy-pages.yml` | test + build su PR/main |

---

## 6. Deploy

| Target | Meccanismo |
|--------|------------|
| Web | GitHub Pages `/XmppTest/` |
| Supabase | Migrazioni in repo → MCP/dashboard |
| Bridge | **Non toccati** — health Fly.io invariato |

### Override config build

```bash
flutter build web \
  --dart-define=SUPABASE_URL=https://... \
  --dart-define=SUPABASE_ANON_KEY=...
```

---

## 7. Limitazioni Alpha (senza bridge)

| Funzionalità | Stato |
|--------------|-------|
| Chat tra utenti Alfred stessa istanza | ✅ Completa |
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

**Riferimenti**: `PROJECT_MAP.md`, `docs/decisions/project-revolution-discovery.md`, `docs/decisions/bridge-stateless.md`
