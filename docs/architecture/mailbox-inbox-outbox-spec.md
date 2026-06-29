# Proposta — modello caselle (direzione)

**Ultima revisione**: 2026-06-28  
**Status**: 📋 **Idea non adottata** — non è su `main`, non è un piano di lavoro  
**Audience**: AI / discussione futura

**Su `main` oggi** vale l’ADR vincolante [address-based-messaging.md](../decisions/address-based-messaging.md) e l’implementazione [messages-only-inbox.md](../implementation/messages-only-inbox.md). Per flussi, RPC, client e schema attuali: [alpha-full-stack.md](./alpha-full-stack.md).

> Se un giorno si adotta questa proposta, **sostituisce** l’ADR message-centric — non lo estende. Fino ad allora **non implementare** nulla da questo file.

---

## Delta rispetto a oggi

| | Oggi (`main`) | Proposta caselle |
|--|---------------|------------------|
| **Archivio messaggio** | 1 riga `messages` condivisa tra Mario e Paolo | 2 archivi (`mailbox_messages`), uno per owner |
| **Consegna internal** | Insert diretto; trigger → `delivered` | **Outbox sempre** (anche internal), poi materializzazione nella casella del destinatario |
| **Inbox** | Query live su `messages` (`list_inbox()`) | Lista delle **tue** caselle verso i peer |

Tutto il resto (UI, realtime, spunte, multi-account, rubrica, tipi messaggio, bridge federato) si **deduce** dall’applicazione attuale e va ripensato al momento della decisione — non è prefigurato qui.

---

## Principi (solo se si adotta)

1. **Nessuna conversazione condivisa** — due caselle indipendenti; analogia email.
2. **Nessun allineamento obbligatorio** tra la casella di Mario e quella di Paolo (ordine, preview, delete).
3. **Solo `author_id`** — niente campo `direction` in/out.
4. **Un solo flusso invio** — internal / xmpp / matrix differiscono solo nel driver di consegna in fondo alla pila.
5. **Delete solo dal proprio lato** — il peer conserva il suo archivio.
6. **Casella = archivio**, non cache di metadati sopra una tabella condivisa: i messaggi vivono nell’archivio dell’owner.

---

## Domande aperte (da chiarire prima di procedere)

- **Quando** ha senso adottarla? (es. bridge reali, delete locale, gruppi, federazione tra istanze — o mai)
- **Alternativa minima**: outbox unificato anche per internal **senza** archivi per owner — basta per unificare il flusso?
- **Migrazione**: doppia scrittura, backfill, rollback — strategia non scelta
- **Identificatore chat lato client**: restare su `peer_profile_id` o passare a `thread_id` nella mia casella
- **Correlazione copie** (spunte, idempotenza consegna): serve un `logical_message_id` dedicato o basta quanto c’è già?
- **Nuovo messaggio dopo delete locale**: riattivare la stessa casella o crearne una nuova
- **Gruppi**: fan-out in outbox, costo storage N×messaggi — accettabile?
- **Driver internal**: stessa transazione del send o job async
- **Schema tabelle, nomi RPC, RLS**: da progettare **dopo** la decisione, non da questo documento

---

## Storico

Idea emersa da sessione design 2026-06-26 (*duplicare cronologia interna per omogeneità col modello federato?*). Il 2026-06-27 su `main` è stato implementato il modello message-centric (PR #130), diverso da questa direzione. Una specifica dettagliata precedente è stata sostituita da questo file per evitare di cristallizzare scelte non ancora prese.

---

## Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [address-based-messaging.md](../decisions/address-based-messaging.md) | Modello **attuale** vincolante |
| [messages-only-inbox.md](../implementation/messages-only-inbox.md) | Implementazione inbox on-read |
| [alpha-full-stack.md](./alpha-full-stack.md) | Architettura Alpha operativa |
| [server-as-reception.md](../decisions/server-as-reception.md) | Spunte (compatibile con entrambi i modelli) |
| [bridge-stateless.md](../decisions/bridge-stateless.md) | Outbox e bridge |
