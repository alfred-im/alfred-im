# {TITLE}

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-{NAME}` |
| **Classe** | PRODUCT |
| **Ultima revisione** | YYYY-MM-DD |
| **Superseded by** | `PROM-…` / `SURF-…` (se applicabile) |

Promessa di prodotto **riusabile** su più superfici. Le superfici referenziano questo file; non duplicano le regole.

---

## 1. Problema / obiettivo

…

---

## 2. Promesse

Ogni promessa vincolante: `PROM-{NAME}-NNN`.

### MUST

| ID | Promessa |
|----|----------|
| `PROM-{NAME}-001` | … |

### SHOULD

| ID | Promessa |
|----|----------|
| `PROM-{NAME}-0xx` | … |

### MUST NOT

| ID | Promessa |
|----|----------|
| `PROM-{NAME}-0xx` | … |

---

## 3. Modello (riferimento)

| Elemento | Artefatto |
|----------|-----------|
| Glossario / comandi | [docs/domain/<context>/](../../../domain/<context>/) |
| UML | [docs/model/uml/<context>/](../../../model/uml/<context>/) |
| Statechart client | [client/lib/machines/<context>/](../../../../client/lib/machines/<context>/) (se applicabile) |

**Implementazione (non vincolante):** [docs/domain/<context>/README.md](../../../domain/<context>/README.md) · guide operative se presenti.

---

## 4. Superfici conformi

| Superficie | Stato | File |
|------------|-------|------|
| SURF-… | `draft` \| `approved` \| `implemented` | [SURF-….md](../../surfaces/SURF-….md) |

---

## 5. Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| `PROM-{NAME}-001` | `client/test/…` o scenario manuale |

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [registry.md](./registry.md) (da `promises/product/`: `../../registry.md`) | Indice promesse |

Lo stato lifecycle si aggiorna **solo** in [docs/specs/registry.md](./registry.md) (colonna Stato). Il file non ha campo Status.

> **Path:** questo template va in `docs/specs/promises/product/` — usare `../../../` per `domain/` e `model/`; `../../../../` per `client/` (da `promises/product/`).
