# Rivoluzione Alfred — Discovery Q&A

**Stato**: 🟡 In corso — Iterazione 6 (Alpha, federazione, principio XMPP)  
**Creato**: 2026-06-24  
**Fase**: **Documentazione strategica** — livello alto + roadmap **Alpha** incrementale.

**Glossario**: **Piattaforma** = Supabase.

### Regole di lavoro su questo documento

1. Tu rispondi in modo discorsivo → io formalizzo.
2. Se una risposta **non è chiara**, la **riformulo e la ripresento** (non assumo).
3. **Solo livello alto** adesso — ordine implementazione dettagliato si pianifica più avanti.
4. **Analogia email** usata dove aiuta (Thunderbird, caselle multiple, indirizzi separati).

**Obiettivo**: Documentare l'app **completa** top-down + roadmap **Alpha** incrementale.  
**Regola**: Nessun codice finché non lo dici tu.

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

### Identità verso il mondo esterno — un solo dominio

**Risposta utente**: fuori mi presento come **`me@alfred.im`** — un dominio, non due.

| Concetto | Decisione |
|----------|-----------|
| Dominio federato | **`alfred.im`** — unico |
| Identità esterna | es. `mario@alfred.im` (JID XMPP) — stesso concetto identità Alfred |
| Due domini / due server distinti per protocollo | ❌ **No** — non ha senso nel modello Alfred |
| Matrix fuori | Stesso principio identità Alfred su dominio unico — dettaglio Matrix **da definire** (utente non conosce ancora Matrix) |

**Analogia email**: come avere `mario@alfred.im` come il tuo indirizzo — non due provider con due domini diversi per la stessa persona.

### Principio card — federazione XMPP (fondamentale)

> **Da ricordare sempre.** Principio architetturale vincolante per il bridge XMPP.

Quando il server Alfred comunica con altri server XMPP federati:

1. **Dichiara esplicitamente** tutte le estensioni/XEP che supporta — come farebbe un client XMPP completo verso l'esterno.
2. **Pretende** che il client supporti quelle capability (handshake federato standard).
3. **Internamente**, molte di quelle cose — nel mondo XMPP classico fatte dal **client** — in Alfred sono gestite dalla **piattaforma** (server Alfred).
4. I **server federati esterni non devono sapere** questa divisione client/server. Per loro, Alfred si comporta come un partecipante XMPP normale e capace.

```
Server federato esterno          Bridge XMPP Alfred          Piattaforma
        │                              │                        │
        │  "Supporti XEP-0184?"        │                        │
        │◄────────────────────────────►│  capability complete   │
        │  (vede un peer "client-like")│───────────────────────►│
        │                              │   logica reale qui     │
```

**In sintesi**: **facciata federata** = client XMPP pieno; **implementazione reale** = piattaforma Alfred.

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

**Nota utente**: per ora **si fidano** le due librerie proposte, senza conoscenza approfondita — confermate a livello alto.

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

## Roadmap Alpha (incrementale)

> **Correzione terminologica**: quanto elencato prima non era un "prototipo minimo" ma la **prima versione — Alpha**. Si definisce **a tappe**, non tutta stasera.

### Alpha — prima tappa (definita)

Focus: messaggistica base stile WhatsApp, **compatibile XMPP**.

| Capability | In Alpha v1 |
|------------|-------------|
| **Invio** messaggi | ✅ |
| **Ricezione** messaggi | ✅ |
| **Lettura** / stati lettura (come WhatsApp) | ✅ |
| Compatibilità **XMPP** | ✅ obbligatoria |
| Matrix | ❓ Non definito — utente non conosce ancora Matrix |

**Fuori Alpha v1** (per ora): push, E2EE, dettaglio Matrix.

### Alpha — scope funzionale complessivo (da iterazione precedente)

Oltre alla prima tappa messaggi, l'Alpha nel suo insieme include anche (definizione incrementale — ordine tra queste da pianificare dopo):

- Login piattaforma
- Lista contatti **unificata** (protocollo visibile per contatto)
- Conversazioni + creazione
- Pagina profilo
- XMPP

---

## Applicazione completa — funzionalità (livello alto)

| Area | Funzionalità |
|------|--------------|
| Auth | Login sulla **piattaforma** |
| Contatti | Lista **unificata**; ogni contatto mostra il **protocollo** (XMPP / Matrix) |
| Conversazioni | Vista conversazione + creazione |
| Profilo | Pagina profilo **Alfred** (unico profilo utente — vedi Iterazione 6) |
| Protocollo | XMPP in Alpha; Matrix in architettura — scope Alpha Matrix TBD |

> Oltre Alpha: prodotto finito da continuare a documentare top-down.

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
| E. Protocolli (inbox, contatti, principio card XMPP) | 🟡 |
| F. Brand | ✅ |
| G. Sicurezza (no E2EE; password solo Alfred) | ✅ |
| H. Scope Alpha incrementale | 🟡 |
| I. Legacy web-client | ✅ |
| J. Metriche successo | ⏸️ posticipato |
| K. Push | ❌ non per ora |
| L. Offline | ⏸️ decisione posticipata |

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

## Iterazione 6 — Risposte formalizzate

### Contatti unificati

**Risposta**: lista contatti **unificata** (come l'inbox). Ogni contatto mostra **chiaramente il protocollo** di provenienza (XMPP o Matrix).

**Analogia email**: una rubrica con indirizzi `@gmail.com` e `@alfred.im` insieme — stessa lista, tipo indirizzo visibile.

---

### Federazione esterna — dominio unico

**Risposta**: mi presento fuori come **`me@alfred.im`** — **un solo dominio** `alfred.im`. Non due server o domini diversi per protocollo.

_(Vedi sezione "Identità verso il mondo esterno" in cima.)_

---

### Profilo — domanda riformulata

**La domanda mal posta era**: "profilo Alfred vs vCard XMPP separata?"

**Risposta dedotta dal modello identità**: esiste **un solo profilo** — quello **Alfred**. L'utente non ha vCard XMPP da gestire separatamente; la piattaforma/bridge espone ciò che serve verso l'esterno se richiesto dal protocollo.

**Risposta utente**: non aveva capito la domanda → **confermato implicitamente**: profilo = profilo Alfred.

---

### Push

**Risposta**: **non per ora**.

---

### Offline — spiegazione

**Cosa intendevo**: se senza internet puoi ancora **leggere messaggi vecchi** (cache sul dispositivo, come oggi con IndexedDB) oppure l'app **funziona solo online** collegata alla piattaforma.

**Risposta utente**: non sapeva cosa significasse → **decisione posticipata**. Default probabile per nuovo Alfred: **online-first** via piattaforma; offline da definire in fase 2 documento.

---

### Alpha vs "prototipo minimo" — correzione

**Risposta**: quanto elencato prima era la **prima versione (Alpha)**, non un minimo. Si definisce **incrementalmente**.

**Alpha — prima tappa** (messaggistica):
- Invio, ricezione, lettura messaggi (stile WhatsApp)
- Compatibilità **XMPP** obbligatoria
- **Matrix**: non definito — utente non conosce ancora Matrix

**Principio card XMPP**: documentato in sezione dedicata — facciata federata completa verso fuori, logica reale sulla piattaforma.

---

## Iterazione 7 — Prossimo livello alto (quando vuoi)

1. **Alpha tappa 2+**: dopo messaggi XMPP, cosa viene? (contatti? login? profilo?)
2. **Matrix**: quando sei pronto, stesso scope di XMPP o diverso?
3. **Offline**: dopo la spiegazione, preferenza?
4. **XEP in Alpha**: quali estensioni XMPP oltre messaggi base e read receipts? (MAM, presence, …)

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

**Risposta originale**: posticipato.

**Aggiornamento Iterazione 6**: sostituito da **roadmap Alpha incrementale** (sezione dedicata). Ordine implementazione dettagliato ancora da pianificare tra qualche giorno.

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
| D-020 | 2026-06-24 | Roadmap **Alpha** incrementale (non "minimo prototipo") | ✅ Aggiornato iter.6 |
| D-021 | 2026-06-24 | Ordine sviluppo dettagliato **posticipato** | ✅ |
| D-022 | 2026-06-24 | **Identità Alfred** unica; XMPP/Matrix = trasporto | ✅ |
| D-023 | 2026-06-24 | Password **solo Alfred** | ✅ |
| D-024 | 2026-06-24 | **Multi-account Alfred** (Thunderbird) | ✅ |
| D-025 | 2026-06-24 | Bridge XMPP: **slixmpp** | ✅ Accettata a livello alto |
| D-026 | 2026-06-24 | Bridge Matrix: **matrix-nio** | ✅ Accettata a livello alto |
| D-027 | 2026-06-24 | Contatti **unificati** con protocollo visibile | ✅ |
| D-028 | 2026-06-24 | Federazione esterna: **`@alfred.im`** dominio unico | ✅ |
| D-029 | 2026-06-24 | Profilo = **solo profilo Alfred** | ✅ |
| D-030 | 2026-06-24 | **Push** fuori scope per ora | ✅ |
| D-031 | 2026-06-24 | **Offline** — decisione posticipata | ⏸️ |
| D-032 | 2026-06-24 | **Alpha v1**: invio/ricezione/lettura messaggi, XMPP | ✅ |
| D-033 | 2026-06-24 | **Principio card** federazione XMPP | ✅ Vincolante |

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
- [x] Contatti unificati + protocollo visibile
- [x] Federazione `@alfred.im` unico dominio
- [x] Profilo Alfred unico
- [x] Push escluso per ora
- [x] Alpha v1 definita (messaggi XMPP)
- [x] Principio card XMPP
- [ ] Offline (posticipato)
- [ ] Alpha tappe successive / Matrix
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
| 6 | 2026-06-24 | Contatti unificati; `@alfred.im`; Alpha v1 messaggi; principio card; push no; offline TBD |
| 7 | _prossima_ | Alpha tappe 2+, Matrix, offline, XEP Alpha |
