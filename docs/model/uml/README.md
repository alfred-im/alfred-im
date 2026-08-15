# UML 2.5 — Alfred

**Audience**: AI / implementazione  
**Ultima revisione**: 2026-08-08

Formalizzazione del modello di dominio in **UML 2.5** (PlantUML). È il livello **forma** tra significato (DDD) ed esecuzione (statechart / codice).

Metodo completo: [docs/domain/README.md](../../domain/README.md).

---

## Strumento

- **PlantUML** — file `.puml` in `docs/model/uml/<context>/`
- Versionati in git, revisionabili in PR
- Nessun diagramma solo in immagine o in markdown inventato

---

## Tipi obbligatori per contesto

| Tipo | File | Quando |
|------|------|--------|
| **State Machine** | `<context>-state.puml` | Comportamento con stati distinti (shell UI, auth, ciclo messaggio, …) |
| **Sequence** | `seq-<nome>.puml` | Ogni flusso multi-attore o ogni adapter esterno (push, link, RPC, …) |

---

## Due profili di astrazione (sequence)

Ogni sequence usa **uno** dei profili sotto. Il profilo è dichiarato nel commento `' Profile: client | platform` del file.

### Profilo **Client** (contesti con statechart Flutter)

Contesti: auth, multi-account, navigation, notifications, shareable-link, messaging, contacts, profile, reception, groups, media.

| Consentito | Vietato |
|------------|---------|
| `Utente`, `UI`, `<Context>Machine`, altre macchine del modello | `*Service`, `*Coordinator`, `*Controller`, `*Listener` |
| `AccountManager` come unico confine effetti sessione/account | Nomi RPC/SQL (`send_message_to_profile`, `INSERT`, …) |
| Sistemi esterni rosa: `Supabase`, `ServiceWorker`, `Browser` | Classi Dart, file `.dart`, widget screen |
| Concetti dominio: `OutboundQueue`, `OutboundMediaCache` | `PostgresChange`, nomi tabella |

**Frecce:** solo comandi ed eventi da `commands-and-events.md`. L’implementazione (`MessageService`, coordinator) resta in `docs/domain/<context>/README.md`.

**Esempio:** [notifications/seq-notification-click.puml](./notifications/seq-notification-click.puml).

### Profilo **Platform** (worker, bridge, gate server)

Contesti: delivery, federation, gate recapito in reception (sequence cross-boundary).

| Consentito | Vietato |
|------------|---------|
| Attori dominio platform: `AccountBoundary`, `DeliveryWorker`, `ReceptionGate`, `Outbox`, `MailboxArchive` | Nomi funzione SQL grezzi come unico partecipante (`alfred_delivery.process_outbox`) |
| `BridgeWorker`, `FederatedServer` | Dettaglio schema (`ON CONFLICT DO NOTHING`) sulle frecce |
| Comandi worker da dominio: `ProcessDeliveryQueue`, `DeliverInternal` | |

**Esempio target:** partecipante `DeliveryWorker`, freccia `DeliverInternal` — non `DI -> MSG : INSERT …`.

### Profilo **Service** (servizi dominio senza statechart Dart)

Esempi: [multi-account/session-authority-state.puml](./multi-account/session-authority-state.puml).

| Consentito | Vietato |
|------------|---------|
| Stati **logici** osservabili dal servizio (`activeFocusUserId`, lease, transitorio switch) | Presentare il diagramma come `*Machine` in `client/lib/machines/` |
| Comandi da `commands-and-events.md` del contesto | Duplicare stati di `MultiAccountMachine` |
| Nota esplicita `Profile: service` nel file `.puml` | Estrarre enum stato Dart obbligatorio dal solo diagramma |

L'implementazione resta in `client/lib/services/` (es. `session_authority.dart`) — vedi [session-authority.md](../../domain/multi-account/session-authority.md).

---

## Convenzioni

### Nomi

- **Stati:** `PascalCase` — es. `InboxVisible`, `ReconnectingFocus`
- **Eventi / comandi sulle transizioni:** stesso nome del dominio — es. `FocusAccount`, `OpenChatFromNotification`
- **Attori Client:** `Utente`, `UI`, `<Context>Machine`, `AccountManager`, `Supabase`, `ServiceWorker`
- **Attori Platform:** `AccountBoundary`, `DeliveryWorker`, `ReceptionGate`, `Outbox`, `BridgeWorker`

### Intestazione file (commento PlantUML)

```plantuml
' Context: navigation
' Profile: client
' SDD: PROM-MULTI-ACCOUNT, PROM-PUSH-NOTIFY (solo riferimento confine prodotto)
' Revision: 2026-07-19
```

### Regole

- Una state machine per **bounded context** UI — non un mega-diagramma di tutta l'app
- Ogni sequence documenta **un** percorso; gli adapter client devono rispettarla
- Aggiornare il `.puml` **prima** del codice che cambia stati o flussi
- I nomi sulle frecce = nomi in `docs/domain/<context>/commands-and-events.md`

---

## Struttura directory

```text
docs/model/uml/
├── README.md                 # Questo file
└── <context>/
    ├── <context>-state.puml
    └── seq-*.puml
```

---

## Statechart client

Per contesti con UI a stati, l'interprete Dart in `client/lib/machines/<context>/` deve rispecchiare **1:1** stati, eventi, guard e azioni del diagramma (profilo **client**). I diagrammi profilo **service** descrivono servizi in `client/lib/services/` — vedi § Profilo Service.

Design visuale opzionale: [Stately](https://stately.ai/) / XState v5 — export come riferimento; runtime in Dart.

---

## Verifica

- Review PR: «questa transizione esiste nel `.puml`?»
- Test unitari client: evento + stato iniziale → stato finale (+ effetti attesi)
- Test citano nome transizione UML e ID promessa SDD se applicabile
