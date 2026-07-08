# Registro promesse — Alfred

**Ultima revisione**: 2026-07-08  
**Metodo**: [README.md](./README.md) (SDD v2)

Indice unico di promesse SYSTEM, PRODUCT e SURFACE. Per capability legacy v1: [index.md](./index.md).

Legenda stato: `draft` | `approved` | `implemented` | `deprecated` | `superseded`

---

## SYSTEM — piattaforma

Dettaglio completo (schema, RPC, RLS, smoke): **[contracts/schema.md](./contracts/schema.md)** · **[contracts/rpc.md](./contracts/rpc.md)**

| Ambito | Documento | Stato | Note |
|--------|-----------|-------|------|
| Schema DB, enum, RLS, storage | [contracts/schema.md](./contracts/schema.md) | `implemented` | Promesse SYS su tabelle `profiles`, `messages`, `outbox`, `contacts`, `reception_allowlist`, … |
| RPC messaggistica e profili | [contracts/rpc.md](./contracts/rpc.md) | `implemented` | `list_inbox`, `send_message_to_profile`, `search_profiles`, `mark_peer_read`, … |
| Capability bundle legacy | [capabilities/](./capabilities/) | `implemented` | `MAILBOX-*`, `GROUP-*`, `RECEPTION-ALLOWLIST`, … — REQ-ID storici; backend authoritative fino a distillazione |

---

## PRODUCT — promesse riusabili

| Promessa ID | Titolo | Stato | File |
|-------------|--------|-------|------|
| **PROM-LIST-FILTER** | Filtro locale su lista + ricerca on-demand (lente) | `implemented` | [PROM-LIST-FILTER.md](./promises/product/PROM-LIST-FILTER.md) |

---

## SURFACE — binding per schermata

| Superficie ID | Titolo | Stato | Promesse | File |
|---------------|--------|-------|----------|------|
| **SURF-INBOX** | Lista conversazioni (`InboxPanel`) | `implemented` | PROM-LIST-FILTER | [SURF-INBOX.md](./surfaces/SURF-INBOX.md) |
| **SURF-CONTACTS** | Rubrica (`ContactsScreen`) | `implemented` | PROM-LIST-FILTER | [SURF-CONTACTS.md](./surfaces/SURF-CONTACTS.md) |
| **SURF-ALLOWLIST** | Persone consentite (`AllowedPeopleScreen`) | `implemented` | PROM-LIST-FILTER | [SURF-ALLOWLIST.md](./surfaces/SURF-ALLOWLIST.md) |

---

## Mappa legacy → v2

| Documento v1 | Promesse v2 |
|--------------|-------------|
| [INBOX-SEARCH.spec.md](./capabilities/INBOX-SEARCH.spec.md) | PROM-LIST-FILTER + SURF-INBOX |
| [CONTACTS.spec.md](./capabilities/CONTACTS.spec.md) REQ-013 (filtro) | PROM-LIST-FILTER + SURF-CONTACTS |
| [RECEPTION-ALLOWLIST.spec.md](./capabilities/RECEPTION-ALLOWLIST.spec.md) (filtro lista UI) | PROM-LIST-FILTER + SURF-ALLOWLIST |
| `contracts/*` | SYSTEM (invariato) |

---

## Backlog promesse (proposte)

| ID proposto | Classe | Contenuto |
|-------------|--------|-----------|
| PROM-OVERLAY-DISMISS | PRODUCT | Chiusura overlay fullscreen (peer profile, …) |
| PROM-BOTTOM-ANCHOR | PRODUCT | Lista messaggi agganciata al fondo |
| SURF-AUTH | SURFACE | Login/registrazione multi-account |
| BRIDGE-* | SYSTEM | Consumer outbox federato (fase post-Alpha) |
