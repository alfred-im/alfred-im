# Nessuna distinzione chat interna / esterna

**Data**: 2026-06-27  
**Status**: ✅ Accettata — **regola vincolante**  
**Categoria**: Chat, UX, client, piattaforma, bridge  
**Correlata**: [project-revolution-discovery.md](./project-revolution-discovery.md) (protocollo invisibile in UI), [bridge-stateless.md](./bridge-stateless.md), [server-as-reception.md](./server-as-reception.md)

---

## Regola

**La distinzione tra chat interna e chat esterna NON ESISTE e NON DEVE ESISTERE.**

È **vietata a qualsiasi livello**, dal client fino all'infrastruttura più bassa:

| Livello | Esempi |
|---------|--------|
| **UI / client** | Widget, controller, routing schermate, test widget/e2e |
| **Servizi client** | Repository, provider, parsing RPC |
| **Piattaforma** | Schema Postgres, enum, RPC, trigger, funzioni PL/pgSQL, RLS, migrazioni, test SQL |
| **Bridge** | Worker XMPP/Matrix, consumer outbox, job handler |
| **Documentazione** | ADR, architettura, PROJECT_MAP, commenti funzionali nel codice |

Non esiste «la chat interna» e «la chat esterna» come concetti del prodotto, del dominio o dell'implementazione.

Ogni conversazione è **una sola chat**, con lo stesso comportamento end-to-end — inclusi scroll, aggancio al fondo, elementi UI correlati, composer, indicatori, spunte, invio, ricezione, stati `delivery_status`, outbox.

---

## Cosa significa

### ✅ Unica esperienza e unico modello

- Un solo percorso di implementazione per tutte le conversazioni, **a ogni strato**
- Stesse RPC, stessi trigger di aggiornamento conversazione, stessa semantica messaggio
- Stesse regole di scroll e aggancio al fondo per ogni chat
- Stessi componenti e stessi stati; nessun ramo «se interna / se esterna»

### ❌ Vietato (ovunque)

- Branch del tipo `if (protocol == 'internal')` / `else` per **comportamento** o **semantica** della chat
- RPC, trigger o funzioni separate per «conversazioni interne» vs «conversazioni esterne/federate»
- Migrazioni, commenti SQL o nomi file che trattano due tipi di chat (es. `*_internal_*` come eccezione di prodotto)
- Implementazioni parallele (due `ChatPanel`, due pipeline messaggi, due modelli di delivery)
- Etichette, badge o sottotitoli che classificano la chat come «interna», «esterna», «Alfred», «in attesa bridge», ecc.
- Documentare o progettare feature come «solo per interne» o «solo per federate»
- Test (qualsiasi livello) che assumono comportamenti o entità diverse per tipo di chat
- Bridge o outbox che implementano **logiche di chat diverse** invece di un unico flusso con handler di recapito

---

## `protocol` / `contact_protocol` — recapito, non tipologia di chat

Il campo `protocol` su contatto/conversazione/outbox indica **solo il percorso di recapito uscente** verso la fonte di verità del destinatario:

- recapito diretto in piattaforma (nessun bridge)
- bridge XMPP
- bridge Matrix

Non classifica la conversazione come entità diversa. Coerente con [project-revolution-discovery.md](./project-revolution-discovery.md): l'utente vede persone e chat, non protocolli.

**Il routing di recapito non giustifica due chat diverse** — né in UI, né in RPC, né in trigger, né nei bridge.

---

## Relazione con [server-as-reception.md](./server-as-reception.md)

La semantica «consegnato = ricevuto sul server» vale **per tutte le conversazioni**.

Eventuali differenze di **tempistica** (messaggio subito in piattaforma vs in coda outbox fino ad ack bridge) sono proprietà del **pipeline di recapito**, non di due tipi di chat. Stesso stato `delivery_status`, stessa UI spunte, stesso modello messaggio — handler di trasporto diversi dove serve.

Documentazione e codice che contraddistinguono «chat interna» vs «federata» per spunte o delivery vanno **riallineati** a questa regola (linguaggio e implementazione).

---

## Implicazioni per l'aggancio al fondo

L'aggancio al fondo della conversazione (scroll ancorato, stacco quando si legge lo storico, riaggancio, eventuali controlli UI correlati) si applica **identicamente a tutte le conversazioni**, senza eccezioni — come ogni altra feature della chat.

---

## Violazioni note da eliminare (debito tecnico)

Riferimenti esistenti che **violano** questa regola e non vanno replicati:

**Client Flutter**
- ~~Ramificazioni su `conversation.protocol` (es. sottotitolo header)~~ — rimosso con aggancio al fondo (2026-06-27)

**Piattaforma Supabase**
- Trigger `on_message_inserted`: branch `v_protocol = 'internal'` vs `xmpp`/`matrix` con semantica chat distinta
- RPC `get_or_create_direct_conversation` descritta come «chat 1:1 interna»
- Migrazione `20260626100000_internal_delivered_on_server.sql` (nome e commenti «chat interna»)
- Documentazione in `alpha-full-stack.md` §2.9 che parla di «Alpha interna» / trigger solo per `internal`

**Obiettivo refactor**: un unico flusso messaggio/conversazione; `protocol` usato solo per selezionare l'handler di recapito uscente, senza biforcazioni di prodotto.

---

## Riferimenti

- [project-revolution-discovery.md](./project-revolution-discovery.md) — protocollo invisibile in UI
- [server-as-reception.md](./server-as-reception.md) — semantica spunte lato server (da mantenere **unificata** per tutte le chat)
- [conversation-bottom-anchor.md](../design/conversation-bottom-anchor.md) — aggancio al fondo (feature unificata)
- [alpha-full-stack.md](../architecture/alpha-full-stack.md) — da riallineare dove cita tipi di chat distinti
