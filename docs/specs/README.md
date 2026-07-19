# Spec-Driven Development (SDD) — Alfred

**Audience**: AI / implementazione  
**Ultima revisione**: 2026-07-19  
**Versione metodo**: SDD — registro promesse prodotto

Alfred è software stabile: la SDD governa **ciò che il prodotto promette** all'utente — schema, RPC, comportamento riusabile e binding per superficie.

**Il centro del processo ingegneristico è il modello** (dominio → UML → statechart → codice). Vedi [docs/domain/README.md](../domain/README.md). La SDD **non duplica** il modello: registra solo il **confine osservabile** verso l'utente, con riferimenti a comandi/stati UML quando serve.

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
├── registry.md               # Catalogo unico promesse + stato
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
| **Modello** | `docs/domain/`, `docs/model/uml/`, `client/lib/machines/` | Rappresentazione astratta — **centro ingegneristico** |
| **Ingresso pubblico** | `README.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md` | GitHub — panoramica, sicurezza, community |
| **ADR** | `docs/decisions/` | Perché architetturale |
| **Promesse** | `promises/`, `surfaces/`, `contracts/`, `registry.md` | Confine prodotto — cosa l'utente osserva |
| **Panoramica** | `PROJECT_MAP.md`, `full-stack.md` | Orientamento |
| **Guide** | `docs/guides/` | Dettaglio operativo post-implementazione |
| **Cronologia** | `CHANGELOG.md` | Merge e revisioni |
| **Test** | `client/test/`, `supabase/tests/` | Verifica; citati in tracciabilità |

### SDD e modello (non duplicare)

| Cambio | Modello | SDD |
|--------|---------|-----|
| Refactor interno, utente non vede | dominio + UML (+ statechart) | no |
| Comportamento osservabile | dominio + UML (+ statechart) | amend `PROM-*` / `SURF-*` / `SYS-*` |
| Solo theme | no | no |

Nelle promesse PRODUCT: sezione **Modello (riferimento)** verso dominio/UML/statechart; **non** sezione «Contratto implementativo» (dettaglio in `docs/domain/<context>/README.md` e `docs/guides/`). Nelle promesse: **riferire** comandi/eventi/stati del modello (es. `OpenFromPushTap` → `seq-notification-click.puml`), non riscrivere flussi in prosa.

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
Quale bounded context?  → vedi docs/domain/bounded-contexts.md
    ↓
Solo cosmetica theme / refactor 1:1?
    ↓ No
Aggiornare dominio + UML (+ statechart se UI) — vedi docs/domain/README.md
    ↓
Quale promessa creo, estendo o rompo?  (solo se utente osserva)
    ↓ Promessa toccata
Classificare: SYSTEM | PRODUCT | SURFACE → draft → approved
    ↓
«Vuoi che proceda con le modifiche?» → conferma (regola 0)
    ↓
Implementazione + test (transizioni modello + ID promessa)
    ↓
check-spec-sync.sh + verify.sh
    ↓
Post-merge: implemented + registry + CHANGELOG (+ hub sotto)
```

### Workflow PR

1. Classificare promesse toccate (SYSTEM / PRODUCT / SURFACE).
2. Aggiornare file promessa + [registry.md](./registry.md).
3. Se backend: aggiornare `contracts/schema.md` e/o `contracts/rpc.md`.
4. Implementare; test citano ID promessa.
5. `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh`.
6. PR template: checkbox promesse compilate.

### Checklist allineamento doc (post-merge su `main`)

1. **`README.md`** — se cambia posizionamento pubblico, getting started o community policy
2. **`PROJECT_MAP.md`** — stato corrente
3. **`CHANGELOG.md`** — voce in `[Unreleased]`
4. **`docs/specs/`** — [registry.md](./registry.md) (`approved` → `implemented`); `contracts/` se SYSTEM
5. **`docs/architecture/full-stack.md`** — sezione interessata
6. **`docs/INDICE.md`** — nuove guide o promesse
7. **`client/README.md`** — se cambia toolchain client
8. **`docs/guides/`** — nuova guida operativa se serve dettaglio implementativo
9. **`scripts/check-spec-sync.sh`** — se toccate spec o migrazioni

---

## Gate automatico

```bash
bash scripts/check-spec-sync.sh
```

Verifica: registry, promesse PRODUCT/SURFACE/SYSTEM, contratti `contracts/`, coerenza migrazioni.

---

## Riferimenti rapidi

- **Modello**: [docs/domain/README.md](../domain/README.md) · [docs/model/uml/README.md](../model/uml/README.md)
- **Registro**: [registry.md](./registry.md)
- **Navigazione**: [INDICE.md](../INDICE.md)
- **Regole agente**: [`.cursor-rules.md`](../../.cursor-rules.md) § SDD · § Modello
- **PR**: [`.github/PULL_REQUEST_TEMPLATE.md`](../../.github/PULL_REQUEST_TEMPLATE.md)
