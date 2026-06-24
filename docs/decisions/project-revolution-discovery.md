# Rivoluzione Alfred — Discovery Q&A

**Stato**: 🟡 In corso — Iterazione 5 (modello identità Alfred; librerie bridge)  
**Creato**: 2026-06-24  
**Fase**: **Prototipo / documentazione strategica** — solo livello alto per ora.  
**Obiettivo**: Documentare l'applicazione **completa** top-down, prima di qualsiasi implementazione.  
**Regola**: Nessun codice finché non lo dici tu. Piano pezzi e ordine sviluppo → **non in questa fase** (si parlerà tra qualche giorno).

**Glossario**: **Piattaforma** = Supabase.

### Regole di lavoro su questo documento

1. Tu rispondi in modo discorsivo → io formalizzo.
2. Se una risposta **non è chiara**, la **riformulo e la ripresento** (non assumo).
3. **Solo livello alto** adesso — niente prototipo minimo, niente ordine di sviluppo, niente dettagli che possono aspettare.

---

## Visione target (formalizzata)

### Sintesi

**Alfred viene riscritto da zero.** Il `web-client/` React **muore del tutto** (tag `legacy/web-client-final` @ `6e792eb`). Nuovo stack: **Flutter Web** + **Piattaforma (Supabase)** + **due bridge Python** (XMPP + Matrix) su **Fly.io**. Inbox unificata, chat separate per protocollo, brand grafico **identico** all'attuale.

**Alfred è un servizio di chat federato**, non un client XMPP/Matrix. L'utente ha un'**identità Alfred**; XMPP e Matrix sono solo **mezzi di comunicazione** verso l'esterno.

### Modello identità (fondamentale — Iterazione 5)

```
Utente
  └── Identità Alfred (piattaforma)     ← unica identità che l'utente conosce
        ├── password Alfred             ← solo login piattaforma
        ├── federazione → XMPP          ← invisibile all'utente (bridge)
        └── federazione → Matrix        ← invisibile all'utente (bridge)
```

| Concetto | Esiste per l'utente? | Note |
|----------|----------------------|------|
| Account / identità **Alfred** | ✅ Sì | Login tramite API piattaforma |
| Password **Alfred** | ✅ Sì | Unica password rilevante per l'utente |
| "Collegare XMPP" / password XMPP | ❌ **No** | Non c'è login protocollo nel prodotto |
| Identità XMPP | ❌ No (concetto utente) | Alfred è federato **verso** XMPP; XMPP è trasporto |
| Identità Matrix | ❌ No (concetto utente) | Stesso ragionamento |

**Formalizzazione**: l'utente **si connette ad Alfred**, non a un server XMPP o Matrix. I bridge espongono l'identità Alfred nel mondo XMPP/Matrix — federazione **in uscita**, non importazione di identità esterne.

> Le domande precedenti su "collegare XMPP" e "password XMPP" erano **mal poste** — basate su un modello client-classico che **non** è Alfred. Ritirate.

### Multi-account (stile Thunderbird)

L'app gestisce **multi-account Alfred**: l'utente può avere **quanti account Alfred vuole** e passare tra loro (come più caselle email in Thunderbird). Ogni account Alfred ha la propria identità e i propri dati sulla piattaforma.

### Architettura target

```
                    ┌─────────────────────────────┐
                    │   Flutter Web (client UI)    │
                    │   brand Alfred invariato     │
                    │   hosting: deploy facile     │
                    └──────────────┬──────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────┐
│                     Piattaforma (Supabase)                    │
│  Auth • Postgres • Realtime • Storage • Edge Functions        │
└───────────────┬──────────────────────────────┬───────────────┘
                │                              │
         sempre attivo                   sempre attivo
                │                              │
                ▼                              ▼
┌───────────────────────────┐    ┌───────────────────────────┐
│  Bridge XMPP (Python)     │    │  Bridge Matrix (Python)   │
│  Fly.io — sempre in run   │    │  Fly.io — sempre in run   │
└─────────────┬─────────────┘    └─────────────┬─────────────┘
              │                                │
              └──────── routing per contatto ──┘
                    (non scelto dall'utente)
```

### Routing: contatti, non server

**Chiarimento utente (Iterazione 4)** — cosa intendi per "server":

| Cosa intendi tu | Formalizzazione |
|-----------------|-----------------|
| I due **bridge** sono sempre attivi | I processi bridge XMPP e Matrix girano **sempre** su Fly.io |
| Non scelgo i server | L'utente **non configura** server XMPP/Matrix nell'UI |
| Scelgo i **contatti** | Se aggiungi un contatto **Matrix** → il messaggio passa dal **bridge Matrix** |
| | Se il contatto è **XMPP** → passa dal **bridge XMPP** |
| | Il protocollo è una proprietà del **contatto/conversazione**, non una scelta esplicita di server |

**L'utente pensa in termini di persone**, non di infrastruttura. I bridge e i server sotto sono trasparenti.

### Ruoli componenti

| Componente | Tecnologia | Ruolo | Deploy |
|------------|------------|-------|--------|
| **Piattaforma** | Supabase | Backend completo; fonte di verità | Supabase Cloud |
| **Bridge XMPP** | Python + **slixmpp** | Sempre attivo; federazione Alfred ↔ rete XMPP | Fly.io |
| **Bridge Matrix** | Python + **matrix-nio** | Sempre attivo; federazione Alfred ↔ rete Matrix | Fly.io |
| **Client** | Flutter Web | UI; parla solo con piattaforma; brand Alfred attuale | Deploy facile (GH Pages ok) |

### Bridge Python — librerie esistenti

I daemon si scrivono in **Python** con librerie mature già disponibili:

| Bridge | Libreria proposta | Perché | Alternativa |
|--------|-------------------|--------|-------------|
| **XMPP** | [**slixmpp**](https://slixmpp.readthedocs.io/) | Asyncio; attiva (2026); plugin XEP; adatta a processi long-running | aioxmpp |
| **Matrix** | [**matrix-nio**](https://matrix-nio.readthedocs.io/) | SDK Matrix Python de facto; async; sync live; bot e bridge | mautrix-python |

**Nota**: senza E2EE nel prototipo, non servono subito `matrix-nio[e2e]` né OMEMO su XMPP.

I bridge ascoltano rete protocollo **e** piattaforma; normalizzano eventi; leggono/scrivono su Supabase. La logica Alfred resta sulla piattaforma.

### Repository

**Monorepo** in questo repository, **tre cartelle** (proposta accettata):

```
/workspace/
├── client/          # Flutter Web
├── bridge-xmpp/     # Bridge Python XMPP
├── bridge-matrix/   # Bridge Python Matrix
└── supabase/        # Schema, migrazioni, edge functions
```

Un solo repo — nessuna repo separata per ora.

### Brand

**Identico** al Alfred attuale dal punto di vista grafico: colore `#2D2926`, spunta, stile UI esistente. Il rewrite Flutter **riproduce** il look, non lo reinventa.

---

## Applicazione completa — funzionalità (livello alto)

> **Nota**: questo è lo **scope dell'app intera**, non un "prototipo minimo". Lo sviluppo sarà a pezzi, ma il documento descrive il prodotto finito a livello strategico.

| Area | Funzionalità |
|------|--------------|
| Auth | Login sulla **piattaforma** |
| Contatti | Lista contatti |
| Conversazioni | Vista conversazione + **creazione** nuova conversazione |
| Profilo | Pagina profilo |
| Protocollo | **XMPP** (Matrix nell'architettura generale; dettaglio feature Matrix — da approfondire a livello alto) |

---

## Workflow concordato

| Fase | Cosa | Stato | Quando |
|------|------|-------|--------|
| 1. Discovery alto livello | Questo documento | 🟡 **In corso** | Adesso |
| 2. Architettura dettagliata | Schema dati, flussi, API — sempre documento | ⬜ | Dopo |
| 3. Piano implementazione a pezzi | Ordine sviluppo, milestone | ⏸️ **Posticipato** | Tra qualche giorno |
| 4. Codice | Implementazione | ⏸️ | Su tuo comando esplicito |

---

## Aree — stato

| Area | Stato |
|------|-------|
| A. Visione | ✅ |
| B. Prodotto (Flutter Web) | ✅ |
| C. Architettura macro | 🟡 — schema dati / API da documentare |
| D. Infra (Fly bridge, GH Pages web, monorepo) | ✅ |
| E. Protocolli (inbox unica, chat separate, routing per contatto) | 🟡 |
| F. Brand | ✅ |
| G. Sicurezza (no E2EE; password solo Alfred) | ✅ |
| H. Scope funzionale alto livello | 🟡 |
| I. Legacy web-client | ✅ |
| J. Metriche successo | ⏸️ posticipato |

---

## Iterazione 5 — Risposte formalizzate

### L2b / Multi-account

**Domanda originale** (ritirata): "più account XMPP?" — **non pertinente**.

**Risposta utente**: Sì al **multi-account Alfred** — quanti account vuole, come più email in Thunderbird. L'app **deve** gestirlo.

---

### G2 / L2 — Identità e password (chiarimento concettuale)

**Domande originali** (ritirate): "collegare XMPP", "password XMPP" — **concetto sbagliato**.

**Risposta utente**:
- Alfred = **servizio di chat federato**
- Password = **solo Alfred** (piattaforma)
- Login = **solo API piattaforma**
- **Nessuna** identità XMPP lato utente; XMPP/Matrix = **metodo di comunicazione** col mondo esterno
- Esiste **identità Alfred**, federata verso XMPP e Matrix

---

### Librerie Python bridge

**Risposta utente**: i daemon in Python con **librerie esistenti** — ricercate e proposte sopra (slixmpp + matrix-nio).

---

## Iterazione 6 — Prossimo livello alto (quando vuoi)

Domande **solo strategiche**:

1. **Contatti**: lista contatti **unificata** (XMPP + Matrix insieme) come l'inbox?
2. **Federazione Alfred**: come appare l'identità Alfred nel mondo esterno? (es. `utente@alfred.im` su XMPP, `@utente:alfred.matrix` su Matrix — da definire)
3. **Profilo**: il profilo in UI è **solo profilo Alfred** (niente vCard XMPP separata per l'utente)?
4. **Notifiche push**: servono nel nuovo Alfred o dopo?
5. **Offline**: cache locale come oggi, o solo online via piattaforma?

---

## Iterazione 4 — Risposte (storico)

### L3 (correzione). Bridge sempre attivi; routing per contatto

**Risposta utente**: I bridge sono **sempre attivi**. Non scelgo server — scelgo **contatti**. Contatto Matrix → bridge Matrix; altrimenti bridge XMPP.

**Sostituisce** la formulazione precedente che legava l'attivazione bridge all'aggiunta account utente. I bridge sono **servizi permanenti**; il percorso del messaggio dipende dal **protocollo del contatto/conversazione**.

---

### D4. Repository

**Risposta**: **Monorepo unico**, cartelle separate per client / bridge-xmpp / bridge-matrix / supabase. Per l'utente va bene così; repo separate solo se servissero e fossero da creare.

**Raccomandazione**: monorepo — coerente con fase prototipo e singolo team.

---

### F1. Brand

**Risposta**: Brand Alfred **attuale**, **identico** graficamente.

---

### P1 / P2. Prototipo minimo e ordine pezzi

**Risposta**: **Non si discute ora.** Non c'è un "prototipo minimo" da definire in questa fase. Si documenta l'app **intera** top-down; lo sviluppo a pezzi si pianifica **più avanti** (non stasera).

- P1 → ⏸️ posticipato
- P2 → ⏸️ posticipato

---

## Domande ritirate (modello errato)

Le seguenti domande erano basate sull'assunzione "client XMPP classico" e sono **annullate**:

- ~~L2b: più account XMPP?~~ → sostituita da **multi-account Alfred**
- ~~G2: password XMPP?~~ → **non esiste**; solo password Alfred
- ~~L2: collegare identità XMPP dopo login?~~ → **non esiste** identità XMPP utente

---

## Log decisioni

| # | Data | Decisione | Stato |
|---|------|-----------|-------|
| D-001 | 2026-06-24 | Riscrittura completa | ✅ |
| D-002 | 2026-06-24 | Client Flutter Web | ✅ |
| D-003 | 2026-06-24 | Piattaforma = Supabase (backend completo) | ✅ |
| D-004 | 2026-06-24 | Due bridge Python (XMPP + Matrix) | ✅ |
| D-005 | 2026-06-24 | Bridge su Fly.io | ✅ |
| D-006 | 2026-06-24 | Bridge = adattatori, non server protocollo | ✅ |
| D-007 | 2026-06-24 | Inbox unificata | ✅ |
| D-008 | 2026-06-24 | Flutter → solo piattaforma | ✅ |
| D-009 | 2026-06-24 | Documento top-down prima del codice | ✅ |
| D-010 | 2026-06-24 | web-client React eliminato | ✅ |
| D-011 | 2026-06-24 | Web hosting = deploy facile (GH Pages ok) | ✅ |
| D-012 | 2026-06-24 | Tag `legacy/web-client-final` @ `6e792eb` | ✅ |
| D-013 | 2026-06-24 | Chat separate in inbox (no associazione cross-protocollo) | ✅ |
| D-014 | 2026-06-24 | Login solo piattaforma | ✅ |
| D-015 | 2026-06-24 | ~~Bridge attivi per account aggiunti~~ → **Bridge sempre attivi; routing per contatto** | ✅ Corretto iter.4 |
| D-016 | 2026-06-24 | No E2EE | ✅ |
| D-017 | 2026-06-24 | Fase prototipo — infra non bloccante | ✅ |
| D-018 | 2026-06-24 | **Monorepo** con cartelle client / bridge-xmpp / bridge-matrix / supabase | ✅ |
| D-019 | 2026-06-24 | Brand grafico **identico** all'Alfred attuale | ✅ |
| D-020 | 2026-06-24 | Scope = **app completa** documentata; no "minimo prototipo" ora | ✅ |
| D-021 | 2026-06-24 | Piano pezzi e ordine sviluppo **posticipati** | ✅ |
| D-022 | 2026-06-24 | **Identità Alfred** unica; XMPP/Matrix = trasporto federato | ✅ |
| D-023 | 2026-06-24 | Password **solo Alfred**; nessun login/collegamento protocollo utente | ✅ |
| D-024 | 2026-06-24 | **Multi-account Alfred** (stile Thunderbird) | ✅ |
| D-025 | 2026-06-24 | Bridge XMPP: libreria **slixmpp** | 🟡 Proposta alto livello |
| D-026 | 2026-06-24 | Bridge Matrix: libreria **matrix-nio** | 🟡 Proposta alto livello |

---

## Checklist chiusura fase alto livello

- [x] Architettura macro (client / piattaforma / bridge)
- [x] Routing per contatto, bridge sempre attivi
- [x] Inbox e chat separate
- [x] Login piattaforma
- [x] Monorepo
- [x] Brand invariato
- [x] Funzionalità app a livello alto (login, contatti, chat, creazione, profilo, XMPP)
- [x] Modello identità Alfred (no identità XMPP utente)
- [x] Multi-account Alfred
- [x] Librerie bridge Python (proposta)
- [ ] Iterazione 6: contatti, federazione esterna, profilo, push, offline
- [ ] Schema dati e flussi (fase 2 documento)
- [ ] Brief alto livello approvato ("ok, il livello alto è completo")

---

## Cronologia iterazioni

| Iterazione | Data | Sintesi |
|------------|------|---------|
| 0–1 | 2026-06-24 | Visione stack; formalizzazione iniziale |
| 2 | 2026-06-24 | Ruoli Supabase/bridge; Flutter Web; workflow |
| 3 | 2026-06-24 | Inbox; login piattaforma; no E2EE; hosting facile |
| 4 | 2026-06-24 | Bridge sempre attivi; routing contatti; monorepo; brand |
| 5 | 2026-06-24 | Identità Alfred federata; multi-account; no password XMPP; librerie slixmpp + matrix-nio |
| 6 | _prossima_ | Federazione esterna, contatti, profilo, push, offline |
