# Glossario — contesto messaging

**Bounded context:** `messaging`  
**Ultima revisione:** 2026-07-19

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
| **Allineamento inbox–chat** | L'anteprima `list_inbox` per un peer è sempre inclusa nella prima finestra di storico (SYS-MAILBOX-057). |

---

## Invarianti

1. Un messaggio logico non appare duplicato in conversazione.
2. Un solo invio attivo per conversazione.
3. Aprendo la conversazione, i messaggi del peer sono considerati letti.
4. Il mittente non riceve errore se il destinatario blocca per allow list — vede solo spunta singola.
