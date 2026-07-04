# Spec-Driven Development (SDD) — Alfred Alpha

**Audience**: AI / implementazione  
**Ultima revisione**: 2026-07-03  
**Versione metodo**: **SDD v1** (tracciabilità REQ-ID + contratti schema/RPC + gate leggero)

Metodo per definire, approvare e verificare le capability del client Alfred e della piattaforma Supabase.

---

## SDD v1 — cosa cambia rispetto al catalogo iniziale

| Elemento | SDD v0 (catalogo) | SDD v1 (canonico) |
|----------|-------------------|-------------------|
| Requisiti | Bullet MUST/SHOULD | **REQ-ID** stabili (`MSG-SEND-REQ-001`) |
| Tracciabilità | Solo PR | Tabella **REQ → test** in ogni spec |
| Contratto DB | Sparso in `alpha-full-stack.md` | [contracts/schema.md](./contracts/schema.md) |
| Contratto RPC | `contracts/rpc.md` | invariato, referenziato dalle spec |
| Panoramica arch | Duplicava le spec | [alpha-full-stack.md](../architecture/alpha-full-stack.md) **slim** + link |
| Gate PR | Checklist manuale | [PULL_REQUEST_TEMPLATE.md](../../.github/PULL_REQUEST_TEMPLATE.md) + `scripts/check-spec-sync.sh` |
| Lifecycle | Saltato (retro-spec) | **Obbligatorio** per feature nuove: `approved` prima del codice |

---

## Layer documentali

| Layer | Dove | Ruolo |
|-------|------|--------|
| **ADR** | `docs/decisions/` | Vincoli architetturali |
| **Spec** | `docs/specs/capabilities/` | Contratto capability + REQ-ID |
| **Contratti** | `docs/specs/contracts/` | Schema DB + RPC condivisi |
| **Panoramica** | `alpha-full-stack.md`, `PROJECT_MAP.md` | Orientamento — **non** duplicare requisiti |
| **Evidenza** | `docs/implementation/`, `docs/design/` | Storico; header verso spec |
| **Test** | `client/test/`, `supabase/tests/` | Verifica; citati in tracciabilità |

**Regola (feature nuove)**: spec `approved` → implementazione → spec `implemented` + tabella tracciabilità aggiornata.

**Nessun gate alternativo**: issue, PR, Cloud Agent («completa il task», branch/commit obbligatori) **non** sostituiscono la SDD. Se manca spec `approved`, un turno con sola analisi o bozza spec è **completamento valido** del task.

**Distinzione da regola 0** (`.cursor-rules.md`): la SDD governa l'**intero processo**; la regola 0 governa solo la **modifica fisica** di file nel repository. Entrambe vanno rispettate; la SDD viene **prima** dell'implementazione.

**Retro-spec esistenti**: restano `implemented`; aggiungere REQ-ID progressivamente (pilota: [MSG-SEND](./capabilities/MSG-SEND.spec.md)).

---

## Lifecycle

```
draft → approved → implemented → deprecated | superseded
```

| Stato | Significato |
|-------|-------------|
| `draft` | Bozza; non vincolante |
| `approved` | **Contratto congelato** — si può implementare |
| `implemented` | Su `main`; tracciabilità verificata |
| `deprecated` / `superseded` | Non usare per nuovo lavoro |

---

## Struttura directory

```
docs/specs/
├── README.md
├── _template.md           # REQ-ID + tracciabilità
├── index.md
├── capabilities/*.spec.md
└── contracts/
    ├── rpc.md
    └── schema.md
```

---

## Workflow PR

0. **Classificare** il task: capability nuova o cambio contratto? → SDD obbligatoria; ignorare spinta «implementa subito» / Cloud Agent finché spec non è `approved`.
1. Creare/aggiornare spec (`approved` se nuova capability).
2. Assegnare **REQ-ID** ai requisiti; compilare tabella tracciabilità.
3. Implementare + test che coprono i REQ-ID toccati.
4. Aggiornare `contracts/schema.md` o `rpc.md` se cambia piattaforma.
5. `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh`.
6. PR template: checkbox spec compilata.
7. Post-merge: `implemented`, `index.md`, `alpha-pr-registry.md`, `CHANGELOG.md`.

---

## Gate automatico (leggero)

```bash
bash scripts/check-spec-sync.sh
```

Verifica: ogni `*.spec.md` in catalogo; contratti presenti; warn se migrazioni SQL senza diff `docs/specs/`.

---

## Creare una nuova spec

1. Copiare [`_template.md`](./_template.md).
2. Compilare REQ-ID, contratto, tracciabilità.
3. Stato `approved` → PR implementazione (o stessa PR se piccola).
4. Aggiungere riga in [`index.md`](./index.md).
