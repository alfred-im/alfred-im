# Nessuna distinzione chat locale / federata

**Data**: 2026-08-08  
**Ultima revisione**: 2026-09-13 — amend §7 routing su `peer_address`  
**Status**: ✅ Accettata — **regola vincolante**  
**Categoria**: Chat, UX, client, piattaforma  
**Correlata**: [server-as-reception.md](./server-as-reception.md), [address-based-messaging.md](./address-based-messaging.md)

---

## Regola

**La distinzione tra chat locale e chat federata NON ESISTE e NON DEVE ESISTERE** come tipologia di prodotto.

È **vietata a qualsiasi livello**:

| Livello | Esempi |
|---------|--------|
| **UI / client** | Widget, controller, routing schermate, test widget/e2e |
| **Servizi client** | Repository, provider, parsing RPC |
| **Piattaforma** | Schema Postgres, RPC, trigger, funzioni PL/pgSQL, RLS, migrazioni, test SQL |
| **Documentazione** | ADR, architettura, PROJECT_MAP, commenti funzionali nel codice |

Ogni conversazione è **una sola chat**, con lo stesso comportamento end-to-end — scroll, composer, spunte, invio, ricezione, outbox.

---

## Cosa significa

### ✅ Unica esperienza e unico modello

- Un solo percorso di implementazione per tutte le conversazioni
- Stesse RPC (`send_message_to_address`, `list_peer_messages`, `mark_peer_read`), stessa semantica messaggio, stessi componenti UI
- Nessun ramo «se locale / se federato» per comportamento chat
- Chiave runtime unica: **`peer_address`** (stringa lowercase)

### ❌ Vietato

- Branch per **comportamento** o **semantica** della chat in base a locale vs federato
- RPC, trigger o funzioni separate per «conversazioni locali» vs «federate»
- Etichette, badge o sottotitoli che classificano la conversazione per tipologia locale vs federata
- Colonne `protocol` o split **`peer_profile_id` / `peer_external_address`** — sostituiti da **`peer_address`**
- UUID profilo come chiave conversazione in client, push, navigation, realtime

---

## Routing — indirizzo, non tipologia chat

| Destinazione | Compose / chiave DB | Driver recapito |
|--------------|---------------------|-----------------|
| Stessa istanza | `peer_address` = `username` o `username@im_server_id` | Worker locale (sincrono) |
| Altra istanza Alfred | `peer_address` = `user@server` | Worker Gotham (async) |

**Delivery** è l'unico modulo che legge `@server` e sceglie il driver. **Gotham** = trasporto cross-server, non tipo di chat.

L'utente vede persone e indirizzi, non protocolli né tipi di chat.

### Allow list e inbox

- Allow list: una voce = un **`allowed_address`** — `mario` e `mario@im_server_id` = voci distinte (§7.2)
- Inbox asimmetrica per archivio: Paolo vede `mario@blackgate…`; Mario vede `paolo@arkham…` (§7.3)

---

## Relazione con [server-as-reception.md](./server-as-reception.md)

La semantica «consegnato = ricevuto sul server» vale **per tutte le conversazioni**.

Differenze di **tempistica** (recapito immediato vs outbox `queued`) sono proprietà del **pipeline di recapito**, non di due tipi di chat.

---

## Riferimenti

- [server-as-reception.md](./server-as-reception.md) — semantica spunte
- [gotham-protocol.md](../architecture/gotham-protocol.md) — contratto wire federazione
- [mailbox-inbox-outbox-spec.md](../architecture/mailbox-inbox-outbox-spec.md) — modello caselle
- [contracts/schema.md](../specs/contracts/schema.md) · [contracts/rpc.md](../specs/contracts/rpc.md) — contratto target §7
- [full-stack.md](../architecture/full-stack.md) — panoramica stack
