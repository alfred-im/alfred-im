# Glossario — contesto groups

**Bounded context:** `groups`  
**Ultima revisione:** 2026-07-19  
**Promesse SDD:** [SYS-GROUP](../../specs/promises/system/SYS-GROUP.md), [SYS-DELIVERY](../../specs/promises/system/SYS-DELIVERY.md)

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Group account** | Profilo Alfred di tipo gruppo; identità `@username` come qualsiasi account. |
| **Participation** | Consenso bidirezionale su allow list: gruppo consente persona **e** persona consente gruppo — nessuna tabella membership. |
| **Group archive** | Storico unico messaggi con owner = gruppo, ordinato per data creazione. |
| **Group shell** | Layout client senza inbox classica: home gruppo + singola conversazione gruppo. |
| **Broadcast** | Invio dal gruppo verso tutti i partecipanti allow list; una riga archivio gruppo + fan-out worker. |
| **Erogazione** | Worker inserisce copie proxy su archivi partecipanti dopo recapito al gruppo o broadcast. |
| **Original author** | Chi ha scritto il contenuto; valorizzato in tutti i flussi gruppo. |
| **Technical sender** | Mittente tecnico della riga: umano su storico gruppo; **gruppo** su copie erogate verso partecipanti. |
| **Group active author** | Riepilogo home: profilo + conteggio messaggi per autore umano nello storico (escluso il gruppo). |
| **Conversation tile** | Unica voce chat in home gruppo: anteprima ultimo messaggio dello storico. |
| **Human → group** | Utente invia a gruppo; stessa pipeline mailbox + outbox deliver. |
| **Group → allow list** | Broadcast o erogazione automatica post-recapito. |
| **Author labels** | UI mostra header autore da original author su messaggi gruppo. |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **messaging** | Chat umano→gruppo usa stessa pipeline invio; UI autore in bolla. |
| **delivery** | Recapito archivio gruppo, spunte mittente umano, erogazione fan-out. |
| **reception** | Gate bidirezionale allow list prima di INSERT storico o copia erogata. |
| **navigation** | `OpenGroupChat` / `BackToGroupHome` in shell gruppo. |
| **multi-account** | Account gruppo nel manifest; focus come qualsiasi sessione. |
| **media** | Broadcast media: upload prima di RPC broadcast con content type e URL. |

---

## Invarianti

1. Account gruppo **non** espone inbox multi-peer — una sola conversazione (storico owner).
2. Broadcast richiede almeno un destinatario in allow list del gruppo (escluso il gruppo stesso).
3. Un solo broadcast alla volta nella stessa sessione gruppo (nessuna coda outbound persistente come 1:1).
4. Dopo broadcast riuscito: storico ricaricato — nessuna bolla optimistic client-side.
5. Spunte messaggio umano→gruppo: solo fino a recapito al gruppo; erogazione verso terzi non le modifica.
6. Rimozione da allow list blocca solo recapiti **nuovi**; messaggi già in archivio restano.
