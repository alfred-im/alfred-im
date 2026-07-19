# Glossario — contesto shareable-link

**Bounded context:** `shareable-link`  
**Ultima revisione:** 2026-07-19  
**Promessa SDD:** [PROM-SHAREABLE-LINK](../../specs/promises/product/PROM-SHAREABLE-LINK.md)

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Fragment** | Segmento URL dopo `#` — identità stabile della risorsa (profilo o chat). |
| **Shareable link target** | Destinazione parsata: indirizzo normalizzato + tipo (`profile` \| `chat`). |
| **Canonical address** | `username` o `username@server` con server dell'istanza corrente. |
| **ParseFragment** | Legge e normalizza il fragment; ignora fragment riservati push. |
| **OpenFromShareableLink** | Comando verso navigation per `#indirizzo/chat` sull'account in focus. |
| **NotFound** | Peer/gruppo inesistente o indirizzo non risolvibile su questa istanza. |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **navigation** | `#…/chat` → `OpenFromShareableLink` con clear stale + fallback profilo. |
| **multi-account** | Richiede sessione pronta + ≥1 account; risorsa sull'account in focus. |
| **profile** | `#indirizzo` (senza `/chat`) → overlay scheda profilo peer. |

---

## Invarianti

1. Il link identifica la **risorsa**, non l'account del visitatore.
2. Fragment push-chat è riservato alle notifiche — non shareable-link.
3. Peer proprio → fragment ignorato, nessun errore.
4. Con 0 account aperti il target resta in coda fino a sessione pronta.
