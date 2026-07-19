# UML 2.5 — Alfred

**Audience**: AI / implementazione  
**Ultima revisione**: 2026-07-19

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

## Convenzioni

### Nomi

- **Stati:** `PascalCase` — es. `InboxVisible`, `ReconnectingFocus`
- **Eventi / comandi sulle transizioni:** stesso nome del dominio — es. `FocusAccount`, `OpenFromPushTap`
- **Attori tipici:** `Utente`, `UI`, `<Context>Machine`, `AccountManager`, `Supabase`, `ServiceWorker`

### Intestazione file (commento PlantUML)

```plantuml
' Context: navigation
' SDD: PROM-MULTI-ACCOUNT, PROM-PUSH-NOTIFY (solo riferimento confine prodotto)
' Revision: 2026-07-18
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

Per contesti con UI a stati, l'interprete Dart in `client/lib/machines/<context>/` deve rispecchiare **1:1** stati, eventi, guard e azioni del diagramma.

Design visuale opzionale: [Stately](https://stately.ai/) / XState v5 — export come riferimento; runtime in Dart.

---

## Verifica

- Review PR: «questa transizione esiste nel `.puml`?»
- Test unitari client: evento + stato iniziale → stato finale (+ effetti attesi)
- Test citano nome transizione UML e ID promessa SDD se applicabile
