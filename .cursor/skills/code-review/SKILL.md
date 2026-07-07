---
name: code-review
description: "Use when the user asks for a full or planned code review. Triggers: review all code, progettare una revisione, audit del codebase, design-first or spec-first review."
metadata:
  version: "1.0.0"
---

# Revisione codice

## Quando applicare

L'utente chiede una revisione del codice — in particolare una revisione ampia da **progettare** prima di eseguirla.

## Workflow

### 1. Piano di revisione (prima di tutto)

Scrivi un piano di revisione e comunicalo all'utente. Il piano include:

- **Scopo** — cosa si revisiona
- **Perimetro** — aree / moduli / layer coinvolti
- **Assi** — design-first e spec-first (vedi sotto)
- **Sub-agenti** — quali lanciare, su quale perimetro, in parallelo dove possibile
- **Verifica** — quali documenti e quali test userai per validare i risultati
- **Deliverable** — formato del report finale

Poi esegui il piano — non fermarti alla bozza.

### 2. Sub-agenti

Usa i sub-agenti per massimizzare l'efficacia:

- Suddividi il codebase per aree indipendenti
- Lancia sub-agenti **in parallelo** quando le aree non si sovrappongono
- Ogni sub-agente riceve: perimetro, cosa cercare, formato dell'output atteso
- L'agente principale aggrega e deduplica i risultati

### 3. Design-first e spec-first

**Design-first** — prima dell'implementazione fine:

- Architettura, responsabilità, accoppiamento, flussi dati
- Coerenza strutturale del sistema
- Problemi di design prima dei bug locali

**Spec-first** — contratti e intenzione prima del codice:

- Documentazione di prodotto, spec, contratti, ADR dove esistono
- Confronto tra quanto dichiarato e quanto implementato
- Gap, violazioni, ambiguità tra spec e codice

### 4. Verifica con documentazione e test

Ogni conclusione rilevante va supportata da evidenza:

- **Documentazione** — spec, architettura, README tecnici, contratti
- **Test** — esegui i test pertinenti al perimetro revisionato; riporta pass/fail e cosa coprono

Distingui ciò che è verificato da test da ciò che resta analisi statica.

### 5. Comunicazione

Tieni l'utente informato lungo tutto il flusso:

- Piano all'inizio
- Sintesi dei risultati alla fine
- Eventuali criticità emerse, nel report

Non serve chiedere conferme intermedie se la richiesta è già chiara.

## Report finale

- Sintesi esecutiva
- Findings per severità (critico → informativo)
- Esito design-first (architettura, coerenza strutturale)
- Esito spec-first (allineamento documentazione ↔ codice)
- Esito verifiche (documenti consultati, test eseguiti)
- Raccomandazioni e prossimi passi
