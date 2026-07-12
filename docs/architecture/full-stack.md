# Alfred — Architettura (panoramica)

**Data**: 2026-07-12  
**Scope**: App completa **senza bridge** (XMPP/Matrix restano stub Fly.io)  
**Stato**: prodotto stabile su `main`

> **Contratti (SDD)**: [docs/specs/registry.md](../specs/registry.md)

---

## 1. Panoramica sistema

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter Web (`client/`)                                   │
│  Auth · Contatti · Persone consentite · Conversazioni · Chat · Profilo · Multi-account · Gruppi · Link `#` │
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
| D-024 | Multi-account — manifest + focus; una GoTrue attiva |
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
└── utils/       # Formattazione, scroll anchor, filtri, shareable link
```

### 2.2 Provider

- `ChangeNotifierProxyProvider` per contatti, profilo e allow list al cambio focus
- Inbox: `ListenableBuilder` su `focusedSession?.inboxController`
- Dettaglio: [guides/multi-account.md](../guides/multi-account.md)

### 2.3 Bootstrap

1. `bootstrapApp()` — nessuna sessione globale
2. `AuthController.initialize()` → manifest + restore focus
3. `AppShell` → sempre `HomeScreen`; overlay se 0 account
4. `ShareableLinkListener` → fragment `#` in ingresso ([PROM-SHAREABLE-LINK](../specs/promises/product/PROM-SHAREABLE-LINK.md))

### 2.4 Link condivisibili (fragment `#`)

Dettaglio: [guides/shareable-link.md](../guides/shareable-link.md).

---

## 3. Promesse → area

| Area | Spec | Guida |
|------|------|-------|
| Multi-account, overlay auth | [PROM-MULTI-ACCOUNT](../specs/promises/product/PROM-MULTI-ACCOUNT.md), [SURF-AUTH](../specs/surfaces/SURF-AUTH.md) | [multi-account.md](../guides/multi-account.md) |
| Archivio, inbox, media, spunte | [SYS-MAILBOX](../specs/promises/system/SYS-MAILBOX.md), [SYS-DELIVERY](../specs/promises/system/SYS-DELIVERY.md) | [media.md](../guides/media.md), [mailbox-inbox-outbox-spec.md](./mailbox-inbox-outbox-spec.md) |
| Confine account | [SYS-ACCOUNT-BOUNDARY](../specs/promises/system/SYS-ACCOUNT-BOUNDARY.md) | — |
| Ricerca liste | [PROM-LIST-FILTER](../specs/promises/product/PROM-LIST-FILTER.md) | [inbox.md](../guides/inbox.md) |
| Profilo, rubrica, allow list | [SYS-PROFILE](../specs/promises/system/SYS-PROFILE.md), [SYS-CONTACTS](../specs/promises/system/SYS-CONTACTS.md), [SYS-RECEPTION](../specs/promises/system/SYS-RECEPTION.md) | [peer-profile.md](../guides/peer-profile.md) |
| Link condivisibili | [PROM-SHAREABLE-LINK](../specs/promises/product/PROM-SHAREABLE-LINK.md) | [shareable-link.md](../guides/shareable-link.md) |
| Account gruppo | [SYS-GROUP](../specs/promises/system/SYS-GROUP.md) | [groups.md](../guides/groups.md) |
| Scroll chat | backlog `PROM-BOTTOM-ANCHOR` | [chat-scroll.md](../guides/chat-scroll.md) |

---

## 4. Piattaforma Supabase

Schema, enum, RLS, storage: **[contracts/schema.md](../specs/contracts/schema.md)**  
RPC business logic: **[contracts/rpc.md](../specs/contracts/rpc.md)**  
Migrazioni: [`supabase/migrations/`](../../../supabase/migrations/)

### Integrazione bridge (non implementata)

```
Client → send_message_to_profile (account mittente)
       → INSERT copia mittente (✓)
       → INSERT outbox (event_kind=deliver)
       → alfred_delivery.process_outbox (stessa transazione, internal):
            gate reception_allowlist(destinatario)
            SE allowed: copia destinatario + delivered_at mittente (✓✓)
            ALTRIMENTI: skip silenzioso (✓ permanente)
Bridge → claim outbox federato; aggiorna external_id, sync_cursors
       → stesso gate allow list prima di materializzare copia ingresso (fase B)
```

Vedi [SYS-ACCOUNT-BOUNDARY](../specs/promises/system/SYS-ACCOUNT-BOUNDARY.md), [SYS-DELIVERY](../specs/promises/system/SYS-DELIVERY.md), [SYS-RECEPTION](../specs/promises/system/SYS-RECEPTION.md), [bridge-stateless.md](../decisions/bridge-stateless.md), [mailbox-inbox-outbox-spec.md](./mailbox-inbox-outbox-spec.md).

---

## 5. Sicurezza

- Password solo GoTrue; RLS su tabelle dominio
- Publishable key nel client (SPA standard)
- `outbox`, `bridge_jobs`, `sync_cursors`: inaccessibili a `authenticated`

---

## 6. Testing

| Livello | Path |
|---------|------|
| Gate CI | `client/scripts/verify.sh` |
| SDD sync | `scripts/check-spec-sync.sh` |
| Integrazione | `client/scripts/integration-multi-account.sh` · `bash scripts/test.sh integration-ticks` |
| E2E | `client/e2e/` |
| SQL smoke | `supabase/tests/` |

Tracciabilità requisiti → test: tabella **Tracciabilità** in ogni promessa (`registry.md`).

---

## 7. Deploy

| Target | Meccanismo |
|--------|------------|
| Web demo di sviluppo | GitHub Pages `/XmppTest/` — job `deploy-pages` |
| Supabase | Migrazioni in repo → MCP/dashboard |

**Non è produzione**: l’URL https://alfred-im.github.io/XmppTest/ è la **demo di sviluppo** su GitHub Pages (test, integrazione). Alfred è software personale open source: **non esiste** deploy di produzione né è previsto.

**Non deducibile**: URL live = ultimo `deploy-pages` riuscito (PR o push su `main`), non sempre = tip di `main`.

**Web**: `passkeys` `bundle.js` obbligatorio in `client/web/index.html` (PR #110).

Dettaglio deploy: `PROJECT_MAP.md` § Build, workflow `.github/workflows/deploy-pages.yml`.

---

## 8. Limitazioni attuali (senza bridge)

| Funzionalità | Stato |
|--------------|-------|
| Chat Alfred stessa istanza | ✅ testo, GIF, voice, location (recapito solo se mittente ∈ allow list destinatario) |
| Chat gruppo Alfred | ✅ account gruppo, erogazione automatica, broadcast, UI autore (PR #162) |
| Allow list ricezione | ✅ sempre attiva; lista vuota = nessun recapito; UI «Persone consentite» + toggle in scheda profilo peer |
| Link condivisibili | ✅ `#username` / `#username/chat`; share da profilo peer e sidebar (#178) |
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

**Riferimenti**: `PROJECT_MAP.md`, [docs/specs/registry.md](../specs/registry.md), [docs/specs/README.md](../specs/README.md)
