# Design - Riferimenti Tecnici

Principi design e decisioni architetturali design-related. Documento per AI.

**Note**: Brand identity e architettura database (incluso **IndexedDB per account** v2.2) sono in `PROJECT_MAP.md` — sezioni Design System, Database e Storage, Principi Architetturali.

## Principi CSS (Riferimento Rapido)

**Layout**: Prediligere SEMPRE flexbox. Grid solo per layout bidimensionali complessi.

**Utility Classes**: `.scrollable-container` per scroll verticale con touch support (vedi `../implementation/scrollable-containers.md`)

**Colore Primario**: `#2D2926` (Dark Charcoal)

**Typography**: Inter, SF Pro Display, system-ui

**Components**: Radius 8-12px, shadow sottili, transitions 150-300ms

**Breakpoints**: Mobile-first, tablet 768px, desktop 1024px, touch targets min 48px

**Chat — aggancio al fondo**: vedi [conversation-bottom-anchor.md](./conversation-bottom-anchor.md) — comportamento unico per tutte le conversazioni
