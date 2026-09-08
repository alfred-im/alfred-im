# Ricezione = ricezione sul server (client cloud)

> **SSOT semantica spunte UI** (cosa significa ✓ / ✓✓ / blu per l'utente). **Meccanica** delivery/worker: [mailbox-inbox-outbox-spec.md](../architecture/mailbox-inbox-outbox-spec.md) — non duplicare qui.

> **Contratto promessa**: [SYS-MAILBOX.md](../specs/promises/system/SYS-MAILBOX.md)

**Data**: 2026-08-08  
**Status**: ✅ Accettata — **concept vincolante** dell'applicazione  
**Categoria**: Messaggistica, spunte, modello cloud  
**Correlata**: [gotham-protocol.md](../architecture/gotham-protocol.md), [SSOT.md](../SSOT.md)

---

## Concept

Per un **client nel cloud** come Alfred — accesso **multidispositivo**, **fonte di verità sul server** (Supabase) — la **ricezione** di un messaggio coincide con la **ricezione sul server**, non con l'arrivo su un singolo device del destinatario.

Questo è il modello semantico dell'applicazione: il server è il punto in cui un messaggio è considerato «arrivato» nel sistema Alfred.

---

## Oggi vs domani

| Fase | Comportamento |
|------|----------------|
| **Oggi (scope attuale)** | RPC account scrive copia mittente + outbox; worker `alfred_delivery.process_outbox` (stessa transazione su recapito locale, #179) materializza destinatario e `delivered_at`/`read_at` mittente. Il destinatario vede messaggi via Realtime sulla propria copia. Gate allow list nel worker — rifiuto silenzioso se mittente non in lista. |
| **Domani (federazione)** | Invio e ricezione restano **disaccoppiati** tra istanze: il messaggio verso `user@server` resta in outbox `queued` finché il worker federativo non lo recapita sul peer; solo allora il mittente raggiunge il livello 2 (consegnato). |

Il disaccoppiamento non è un'eccezione futura: è la **stessa logica** del caso federato, applicata progressivamente anche ai flussi che oggi appaiono sincroni.

---

## Implicazioni per le spunte (3 livelli WhatsApp)

| Livello | UI | Significato nel modello cloud Alfred |
|---------|-----|--------------------------------------|
| **1 — Inviato** | ✓ grigia | Il messaggio è stato accettato dalla piattaforma (RPC `send_message_to_profile` / outbox `queued` per federato). |
| **2 — Consegnato** | ✓✓ grigie | Il messaggio è **ricevuto sul server del destinatario** — disponibile nella fonte di verità per il destinatario (copia nel suo archivio Alfred, oppure ack HTTP dal peer remoto). **Non** significa «aperto sul telefono del destinatario». Se il gate allow list rifiuta il recapito, il mittente resta al livello 1 in modo permanente e silenzioso. |
| **3 — Lettura** | ✓✓ blu | Il destinatario ha **visualizzato** la conversazione (`mark_peer_read` / evento READ federato). |

Nel client cloud Alfred il livello 2 segue il **server come fonte di verità**: consegnato = ricevuto **nella piattaforma** (o nel server dell'altra istanza). Il multidispositivo è coerente: tutti i device del destinatario leggono lo stesso stato dal server.

---

## Conseguenze implementative

1. **`delivered_at`** quando il messaggio è persistito nella fonte di verità rilevante — **non** quando il client del destinatario riceve Realtime. Meccanismo: worker locale (`alfred_delivery`) o worker federativo — [SYS-DELIVERY](../specs/promises/system/SYS-DELIVERY.md).
2. **`read_at`** legato a `mark_peer_read` / evento READ federato.
3. **Outbox**: recapito federato può restare `queued` fino ad ack HTTP peer — non definisce una chat separata ([no-internal-external-chat-distinction.md](./no-internal-external-chat-distinction.md)).
4. **Non confondere** con WhatsApp mobile P2P: Alfred è cloud-first; la semantica delle spunte riflette il server, non la singola sessione WebSocket del peer.
5. **Allow list ricezione** ([SYS-RECEPTION.md](../specs/promises/system/SYS-RECEPTION.md), [PROM-RECEPTION-FILTER.md](../specs/promises/product/PROM-RECEPTION-FILTER.md), [SURF-ALLOWLIST.md](../specs/surfaces/SURF-ALLOWLIST.md)): livello 1 (✓) si ottiene sempre con RPC accettata e copia mittente; livello 2 richiede recapito nel archivio destinatario — il blocco silenzioso lascia il mittente al solo livello 1.

---

## Riferimenti

- [full-stack.md](../architecture/full-stack.md) — architettura client; [PROM-MESSAGE-STATUS](../specs/promises/product/PROM-MESSAGE-STATUS.md) spunte
- [no-internal-external-chat-distinction.md](./no-internal-external-chat-distinction.md) — regola vincolante: nessuna distinzione chat locale/federata a nessun livello
