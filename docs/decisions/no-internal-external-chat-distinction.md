# Nessuna distinzione chat locale / federata

**Data**: 2026-08-08  
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
- Stesse RPC, stessa semantica messaggio, stessi componenti UI
- Nessun ramo «se locale / se federato» per comportamento chat

### ❌ Vietato

- Branch per **comportamento** o **semantica** della chat in base a locale vs federato
- RPC, trigger o funzioni separate per «conversazioni locali» vs «federate»
- Etichette, badge o sottotitoli che classificano la chat come «interna», «esterna», «in attesa federazione», ecc.
- Colonne `protocol` o enum equivalenti — il routing è implicito da `peer_profile_id` vs `peer_external_address`

---

## Routing — indirizzo, non tipologia chat

| Destinazione | Campo DB / compose | Driver recapito |
|--------------|-------------------|-----------------|
| Stessa istanza | `peer_profile_id` / `username` | Worker internal (sincrono) |
| Altra istanza Alfred | `peer_external_address` / `user@server` | Worker Gotham (async, pianificato) |

L'utente vede persone e indirizzi, non protocolli né tipi di chat.

---

## Relazione con [server-as-reception.md](./server-as-reception.md)

La semantica «consegnato = ricevuto sul server» vale **per tutte le conversazioni**.

Differenze di **tempistica** (recapito immediato vs outbox `queued`) sono proprietà del **pipeline di recapito**, non di due tipi di chat.

---

## Riferimenti

- [server-as-reception.md](./server-as-reception.md) — semantica spunte
- [gotham-protocol.md](../architecture/gotham-protocol.md) — federazione wire
- [mailbox-inbox-outbox-spec.md](../architecture/mailbox-inbox-outbox-spec.md) — modello caselle
- [full-stack.md](../architecture/full-stack.md) — panoramica stack
