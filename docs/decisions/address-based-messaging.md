# Messaggistica per indirizzo (username / username@server)

**Data**: 2026-08-08 (semantica delivery allineata post-#179)  
**Ultima revisione**: 2026-09-13 — amend §7 `peer_address`  
**Status**: ✅ Accettata — **regola vincolante** (indirizzo + rubrica isolata)  
**Categoria**: Chat, inbox, rubrica, client, piattaforma  
**Correlata**: [no-internal-external-chat-distinction.md](./no-internal-external-chat-distinction.md), [server-as-reception.md](./server-as-reception.md)

### Contratti e architettura

Vedi [SSOT.md](../SSOT.md) — non duplicare RPC/tabelle qui. Riferimenti rapidi:

- [mailbox-inbox-outbox-spec.md](../architecture/mailbox-inbox-outbox-spec.md)
- [contracts/rpc.md](../specs/contracts/rpc.md)
- [contracts/schema.md](../specs/contracts/schema.md)
- [registry.md](../specs/registry.md)

---

## Regola (questo ADR)

**Si scrive a un indirizzo. La rubrica non abilita né blocca la messaggistica.**

| Concetto | Ruolo |
|----------|--------|
| **Indirizzo** | Destinatario e chiave conversazione: `username` o `username@server` (lowercase) — colonna **`peer_address`** |
| **Identità mittente** | **`author_address`** — forma che fa fede nella comunicazione (§7.4–§7.5b) |
| **Messaggi** | Archivio **per titolare archivio** in `messages` — vedi mailbox spec |
| **Inbox** | Aggregazione **on-read** sul mio archivio (`list_inbox()`), raggruppata per **`peer_address`** — **nessuna tabella inbox** |
| **Presentazione** | **`get_profiles(addresses[])`** batch — profilo pubblico sempre; fallback indirizzo grezzo |
| **Rubrica (`contacts`)** | Solo **`address`** lowercase — **isolata** da messaggistica e allow list |

### Indirizzamento

| Tipo | Formato | Esempio | Stato target |
|------|---------|---------|--------------|
| Stessa istanza (bare) | `username` | `mario` | ✅ |
| Stessa istanza (FQDN locale) | `username@im_server_id` | `mario@arkham-im.fly.dev` | ✅ — conversazione **distinta** da bare |
| Altra istanza Alfred | `username@server` | `mario@blackgate-im.fly.dev` | ✅ — stessa UI/RPC; driver Gotham in delivery |

**Regola §7.2**: `mario` e `mario@<im_server_id>` non si fondono — stringhe diverse = chat e allow list distinte.

---

## Cosa significa

### ✅ Corretto

- FAB / nuova chat: inserisci indirizzo → apri chat con quel **`peer_address`**
- Chat vuota o con storico: **stessa UI**, stesso indirizzo canonico
- Primo messaggio: insert in `messages` → inbox al prossimo `list_inbox()` (aggregazione live)
- Messaggio ricevuto da chiunque → inbox **senza** rubrica
- Rubrica: scorciatoia con solo `address`; «Scrivi» apre chat per quell'indirizzo
- Presentazione nome/avatar: `get_profiles` batch — **non** snapshot in `contacts`

### ❌ Vietato

- Tabella `inbox_threads`, `conversations`, `conversation_participants` o **cache inbox**
- **FK verso aggregati inbox** (`messages.inbox_thread_id`, ecc.)
- Vista materializzata inbox come fonte di verità
- `thread_id` o **`peer_profile_id` UUID** esposti al client come chiave chat
- Concetti «bozza», «promozione thread», `get_or_create_*`
- `contact_id` come prerequisito per scrivere
- Record inbox/conversazione **prima** del primo messaggio
- Profili shadow in `profiles` per peer remoti
- Rubrica come cache profilo (nome/avatar denormalizzati)

---

## Inbox = aggregazione on-read (non materializzata)

L'inbox **non** è tabella né vista materializzata. È query sul **mio** archivio a ogni `list_inbox()`:

1. Fonte: `messages` WHERE `archive_user_id = auth.uid()`
2. Calcolo: **`GROUP BY peer_address`**, ultimo messaggio, unread (entrata via `author_address`, `read_at IS NULL`)
3. Presentazione: `get_profiles` batch lato client; inbox mostra indirizzo subito
4. Realtime inbox: subscribe `messages` (`archive_user_id = io`); reload `list_inbox()` su INSERT
5. Realtime chat: filtro server `archive_user_id = io`; client **`peer_address`**

Equivalente: `VIEW` SQL normale (non `MATERIALIZED`). L'RPC serve per `security definer`, `auth.uid()` e payload formattato — dettaglio in [contracts/rpc.md](../specs/contracts/rpc.md#list_inbox).

**Perché niente cache inbox:** preview/unread duplicati divergono da `messages` e invitano FK sul derivato.

---

## Delivery e spunte (post-#179 — sintesi)

Questo ADR **non** definisce RPC né worker. Regola di confine:

| Attore | Può toccare |
|--------|-------------|
| RPC account (`send_message_to_address`, `mark_peer_read`, …) | **Solo** archivio `archive_user_id = auth.uid()` + INSERT `outbox` |
| Worker `alfred_delivery` | Materializza copia destinatario, `delivered_at` / `read_at` mittente (via λ), gate allow list su **indirizzo**, routing `@server` |

Flusso locale (un solo posto con diagramma completo): [mailbox-inbox-outbox-spec.md § Consegna](../architecture/mailbox-inbox-outbox-spec.md#consegna--stessa-pipeline-ovunque-vincolante).  
Semantica ✓ / ✓✓ / blu: [server-as-reception.md](./server-as-reception.md).

`delivered_at` / `read_at` / `failed_at` su righe archivio — non enum `delivery_status`.

---

## Client (puntatori)

- Identità chat: `ChatPeer` keyed su **`peer_address`** — [no-internal-external-chat-distinction](./no-internal-external-chat-distinction.md)
- Presentazione: `ProfileService.fetchByAddresses` / `get_profiles`
- Multi-account + inbox: [guides/multi-account.md](../guides/multi-account.md)
- Push: **`peerAddress`** — [push-payload.md](../specs/contracts/push-payload.md)
- Codice target: `ComposeService`, `InboxController`, `MessagesController` — [PROJECT_MAP.md](../../PROJECT_MAP.md)

---

## Migrazioni (indirizzo / inbox on-read)

Solo storico **indirizzamento** e drop cache inbox; delivery plane (#159, #179) in mailbox spec e `supabase/migrations/`.

**Prossima migrazione (§7.7)**: `peer_address`, `author_address`, `allowed_address`, `contacts.address`; drop colonne UUID chat.

- `20260627200000_address_based_messaging.sql` — `find_profile_by_username`
- `20260627230000_messages_only_inbox.sql` — drop `inbox_threads`
- `20260704120000_mailbox_per_archive_user.sql` — archivio per titolare archivio (#159)
- `20260719220000_list_peer_messages_recent_window.sql` — finestra recente + cursore
- *(pendente)* `peer_address_migration` — amend §7 TEMP
