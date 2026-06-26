# Ricezione = ricezione sul server (client cloud)

**Data**: 2026-06-26  
**Status**: ✅ Accettata — **concept vincolante** dell'applicazione  
**Categoria**: Messaggistica, spunte, modello cloud  
**Correlata**: [bridge-stateless.md](./bridge-stateless.md), [alpha-full-stack.md](../architecture/alpha-full-stack.md) §2.9

---

## Concept

Per un **client nel cloud** come Alfred — accesso **multidispositivo**, **fonte di verità sul server** (Supabase) — la **ricezione** di un messaggio coincide con la **ricezione sul server**, non con l'arrivo su un singolo device del destinatario.

Questo è il modello semantico dell'applicazione: il server è il punto in cui un messaggio è considerato «arrivato» nel sistema Alfred.

---

## Oggi vs domani

| Fase | Comportamento |
|------|----------------|
| **Oggi (Alpha interna)** | Invio e ricezione *sembrano* coincidenti: il mittente chiama `send_message`, il messaggio è subito nel DB piattaforma, il destinatario lo vede via Realtime. Il passaggio «consegnato» può avvenire nello stesso istante dell'inserimento. |
| **Domani (federazione / bridge)** | Invio e ricezione saranno **disaccoppiati**, come già accade tra server diversi in XMPP/Matrix: il messaggio resta `sent` o `pending` finché il bridge non lo consegna all'altro dominio; solo allora diventa «ricevuto» (sul server di destinazione o nella piattaforma come ack federato). |

Il disaccoppiamento non è un'eccezione futura: è la **stessa logica** del caso federato, applicata progressivamente anche ai flussi che oggi appaiono sincroni.

---

## Implicazioni per le spunte (3 livelli WhatsApp)

| Livello | UI | Significato nel modello cloud Alfred |
|---------|-----|--------------------------------------|
| **1 — Inviato** | ✓ grigia | Il messaggio è stato accettato dalla piattaforma (RPC `send_message` / outbox `queued` per federato). |
| **2 — Consegnato** | ✓✓ grigie | Il messaggio è **ricevuto sul server** — cioè disponibile nella fonte di verità per il destinatario (inserimento DB interno, oppure ack bridge/XEP-0184 per federato). **Non** significa «aperto sul telefono del destinatario». |
| **3 — Lettura** | ✓✓ blu | Il destinatario ha **visualizzato** la conversazione (`mark_conversation_read` / XEP-0333 `displayed`). |

### Differenza rispetto al client legacy XMPP diretto

Nel client React legacy (XMPP sul device), il livello 2 seguiva **XEP-0184**: consegnato = arrivato sul **device** del peer.

Nel client cloud Alfred, il livello 2 segue il **server come fonte di verità**: consegnato = ricevuto **nella piattaforma** (o nel server federato di destinazione tramite bridge). Il multidispositivo è coerente: tutti i device del destinatario leggono lo stesso stato dal server; non serve un ack per-device per la spunta grigia doppia.

---

## Conseguenze implementative

1. **`delivery_status = 'delivered'`** va impostato quando il messaggio è persistito/recapitato nella fonte di verità rilevante (trigger post-insert per chat interna; callback bridge per federato) — **non** quando il client del destinatario riceve un evento Realtime.
2. **`delivery_status = 'read'`** resta legato all'azione esplicita di lettura (`mark_conversation_read`), indipendente dal disaccoppiamento invio/ricezione.
3. **Outbox e bridge**: per `protocol in ('xmpp', 'matrix')` il messaggio può restare `pending`/`sent` fino a conferma bridge — il disaccoppiamento è già previsto nello schema (`outbox`, `bridge_jobs`).
4. **Non confondere** con WhatsApp mobile P2P: Alfred è cloud-first; la semantica delle spunte riflette il server, non la singola sessione WebSocket del peer.

---

## Riferimenti

- [alpha-full-stack.md](../architecture/alpha-full-stack.md) — §2.9 Spunte lettura
- [message-states.md](../architecture/message-states.md) — policy legacy XMPP (livello 2 = device); **non** applicare tale semantica al client Flutter Alpha senza adattamento
- `supabase/migrations/*` — enum `message_delivery_status`, RPC `send_message`, `mark_conversation_read`
