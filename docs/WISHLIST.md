# Wishlist funzionalità

**Ultimo aggiornamento**: 2026-09-08

Backlog **non vincolante** — idee future oltre le promesse `implemented` in [specs/registry.md](./specs/registry.md).

---

## Già in prodotto (riferimento)

| Area | Stato | Documentazione |
|------|-------|----------------|
| Spunte cloud (inviato / consegnato / lettura) | ✅ | [server-as-reception.md](./decisions/server-as-reception.md), [PROM-MESSAGE-STATUS](./specs/promises/product/PROM-MESSAGE-STATUS.md) |
| Chat testo, GIF, voice, location, media | ✅ | [media.md](./guides/media.md), [PROM-CHAT-MEDIA](./specs/promises/product/PROM-CHAT-MEDIA.md) |
| Web Push (VAPID) | ✅ | [SYS-PUSH](./specs/promises/system/SYS-PUSH.md) |
| Inbox mailbox | ✅ | [SYS-MAILBOX](./specs/promises/system/SYS-MAILBOX.md) |
| Allow list ricezione | ✅ | [SYS-RECEPTION](./specs/promises/system/SYS-RECEPTION.md) |
| Account gruppo | ✅ | [SYS-GROUP](./specs/promises/system/SYS-GROUP.md) |
| Link condivisibili `#indirizzo` | ✅ | [PROM-SHAREABLE-LINK](./specs/promises/product/PROM-SHAREABLE-LINK.md) |
| Multi-account | ✅ | [PROM-MULTI-ACCOUNT](./specs/promises/product/PROM-MULTI-ACCOUNT.md) |
| Reazioni messaggio | ✅ | [PROM-MESSAGE-REACTIONS](./specs/promises/product/PROM-MESSAGE-REACTIONS.md) |
| Rubrica locale + federata (`user@server`) | ✅ | [SYS-CONTACTS](./specs/promises/system/SYS-CONTACTS.md) |

---

## Priorità alta

### Federazione Gotham (nativa)

Messaggistica tra istanze Alfred via [gotham-protocol.md](./architecture/gotham-protocol.md): gateway HTTP/3, worker outbox, materialize inbound.

| Pezzo | Stato |
|-------|-------|
| Spec wire + Protobuf | ✅ in repo |
| Gateway Fly | ❌ |
| Worker claim outbox | ❌ |
| Invio verso `peer_external_address` | ⏸ outbox `queued` |
| Ricezione inbound | ❌ |

### Delete chat locale

Rimozione righe dal proprio archivio senza toccare il peer; GC media con refcount logico — vedi [mailbox-inbox-outbox-spec.md](./architecture/mailbox-inbox-outbox-spec.md).

### E2EE

Fuori scope attuale; eventuale layer sopra Gotham o solo internal.

---

## Priorità media

- Chiamate vocali / video (WebRTC o integrazione dedicata)
- Messaggi programmati
- Bozze multi-dispositivo esplicite (oltre al modello mailbox attuale)

---

## Esplorazioni

Vedi [wishes/](./wishes/) per documenti non vincolanti (es. vault prove protette).
