# Modello di dominio — Alfred

**Audience**: AI / implementazione  
**Ultima revisione**: 2026-07-18

Questo documento definisce il **metodo di rappresentazione** dell'applicazione Alfred a strati di astrazione crescente. È la fonte di verità **ingegneristica**; non duplica le promesse SDD.

---

## Una torre, non strati paralleli

```text
Più astratto ──────────────────────────────────────────────► Più concreto

  DDD + Event Storming          UML 2.5                 Statechart              Codice
  (significato)                 (forma)                 (client eseguibile)     (Dart, SQL, …)
       │                             │                         │
       └────────── stesso modello, stessi nomi ─────────────────┘

  SDD (PROM / SURF / SYS) ── solo confine prodotto: cosa l'utente osserva
```

| Livello | Linguaggio | Domanda | Dove |
|---------|------------|---------|------|
| Significato | DDD + Event Storming | Di cosa parliamo? Quali comandi ed eventi? | `docs/domain/<context>/` |
| Forma | UML 2.5 (State Machine, Sequence) | Quali stati e messaggi sono legali? | `docs/model/uml/<context>/` |
| Esecuzione client | Statechart (Stately / XState come design) | Come lo esegue Flutter? | `client/lib/machines/<context>/` |
| Confine prodotto | SDD | Cosa promettiamo all'utente? | `docs/specs/` — **solo se osservabile** |
| Implementazione | Dart, SQL, Python | Codice | `client/`, `supabase/`, `bridge-*/` |

**Regola madre:** il modello guida il codice. Il modello **non** si adatta al codice sporco.

**Regola nomi:** un comando o evento ha **un solo nome** dal post-it Event Storming al PlantUML allo statechart al Dart (`FocusAccount`, non sinonimi sparsi).

**Vietato:** linguaggi di design inventati in markdown (DSL custom, «contratti NAV» ad hoc, descrizioni di flusso duplicate in guide al posto di UML).

---

## Relazione con la SDD

La SDD **non è un quarto strato parallelo** da tenere allineato a mano con dominio e UML.

| Situazione | Cosa aggiornare |
|------------|-----------------|
| Cambio nel modello, utente **non** vede differenza | Dominio + UML (+ statechart se client) — **non** `PROM-*` |
| Cambio osservabile dall'utente | Modello **e** amend minimo su promessa SDD (riferimento a comando/stato UML, non riscrittura in prosa) |
| Solo cosmetica theme | Nessun livello del modello |

Le promesse SDD restano il **registro contrattuale** verso l'utente. Il **centro del processo** è il modello (`docs/domain/` → `docs/model/uml/` → `client/lib/machines/`).

---

## Bounded context

Mappa completa: [bounded-contexts.md](./bounded-contexts.md).

Ogni area dell'app ha una cartella in `docs/domain/<context>/` con:

- `glossary.md` — linguaggio ubiquo del contesto
- `commands-and-events.md` — output Event Storming (comandi, eventi, invarianti)

Non mescolare comandi di contesti diversi in un unico diagramma stati.

### Stato modellazione per contesto

Ogni `docs/domain/<context>/README.md` dichiara **un solo** stato tra:

| Stato | Significato | Artefatti minimi |
|-------|-------------|------------------|
| `documented` | Significato e forma UML allineati; nessuno statechart in produzione (o solo mirror documentativo) | `glossary.md`, `commands-and-events.md`, almeno un `.puml` |
| `wired` | Statechart client in `client/lib/machines/<context>/` cablato al runtime | come `documented` + directory macchina |
| `verified` | Transizioni statechart coperte da test unitari | come `wired` + `client/test/unit/<context>_machine_test.dart` |

Mappa contesti e relazioni: [bounded-contexts.md](./bounded-contexts.md) · [context-map.puml](../model/context-map.puml).

Gate CI: `bash scripts/check-model-sync.sh` (invocato da `client/scripts/verify.sh`).

---

## Event Storming (formato)

Workshop (anche asincrono) → risultato **sempre** in `commands-and-events.md`:

| Tipo | Colore (riferimento) | Esempio |
|------|----------------------|---------|
| Comando | Blu | `FocusAccount` |
| Evento di dominio | Arancio | `AccountFocused` |
| Policy / reazione | Lilla | «Se push tap → `OpenFromPushTap`» |
| Sistema esterno | Rosa | `ServiceWorker`, `Supabase` |

---

## Workflow obbligatorio

```text
Richiesta
    ↓
Quale bounded context?
    ↓
Cambio di comportamento (non solo theme / refactor 1:1)?
    ↓ Sì
Aggiornare dominio (glossario, comandi, eventi)
    ↓
Aggiornare UML (state machine; sequence se flusso multi-attore)
    ↓
Se UI client con stati: aggiornare statechart in client/lib/machines/
    ↓
L'utente osserva il cambiamento?
    ↓ Sì → amend SDD (approved prima del codice se promessa toccata)
    ↓
«Vuoi che proceda con le modifiche?» (regola 0)
    ↓
Implementazione + test (transizioni / ID promessa)
    ↓
check-spec-sync.sh + check-model-sync.sh + verify.sh
```

### Cosa richiede ogni livello

| Tipo di task | Dominio | UML | Statechart | SDD |
|--------------|---------|-----|------------|-----|
| Nuova feature UI | sì | sì | sì | se osservabile |
| Nuova RPC / schema | sì | sequence | no | SYS se osservabile |
| Bugfix semantico | amend | amend | amend | se promessa |
| Refactor 1:1 | no | no | no | no |
| Solo theme | no | no | no | no |

---

## Ingresso sessione (ordine lettura)

1. [PROJECT_MAP.md](../../PROJECT_MAP.md)
2. [bounded-contexts.md](./bounded-contexts.md)
3. Dominio + UML del **contesto** del task
4. [docs/specs/registry.md](../specs/registry.md) se tocca promesse

---

## Riferimenti

- UML: [docs/model/uml/README.md](../model/uml/README.md)
- SDD (confine prodotto): [docs/specs/README.md](../specs/README.md)
- Statechart client: [client/lib/machines/README.md](../../client/lib/machines/README.md)
- Regole agente: [`.cursor-rules.md`](../../.cursor-rules.md) § Modello
- ADR (perché architetturale): [docs/decisions/](../decisions/)
