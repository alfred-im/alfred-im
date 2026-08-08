# Statechart — client Flutter

**Audience**: AI / implementazione  
**Ultima revisione**: 2026-08-08

Implementazione **eseguibile** del modello UML per il client web (Flutter).

Metodo: [docs/domain/README.md](../../../docs/domain/README.md) · UML: [docs/model/uml/README.md](../../../docs/model/uml/README.md)

---

## Ruolo

Una **macchina per bounded context** con UI a stati. È l'unico posto dove si **decidono le transizioni**; i servizi (`AccountManager`, controller) sono **effetti**, non orchestratori paralleli.

```text
  Sidebar ──┐
  Push ─────┼──► <Context>Machine ──► effects ──► servizi esistenti
  Link ─────┘
  UI tap ───┘
```

---

## Struttura per contesto

```text
client/lib/machines/<context>/
├── <context>_machine.dart    # stati, eventi, transizioni, guard
├── <context>_adapters.dart   # ingressi esterni → machine.send(Event)
└── <context>_effects.dart    # azioni → AccountManager, controller, …
```

---

## Regole

- Widget e screen **leggono** lo stato della macchina; non duplicano logica di transizione
- Nuovo ingresso (push, URL, tap) = nuovo **adapter** + sequence UML — non chiamata diretta ai servizi
- Nomi identici a dominio e PlantUML (`FocusAccount`, `InboxVisible`, …)
- Design opzionale in Stately / XState; runtime sempre interprete Dart allineato al `.puml`
- Sequence UML profilo **Client**: solo `*Machine` + sistemi esterni — vedi [uml/README.md](../../../docs/model/uml/README.md)

---

## Stato attuale

| Contesto | Cartella | Stato modellazione |
|----------|----------|-------------------|
| auth | `auth/` | `verified` |
| multi-account | `multi-account/` | `verified` |
| navigation | `navigation/` | `verified` |
| shareable-link | `shareable-link/` | `verified` |
| notifications | `notifications/` | `verified` |
| messaging | `messaging/` | `verified` (4 macchine + coordinator) |
| contacts | `contacts/` | `verified` |
| profile | `profile/` | `verified` |
| reception | `reception/` | `verified` |
| groups | `groups/` | `verified` |

Altri contesti: vedi [bounded-contexts.md](../../../docs/domain/bounded-contexts.md).
