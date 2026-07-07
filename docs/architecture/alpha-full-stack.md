# Alfred Alpha — Architettura (panoramica)

**Data**: 2026-07-06  
**Scope**: App completa **senza bridge** (XMPP/Matrix restano stub Fly.io)  
**Stato**: PR Alpha **#108–#162** su `main`  
**Registro PR**: [alpha-pr-registry.md](./alpha-pr-registry.md)

> **Contratti capability**: [docs/specs/index.md](../specs/index.md) — fonte canonica per inbox, invio, spunte, profilo, rubrica, multi-account.  
> **Contratti piattaforma**: [contracts/schema.md](../specs/contracts/schema.md), [contracts/rpc.md](../specs/contracts/rpc.md).  
> Questo file è **panoramica architetturale** — non duplicare i requisiti delle spec.

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
- Dettaglio: [AUTH-MULTI.spec.md](../specs/capabilities/AUTH-MULTI.spec.md)

### 2.3 Bootstrap

1. `bootstrapApp()` — nessuna sessione globale
2. `AuthController.initialize()` → manifest + restore focus
3. `AppShell` → sempre `HomeScreen`; overlay se 0 account

---

## 3. Capability → spec (contratti su `main`)

| Area | Spec | Note |
|------|------|------|
| Multi-account, overlay auth | [AUTH-MULTI](../specs/capabilities/AUTH-MULTI.spec.md) | PR #140, #147, #152 |
| Archivio per owner, outbox sempre | [MAILBOX-CORE](../specs/capabilities/MAILBOX-CORE.spec.md) | PR #159 |
| Inbox on-read, `ChatPeer` | [MAILBOX-INBOX](../specs/capabilities/MAILBOX-INBOX.spec.md) | PR #159 |
| Invio testo/GIF/voice/location | [MAILBOX-SEND](../specs/capabilities/MAILBOX-SEND.spec.md) | PR #159 |
| Spunte delivered/read (`delivered_at`/`read_at`) | [MAILBOX-READ](../specs/capabilities/MAILBOX-READ.spec.md) | PR #159 |
| Ricerca conversazioni | [INBOX-SEARCH](../specs/capabilities/INBOX-SEARCH.spec.md) | PR #132 |
| Profilo, avatar, pronomi | [PROFILE](../specs/capabilities/PROFILE.spec.md) | PR #118, #134 |
| Rubrica | [CONTACTS](../specs/capabilities/CONTACTS.spec.md) | PR #109 |
| Allow list ricezione | [RECEPTION-ALLOWLIST](../specs/capabilities/RECEPTION-ALLOWLIST.spec.md) | PR #161 |
| Scheda profilo peer (tap avatar) | [PEER-PROFILE](../specs/capabilities/PEER-PROFILE.spec.md) | PR #163 |
| Account gruppo, erogazione | [GROUP-CORE](../specs/capabilities/GROUP-CORE.spec.md), [GROUP-DELIVERY](../specs/capabilities/GROUP-DELIVERY.spec.md) | PR #162 |

### UI cross-cutting (senza spec capability dedicata)

| Area | Documento |
|------|-----------|
| Scroll ancorato chat | [conversation-bottom-anchor.md](../design/conversation-bottom-anchor.md) (PR #125) |
| ADR modello caselle | [mailbox-inbox-outbox-spec.md](./mailbox-inbox-outbox-spec.md) (PR #123, #136, #159) |

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

Vedi [RECEPTION-ALLOWLIST](../specs/capabilities/RECEPTION-ALLOWLIST.spec.md), [bridge-stateless.md](../decisions/bridge-stateless.md), [mailbox-inbox-outbox-spec.md](./mailbox-inbox-outbox-spec.md). PostgREST: **un solo overload** di `send_message_to_profile`.

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

Tracciabilità requisiti → test: sezione **Tracciabilità** in ogni spec (pilota: MAILBOX-SEND).

---

## 7. Deploy

| Target | Meccanismo |
|--------|------------|
| Web Alpha | GitHub Pages `/XmppTest/` — job `deploy-alpha` |
| Supabase | Migrazioni in repo → MCP/dashboard |

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

**Riferimenti**: `PROJECT_MAP.md`, [alpha-pr-registry.md](./alpha-pr-registry.md), [docs/specs/README.md](../specs/README.md)
