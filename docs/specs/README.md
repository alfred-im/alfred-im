# Spec-Driven Development (SDD) — Alfred Alpha

**Audience**: AI / implementazione  
**Ultima revisione**: 2026-07-03

Metodo canonico per definire, approvare e verificare le capability del client Alfred e della piattaforma Supabase.

---

## Layer documentali

| Layer | Dove | Ruolo |
|-------|------|--------|
| **ADR** | `docs/decisions/` | Vincoli architetturali immutabili o difficili da cambiare |
| **Spec** | `docs/specs/` | **Contratto** di capability — cosa deve fare il sistema |
| **Implementazione** | `docs/implementation/`, codice | Evidenza di come è stato costruito (può essere storica) |
| **Test** | `client/test/`, `supabase/tests/` | Verifica automatica del contratto |

**Regola**: prima di codice o migrazione su una capability nuova o modificata, esiste una spec in stato `approved` o superiore. Dopo il merge, la spec passa a `implemented`.

`PROJECT_MAP.md` resta la mappa operativa di sessione — **non** sostituisce le spec per-feature.

---

## Lifecycle

```
draft → approved → implemented → deprecated | superseded
```

| Stato | Significato |
|-------|-------------|
| `draft` | Bozza in discussione; **non** vincolante per PR |
| `approved` | Contratto concordato; implementazione autorizzata |
| `implemented` | Su `main`; allineata a codice e test gate |
| `deprecated` | Non usare per nuovo lavoro; rimane per storico |
| `superseded` | Sostituita da un'altra spec (`superseded_by`) |

Transizioni tipiche:

- Nuova capability: `draft` → review → `approved` → merge PR → `implemented`
- Refactor maggiore: nuova spec `approved` → implementazione → vecchia spec → `superseded`
- Target futuro (es. mailbox): resta `approved` finché non su `main`, poi `implemented` e sostituisce la spec message-centric

---

## Struttura directory

```
docs/specs/
├── README.md              # questo file
├── _template.md           # template canonico
├── index.md               # catalogo spec + tracciabilità PR
├── capabilities/          # una spec per capability
│   └── *.spec.md
└── contracts/             # contratti trasversali (RPC, schema)
    └── rpc.md
```

**Naming**: `{CAPABILITY-ID}.spec.md` — ID in maiuscolo con trattino (es. `MSG-INBOX`, `AUTH-MULTI`).

---

## Workflow PR (agenti e umani)

1. Identificare o creare la **spec** (`capabilities/` o aggiornamento `contracts/`).
2. Portare la spec a `approved` (o aggiornare quella `implemented` se il delta è piccolo e documentato).
3. Implementare codice + test allineati al contratto.
4. Aggiornare `index.md`, `alpha-pr-registry.md` (colonna Spec), `CHANGELOG.md`.
5. Marcare la spec `implemented`; doc storica in `implementation/` / `design/` → header «Superseded by SPEC-…».

Checklist post-merge: vedi [alpha-pr-registry.md](../architecture/alpha-pr-registry.md) § checklist.

---

## Relazione con altri documenti

| Documento | Relazione |
|-----------|-----------|
| [mailbox-inbox-outbox-spec.md](../architecture/mailbox-inbox-outbox-spec.md) | Target futuro; quando su `main` diventerà spec capability e sostituirà MSG-INBOX message-centric |
| [alpha-full-stack.md](../architecture/alpha-full-stack.md) | Panoramica; link alle spec, non duplicare contratti |
| `docs/implementation/*` | Evidenza implementativa; header verso spec canonica |
| `docs/decisions/*` | Vincoli referenziati dalle spec, non riscritti |

---

## Creare una nuova spec

1. Copiare [`_template.md`](./_template.md) in `capabilities/{ID}.spec.md`.
2. Compilare metadata, requisiti, contratto, verifica.
3. Aggiungere riga in [`index.md`](./index.md).
4. Aprire PR con spec + implementazione (o spec-only se fase design).
