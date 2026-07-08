# Spec-Driven Development (SDD) — Alfred

**Audience**: AI / implementazione  
**Ultima revisione**: 2026-07-08  
**Versione metodo**: SDD — unico metodo di specifica

Alfred esce dalla fase Alpha: il metodo governa **tutto ciò che il prodotto promette** all'utente e ai componenti — schema, RPC, comportamento riusabile e binding per superficie.

---

## Una domanda per ogni task

> **Quale promessa creo, estendo o rompo?**

| Risposta | Azione |
|----------|--------|
| Nessuna — solo cosmetica **theme** (colori, spacing, font) senza cambio interazione | Fuori SDD → regola 0 |
| Promessa SYSTEM, PRODUCT o SURFACE nuova o modificata | SDD obbligatoria → `draft` → **`approved`** → implementazione |
| Estendo un pattern PRODUCT già `implemented` su una nuova superficie | Amend **SURFACE** (+ eventuale PRODUCT) → **`approved`** prima del codice |

**Non esiste** la categoria «è solo UX»: se l'utente osserva un comportamento diverso, è una promessa.

---

## Tre classi di promessa

```
SYSTEM   — piattaforma: schema, RPC, RLS, errori, smoke SQL
PRODUCT  — comportamento utente riusabile su più superfici
SURFACE  — binding: quali promesse PRODUCT/SYSTEM su schermata/widget
```

### SYSTEM (backend intatto)

Le promesse di piattaforma restano in:

- [contracts/schema.md](./contracts/schema.md)
- [contracts/rpc.md](./contracts/rpc.md)

Ogni tabella, RPC, enum, policy RLS e smoke SQL documentati lì **non perdono dettaglio**. Per modifiche backend si aggiornano **contracts/** + promessa SYSTEM correlata (`SYS-*`).

Vedi anche [promises/system/README.md](./promises/system/README.md).

### PRODUCT

Promesse cross-cutting in `docs/specs/promises/product/`.

Esempio: [PROM-LIST-FILTER](./promises/product/PROM-LIST-FILTER.md) — filtro locale + ricerca on-demand (lente, dismiss, tap-outside).

Una superficie **referenzia** una promessa PRODUCT; **non** la reimplementa con regole diverse.

### SURFACE

Binding in `docs/specs/surfaces/`.

Esempio: [SURF-CONTACTS](./surfaces/SURF-CONTACTS.md) — quali campi filtra la rubrica, hint, componenti Flutter.

---

## ID stabili

| Prefisso | File tipico | Esempio |
|----------|-------------|---------|
| `SYS-*` | `promises/system/SYS-*.md`, `contracts/*.md` | `SYS-MAILBOX-020` |
| `PROM-*` | `promises/product/PROM-*.md` | `PROM-LIST-FILTER-002` |
| `SURF-*` | `surfaces/SURF-*.md` | `SURF-CONTACTS-001` |

Nuovo lavoro: usare esclusivamente `SYS-*` / `PROM-*` / `SURF-*`.

---

## Lifecycle

```
draft → approved → implemented → deprecated | superseded
```

| Stato | Significato |
|-------|-------------|
| `draft` | Bozza; non vincolante |
| `approved` | **Promessa congelata** — si può implementare |
| `implemented` | Su `main`; tracciabilità verificata |
| `deprecated` / `superseded` | Non usare per nuovo lavoro |

---

## Struttura directory

```
docs/specs/
├── README.md                 # Questo file (SDD)
├── registry.md               # Indice unico promesse + stato
├── index.md                  # Catalogo promesse
├── _template-promise-product.md
├── _template-surface.md
├── promises/
│   ├── product/              # PROM-*
│   └── system/               # SYS-* + README
├── surfaces/                 # SURF-*
└── contracts/                # Dettaglio DDL/RPC (canonico backend)
```

---

## Layer documentali

| Layer | Dove | Ruolo |
|-------|------|--------|
| **ADR** | `docs/decisions/` | Perché architetturale — non cosa promettiamo |
| **Promesse** | `promises/`, `surfaces/`, `contracts/` | **Contratto** — cosa è garantito |
| **Panoramica** | `PROJECT_MAP.md`, `alpha-full-stack.md` | Orientamento — **non** duplicare promesse |
| **Evidenza** | `docs/design/`, `docs/implementation/` | Storico PR; header `superseded by` promessa |
| **Test** | `client/test/`, `supabase/tests/` | Verifica; citati in tracciabilità |

---

## Regole fondamentali

### Verificabilità

Ogni promessa MUST ha almeno una verifica:

- test automatico (`client/test/`, widget/unit)
- smoke SQL (`supabase/tests/`)
- scenario manuale scritto (Gherkin o tabella in spec)

Se non è verificabile, non è una promessa.

### Anti-drift

- **MUST NOT**: implementare su una superficie un pattern PRODUCT già definito senza `SURF-*` che lo referenzia.
- **MUST NOT**: duplicare logica di dismiss/chiusura fuori dal punto unico documentato nella promessa PRODUCT.
- **MUST NOT**: callback sparse nel parent per chiudere ricerca o overlay se la promessa PRODUCT vieta enumerazione (es. tap-outside).

### Cosmetica (fuori SDD)

Solo token theme: colori, padding, font, animazioni non legate a semantica. Refactor 1:1 che non cambia promesse approvate.

### Distinzione da regola 0

| | SDD | Regola 0 |
|--|-----|----------|
| **Ambito** | Processo end-to-end | Solo scrittura fisica nel repo |
| **Gate** | Promessa `approved` + tracciabilità | «Vuoi che proceda con le modifiche?» |
| **Prima di implementare** | Promessa in `approved` | Conferma esplicita alla domanda di scrittura |

**Nessun gate alternativo**: issue, PR, Cloud Agent non sostituiscono SDD né regola 0.

---

## Workflow

```
Richiesta (anche «implementa», issue, Cloud Agent)
    ↓
Quale promessa creo, estendo o rompo?
    ↓ Solo cosmetica theme
Regola 0 + implementazione
    ↓ Promessa toccata
Classificare: SYSTEM | PRODUCT | SURFACE
    ↓
Bozza in registry + file promessa (draft) — SENZA codice prodotto
    ↓
approved (accordo esplicito sul contratto)
    ↓
«Vuoi che proceda con le modifiche?» → conferma (regola 0)
    ↓
Implementazione + test mappati agli ID promessa
    ↓
check-spec-sync.sh + verify.sh
    ↓
Post-merge: implemented + registry + CHANGELOG / alpha-pr-registry
```

### Workflow PR

1. Classificare promesse toccate (SYSTEM / PRODUCT / SURFACE).
2. Aggiornare file promessa + [registry.md](./registry.md).
3. Se backend: aggiornare `contracts/schema.md` e/o `contracts/rpc.md`.
4. Implementare; test citano ID promessa.
5. `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh`.
6. PR template: checkbox promesse compilate.

---

## Gate automatico

```bash
bash scripts/check-spec-sync.sh
```

Verifica: registry, promesse PRODUCT/SURFACE/SYSTEM, contratti `contracts/`, coerenza migrazioni.

---

## Riferimenti rapidi

- **Registro**: [registry.md](./registry.md)
- **Catalogo promesse**: [index.md](./index.md)
- **Regole agente**: [`.cursor-rules.md`](../../.cursor-rules.md) § SDD
- **PR**: [`.github/PULL_REQUEST_TEMPLATE.md`](../../.github/PULL_REQUEST_TEMPLATE.md)
