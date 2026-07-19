---
name: code-review
description: "DEPRECATED — non usare. Vedi .cursor-rules.md (Modello, SDD, Revisione completa, Analisi architetturale)."
metadata:
  version: "1.0.0"
  status: deprecated
  deprecated: "2026-07-19"
  superseded_by:
    - ".cursor-rules.md § Modello (DDD + UML + Statechart)"
    - ".cursor-rules.md § Spec-Driven Development (SDD)"
    - ".cursor-rules.md § Revisione completa del codice"
    - ".cursor-rules.md § Analisi Architetturale"
  reason: "Assi design-first/spec-first obsoleti rispetto al metodo modello-centrico (dominio → UML → statechart → codice) adottato 2026-07-18."
---

# Revisione codice — DEPRECATA

> **Non attivare questa skill.** Sostituita dalle regole in [`.cursor-rules.md`](../../../.cursor-rules.md).

## Perché è deprecata

Aggiunta il 2026-07-07, prima dell'adozione del **modello** come centro ingegneristico (2026-07-18). Propone due assi (design-first, spec-first generico) senza:

- allineamento **dominio → UML → statechart → codice** per bounded context;
- registro promesse SDD v2 (`PROM-*` / `SURF-*` / `SYS-*`, `registry.md`);
- gate `check-model-sync.sh` e `check-spec-sync.sh`.

Un audit guidato da questa skill può trovare problemi nel codice ma **non** drift del modello o delle promesse.

## Cosa usare al suo posto

| Esigenza | Dove |
|----------|------|
| Revisione prima di modificare un file | `.cursor-rules.md` § Revisione completa del codice |
| Architettura, accoppiamento, efficienza | `.cursor-rules.md` § Analisi Architetturale + `PROJECT_MAP.md` |
| Allineamento dominio / UML / macchine | `.cursor-rules.md` § Modello + `docs/domain/README.md` |
| Promesse prodotto vs implementazione | `.cursor-rules.md` § SDD + `docs/specs/README.md` |

## Contenuto storico (v1.0.0 — non seguire)

<details>
<summary>Testo originale conservato per riferimento</summary>

### Quando applicare

L'utente chiede una revisione del codice — in particolare una revisione ampia da **progettare** prima di eseguirla.

### Workflow

#### 1. Piano di revisione (prima di tutto)

Scrivi un piano di revisione e comunicalo all'utente. Il piano include:

- **Scopo** — cosa si revisiona
- **Perimetro** — aree / moduli / layer coinvolti
- **Assi** — design-first e spec-first (vedi sotto)
- **Sub-agenti** — quali lanciare, su quale perimetro, in parallelo dove possibile
- **Verifica** — quali documenti e quali test userai per validare i risultati
- **Deliverable** — formato del report finale

Poi esegui il piano — non fermarti alla bozza.

#### 2. Sub-agenti

Usa i sub-agenti per massimizzare l'efficacia:

- Suddividi il codebase per aree indipendenti
- Lancia sub-agenti **in parallelo** quando le aree non si sovrappongono
- Ogni sub-agente riceve: perimetro, cosa cercare, formato dell'output atteso
- L'agente principale aggrega e deduplica i risultati

#### 3. Design-first e spec-first

**Design-first** — prima dell'implementazione fine:

- Architettura, responsabilità, accoppiamento, flussi dati
- Coerenza strutturale del sistema
- Problemi di design prima dei bug locali

**Spec-first** — contratti e intenzione prima del codice:

- Documentazione di prodotto, spec, contratti, ADR dove esistono
- Confronto tra quanto dichiarato e quanto implementato
- Gap, violazioni, ambiguità tra spec e codice

#### 4. Verifica con documentazione e test

Ogni conclusione rilevante va supportata da evidenza:

- **Documentazione** — spec, architettura, README tecnici, contratti
- **Test** — esegui i test pertinenti al perimetro revisionato; riporta pass/fail e cosa coprono

Distingui ciò che è verificato da test da ciò che resta analisi statica.

#### 5. Comunicazione

Tieni l'utente informato lungo tutto il flusso:

- Piano all'inizio
- Sintesi dei risultati alla fine
- Eventuali criticità emerse, nel report

Non serve chiedere conferme intermedie se la richiesta è già chiara.

### Report finale

- Sintesi esecutiva
- Findings per severità (critico → informativo)
- Esito design-first (architettura, coerenza strutturale)
- Esito spec-first (allineamento documentazione ↔ codice)
- Esito verifiche (documenti consultati, test eseguiti)
- Raccomandazioni e prossimi passi

</details>
