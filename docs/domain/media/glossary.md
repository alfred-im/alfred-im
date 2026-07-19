# Glossario — contesto media

**Bounded context:** `media` (sotto-contesto di messaging per allegati chat)  
**Ultima revisione:** 2026-07-19  
**Promesse SDD:** [PROM-CHAT-MEDIA](../../specs/promises/product/PROM-CHAT-MEDIA.md), [PROM-OUTBOUND-SEND](../../specs/promises/product/PROM-OUTBOUND-SEND.md)

---

## Linguaggio ubiquo

| Termine | Definizione |
|---------|-------------|
| **Chat media storage** | Bucket storage per allegati; path per utente e UUID; URL pubblico post-upload. |
| **Media upload** | Caricamento binario con limiti byte e MIME canonici. |
| **Outbound media cache** | Cache RAM per anteprima media pending prima dell'upload. |
| **Image normalization** | Conversione formati (es. HEIC → JPEG); verifica magic bytes. |
| **Voice limits** | Durata massima, dimensione massima, formato audio canonico. |
| **Media limits** | Soglie image/video; persistenza locale web sotto soglia byte. |
| **Location precision** | Coordinate arrotondate; tile mappa; nessun bucket. |
| **Voice capture phase** | idle → recording → locked → preview. |
| **Location capture phase** | idle → refining → preview conferma. |
| **Local media reference** | Riferimento locale per retry coda (disco o memoria). |
| **Pending media URL** | Placeholder fino a URL pubblico server disponibile. |

---

## Tipi contenuto

| `content_type` | Upload | Campi obbligatori invio |
|----------------|--------|-------------------------|
| `gif` | Sì | URL media |
| `image` | Sì | URL media, MIME, dimensione; corpo opzionale |
| `video` | Sì | URL media, MIME, durata, dimensione |
| `voice` | Sì | URL media, MIME, durata, dimensione |
| `location` | No | latitudine, longitudine |

---

## Confini

| Contesto | Relazione |
|----------|-----------|
| **messaging** | Dopo upload, invio persiste riga mailbox. |
| **messaging** | Coda retry legge riferimento locale e ri-invoca upload + send. |

---

## Invarianti

1. Upload sempre prima di invio RPC (tranne location).
2. Dimensione verificata client-side prima dell'upload.
3. Web: blob grandi non in persistenza prefs — solo cache RAM.
4. Voice: durata minima 1 s; registrazione più corta annullata.
5. Image: formato sconosciuto → errore UI senza accodamento.
