# Alfred Alpha — Architettura (panoramica)

**Data**: 2026-07-06  
**Scope**: App completa **senza bridge** (XMPP/Matrix restano stub Fly.io)  
**Stato**: PR Alpha **#108–#162** su `main`  
**Registro PR**: [alpha-pr-registry.md](./alpha-pr-registry.md)

> **Contratti (SDD)**: [docs/specs/registry.md](../specs/registry.md) — registro promesse SYSTEM / PRODUCT / SURFACE.  
> **Contratti piattaforma (SYSTEM)**: [contracts/schema.md](../specs/contracts/schema.md), [contracts/rpc.md](../specs/contracts/rpc.md).  
> Questo file è **panoramica architetturale** — non duplicare i requisiti delle promesse.

---

## 1. Panoramica sistema

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter Web (`client/`)                                   │
│  Auth · Contatti · Persone consentite · Conversazioni · Chat · Profilo · Multi-account · Gruppi │
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
└─────────────────────────────────────────────────────────────┘
```

### ADR vincolanti

| ADR | Scelta |
|-----|--------|
| D-008 | Flutter parla **solo** con Supabase |
| D-051 | Stato bridge in piattaforma (`outbox`, `sync_cursors`, `bridge_jobs`) |
| D-034 | Protocollo **mai** visibile in UI contatti/inbox |
| D-024 | Multi-account — manifest + focus; **una GoTrue attiva** (PR #152) |
| D-031 | Web **online-only** |

---

## 2. Client Flutter — struttura e bootstrap

### 2.1 Directory

```
client/lib/
├── config/      # Supabase URL, chiavi
├── models/      # DTO UI ↔ JSON
├── services/    # Thin API layer
├── providers/   # ChangeNotifier (stato UI)
├── screens/     # Shell, auth, home, contatti, profilo
├── widgets/     # Componenti presentazionali
└── utils/       # Formattazione, scroll anchor, filtri
```

### 2.2 Provider

- `ChangeNotifierProxyProvider` per contatti, profilo e allow list ricezione al cambio focus (fix PR #114)
- Inbox: `ListenableBuilder` su `focusedSession?.inboxController` (PR #140 + #152)
- Dettaglio: [PROM-MULTI-ACCOUNT](../specs/promises/product/PROM-MULTI-ACCOUNT.md), [SURF-AUTH](../specs/surfaces/SURF-AUTH.md)

### 2.3 Bootstrap

1. `bootstrapApp()` — nessuna sessione globale
2. `AuthController.initialize()` → manifest + restore focus
3. `AppShell` → sempre `HomeScreen`; overlay se 0 account

---

## 3. Promesse → area

| Area | Spec | Note |
|------|------|------|
| Multi-account, overlay auth | [PROM-MULTI-ACCOUNT](../specs/promises/product/PROM-MULTI-ACCOUNT.md), [SURF-AUTH](../specs/surfaces/SURF-AUTH.md) | PR #140, #147, #152 |
| Archivio per owner, outbox sempre | [SYS-MAILBOX](../specs/promises/system/SYS-MAILBOX.md) | PR #159 |
| Inbox on-read, `ChatPeer` | [SYS-MAILBOX](../specs/promises/system/SYS-MAILBOX.md) | PR #159 |
| Invio testo/GIF/voice/location | [SYS-MAILBOX](../specs/promises/system/SYS-MAILBOX.md) | PR #159 |
| Spunte delivered/read (`delivered_at`/`read_at`) | [SYS-MAILBOX](../specs/promises/system/SYS-MAILBOX.md) | PR #159 |
| Ricerca liste (conversazioni, contatti, allow list) | [PROM-LIST-FILTER](../specs/promises/product/PROM-LIST-FILTER.md) + [SURF-*](../specs/registry.md) | PR #132, #171 |
| Profilo, avatar, pronomi | [SYS-PROFILE](../specs/promises/system/SYS-PROFILE.md), [PROM-PROFILE-IDENTITY](../specs/promises/product/PROM-PROFILE-IDENTITY.md), [SURF-PROFILE](../specs/surfaces/SURF-PROFILE.md) | PR #118, #134 |
| Rubrica | [SYS-CONTACTS](../specs/promises/system/SYS-CONTACTS.md), [PROM-PERSONAL-CONTACTS](../specs/promises/product/PROM-PERSONAL-CONTACTS.md), [SURF-CONTACTS](../specs/surfaces/SURF-CONTACTS.md) | PR #109 |
| Allow list ricezione | [SYS-RECEPTION](../specs/promises/system/SYS-RECEPTION.md), [PROM-RECEPTION-FILTER](../specs/promises/product/PROM-RECEPTION-FILTER.md), [SURF-ALLOWLIST](../specs/surfaces/SURF-ALLOWLIST.md) | PR #161 |
| Scheda profilo peer (tap avatar) | [PROM-PEER-PROFILE](../specs/promises/product/PROM-PEER-PROFILE.md), [SURF-PEER-PROFILE](../specs/surfaces/SURF-PEER-PROFILE.md) | PR #163 |
| Account gruppo, erogazione | [SYS-GROUP](../specs/promises/system/SYS-GROUP.md) | PR #162 |

### UI cross-cutting

| Area | Contratto / evidenza |
|------|-------------------------|
| Ricerca lista on-demand | [PROM-LIST-FILTER](../specs/promises/product/PROM-LIST-FILTER.md) + [SURF-*](../specs/registry.md) — [inbox-search-toggle.md](../design/inbox-search-toggle.md) (PR #132, #171) |
| Scroll ancorato chat | [conversation-bottom-anchor.md](../design/conversation-bottom-anchor.md) (PR #125) — *backlog promessa PRODUCT* |
| ADR modello caselle | [mailbox-inbox-outbox-spec.md](./mailbox-inbox-outbox-spec.md) → [SYS-MAILBOX](../specs/promises/system/SYS-MAILBOX.md) (PR #159) |

---

## 4. Piattaforma Supabase

Schema, enum, RLS, storage: **[contracts/schema.md](../specs/contracts/schema.md)**  
RPC business logic: **[contracts/rpc.md](../specs/contracts/rpc.md)**  
Migrazioni: [alpha-pr-registry.md](./alpha-pr-registry.md) § migrazioni

### Integrazione bridge (non implementata)

```
Client → send_message_to_profile → copia archivio mittente (✓ — accettato server)
                                 → gate reception_allowlist(destinatario)
                                 → SE allowed: copia archivio destinatario + delivered_at (✓✓)
                                 → outbox completed (sempre)
Bridge → claim outbox; aggiorna external_id, sync_cursors
       → stesso gate allow list prima di materializzare copia ingresso (fase B)
```

Vedi [SYS-RECEPTION](../specs/promises/system/SYS-RECEPTION.md), [PROM-RECEPTION-FILTER](../specs/promises/product/PROM-RECEPTION-FILTER.md), [SURF-ALLOWLIST](../specs/surfaces/SURF-ALLOWLIST.md), [bridge-stateless.md](../decisions/bridge-stateless.md), [mailbox-inbox-outbox-spec.md](./mailbox-inbox-outbox-spec.md). PostgREST: **un solo overload** di `send_message_to_profile`.

---

## 5. Sicurezza Alpha

- Password solo GoTrue; RLS su tabelle dominio
- Publishable key nel client (SPA standard)
- `outbox`, `bridge_jobs`, `sync_cursors`: inaccessibili a `authenticated`

---

## 6. Testing

| Livello | Path |
|---------|------|
| Gate CI | `client/scripts/verify.sh` |
| SDD sync | `scripts/check-spec-sync.sh` |
| Integrazione | `client/scripts/integration-multi-account.sh` |
| E2E | `client/e2e/` |
| SQL smoke | `supabase/tests/` |

Tracciabilità requisiti → test: tabella **Tracciabilità** in ogni promessa (`registry.md`).

---

## 7. Deploy

| Target | Meccanismo |
|--------|------------|
| Web Alpha | GitHub Pages `/XmppTest/` — job `deploy-alpha` |
| Supabase | Migrazioni in repo → MCP/dashboard |

**Non è produzione**: l’URL https://alfred-im.github.io/XmppTest/ è **solo** l’istanza Alpha su GitHub Pages (demo, test, integrazione). Non è — e non va trattato come — un ambiente di produzione Alfred.

**Non deducibile**: URL Alpha = ultimo `deploy-alpha` riuscito (PR o push su `main`), non sempre = tip di `main`.

**Web**: `passkeys` `bundle.js` obbligatorio in `client/web/index.html` (PR #110).

Dettaglio deploy: `PROJECT_MAP.md` § Build, workflow `.github/workflows/deploy-pages.yml`.

---

## 8. Limitazioni Alpha (senza bridge)

| Funzionalità | Stato |
|--------------|-------|
| Chat Alfred stessa istanza | ✅ testo, GIF, voice, location (recapito solo se mittente ∈ allow list destinatario) |
| Chat gruppo Alfred | ✅ account gruppo, erogazione automatica, broadcast, UI autore (PR #162) |
| Allow list ricezione | ✅ sempre attiva; lista vuota = nessun recapito; UI «Persone consentite» + toggle in scheda profilo peer |
| Rubrica XMPP/Matrix | ✅ salvataggio |
| Invio federato | ⏸ outbox `pending` |
| Ricezione federata | ❌ bridge |
| Push, E2EE | ❌ fuori scope |

---

## 9. Prossimi passi (post-bridge)

1. Worker bridge: claim `outbox`
2. Ingestione inbound → copie archivio destinatario + Realtime
3. Spunte XEP-0184/0333 via bridge

---

**Riferimenti**: `PROJECT_MAP.md`, [alpha-pr-registry.md](./alpha-pr-registry.md), [docs/specs/registry.md](../specs/registry.md), [docs/specs/README.md](../specs/README.md)
