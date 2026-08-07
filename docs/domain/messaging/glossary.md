# Glossario — contesto messaging

**Bounded context:** `messaging`  
**Ultima revisione:** 2026-08-07

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Conversazione** | Scambio messaggi tra utente corrente e un peer (1:1 o gruppo). |
| **Messaggio** | Unità di contenuto in conversazione: testo, media o posizione. |
| **Invio** | Tentativo di consegnare un messaggio al peer tramite piattaforma. |
| **Messaggio in attesa** | Invio non ancora confermato dal server. |
| **Stato spunte** | Segnale visibile al mittente: accettato, recapitato, letto. |
| **Sincronizzazione** | Aggiornamenti in tempo reale mentre la conversazione è aperta. |
| **Finestra recente** | Primi N messaggi restituiti da `list_peer_messages` senza cursore (= ultimi N cronologici nel mio archivio). |
| **Cursore storico** | `created_at` del messaggio più vecchio già caricato; parametro `p_before_created_at` per la pagina precedente. |
| **Tag mention (`@username`)** | Convenzione testo nel body; rendering client aggiunge link alla chat 1:1 con quel peer. Non persistito come entità separata — vedi PROM-MESSAGE-MENTION. |
| **Fatto di conversazione** | Evento persistito nella conversazione: messaggio, reaction, e in futuro edit/rimozione come nuova riga. Solo `INSERT`; mai `UPDATE` né `DELETE` sullo storico. |
| **Reaction** | Fatto di conversazione: espressione emoji su un messaggio (`MessageReactionFact`), ancorata a `logical_message_id`. Stato corrente derivato dall’ultimo fatto per `(logical_message_id, reactor_id)`. |

---

## Invarianti

1. Un messaggio logico non appare duplicato in conversazione.
2. Un solo invio attivo per conversazione.
3. Aprendo la conversazione, i messaggi del peer sono considerati letti.
4. Il mittente non riceve errore se il destinatario blocca per allow list — vede solo spunta singola.
5. **Append-only conversazione** — ogni fatto di conversazione è immutabile: nuova azione = nuova riga, senza perdita di storico. **Eccezione unica:** le **spunte** (`delivered_at`, `read_at`, `failed_at` sulla copia archivio `messages`) — metadati di recapito aggiornabili in place dal pipeline delivery; non sono fatti di conversazione.
