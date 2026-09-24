# Federation — contesto dominio

**Bounded context:** `federation`  
**Stato modellazione:** `documented`  
**Ultima revisione:** 2026-09-24

Messaggistica **tra istanze Alfred** (`user@server`). Il prodotto è federato per definizione; il nome del protocollo wire compare solo nel contratto tecnico.

---

## Modello documentato (obiezioni #1–#6)

| # | Decisione | SSOT |
|---|-----------|------|
| 1 | **Outbox e spunte unificate** — worker = solo erogazione (internal vs Gotham); modulo spunte unico post-erogazione | [gotham-protocol.md](../../architecture/gotham-protocol.md) § 5.0 |
| 2 | **Wire solo su `im_server_id`** — `publicBaseUrl` escluso dal protocollo federativo | [gotham-protocol.md](../../architecture/gotham-protocol.md) § 4.0 · [client/deploy/README.md](../../../client/deploy/README.md) |
| 3 | **Profilo pubblico remoto** — `get_profiles` non gated; Gotham `GET/POST /gotham/v1/.../profile(s)`; no shadow | [gotham-protocol.md](../../architecture/gotham-protocol.md) § 4.2 · [rpc.md](../../specs/contracts/rpc.md) `get_profiles` |
| 4 | **Identità wire** — `from_user`/`to_user` bare; istanza da firma + HTTP Host; `GothamSignedEvent` obbligatorio | [gotham-protocol.md](../../architecture/gotham-protocol.md) § 3.0 · [gotham.proto](../../specs/contracts/gotham.proto) |
| 5 | **Reaction federate** — `reactor_address` (text), non `reactor_id` UUID | [schema.md](../../specs/contracts/schema.md) `message_reaction_facts` |
| 6 | **Media ingest al recapito** — blob per copia archivio; `media_fetch_url` su wire; ingresso inbox unificato | [mailbox-inbox-outbox-spec.md](../../architecture/mailbox-inbox-outbox-spec.md) § Media · [gotham-protocol.md](../../architecture/gotham-protocol.md) § 3.3 |

**Domande aperte (non esaustivo):** [gotham-protocol.md § 11.2](../../architecture/gotham-protocol.md#112-domande-aperte-elenco-non-esaustivo) — elenco vivo di quanto emerso in review; può crescere in sessioni future.

---

## Stato implementazione

| Componente | Stato |
|------------|-------|
| Contratto wire + Protobuf (doc) | ✅ |
| Schema DB (outbox, `peer_address`, allow list) | ✅ |
| Gateway Gotham + worker runtime | ❌ pianificato |
| `reactor_address`, media ingest, wire identity in codice | ❌ pianificato |

---

## Documenti

| File | Contenuto |
|------|-----------|
| [glossary.md](./glossary.md) | Termini |
| [commands-and-events.md](./commands-and-events.md) | Comandi/eventi e policy |
| [../../architecture/gotham-protocol.md](../../architecture/gotham-protocol.md) | Contratto wire completo |
| [../../model/uml/federation/](../../model/uml/federation/) | Sequence target |
| [../../model/uml/delivery/seq-media-ingest-on-delivery.puml](../../model/uml/delivery/seq-media-ingest-on-delivery.puml) | Media internal/external → inbox |

Demo paritarie Arkham / Blackgate: [client/deploy/README.md](../../../client/deploy/README.md#istanze-demo).
