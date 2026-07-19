# Comandi ed eventi — contesto media

**Ultima revisione:** 2026-07-19  
**UML:** [docs/model/uml/media/](../../model/uml/media/)  
**Guida:** [docs/guides/media.md](../../guides/media.md)

---

## Comandi (intento)

| Comando | Emesso da | Descrizione |
|---------|-----------|-------------|
| `RecordVoiceStart` | Utente | Inizia registrazione vocale (long-press). |
| `RecordVoiceStop` | Utente | Termina registrazione (durata minima 1 s). |
| `RecordVoiceLock` | Utente | Blocca registrazione per invio a mani libere. |
| `RecordVoiceCancel` | Utente | Annulla registrazione senza invio. |
| `SendVoice` | Utente | Conferma invio messaggio vocale. |
| `PickImage` | Utente | Seleziona immagine da galleria o fotocamera. |
| `SendImage` | Utente | Conferma invio immagine (con caption opzionale). |
| `PickVideo` | Utente | Seleziona file video. |
| `SendVideo` | Utente | Conferma invio video. |
| `SendGif` | Utente | Seleziona e invia GIF. |
| `PickLocation` | Utente | Avvia acquisizione posizione. |
| `RefineLocation` | Utente | Affina coordinate in anteprima mappa. |
| `SendLocation` | Utente | Conferma invio posizione. |
| `UploadMedia` | Policy (invio/retry) | Carica blob su storage e ottiene URL pubblico. |

---

## Eventi

| Evento | Descrizione |
|--------|-------------|
| `VoiceRecordingStarted` | Registrazione vocale attiva. |
| `VoiceRecordingLocked` | Registrazione bloccata (mani libere). |
| `VoicePreviewReady` | Anteprima vocale disponibile. |
| `VoiceRecordingCancelled` | Registrazione annullata. |
| `ImageFormatRejected` | Formato immagine non supportato. |
| `ImageNormalized` | Immagine convertita in formato canonico (es. HEIC → JPEG). |
| `MediaCached` | Bytes media in cache RAM per anteprima pending. |
| `MediaPersisted` | Media salvato localmente per retry coda. |
| `MediaUploaded` | URL pubblico disponibile su storage. |
| `MediaUploadFailed` | Upload fallito — messaggio marcato failed. |
| `LocationPreviewShown` | Coordinate arrotondate in anteprima mappa. |
| `LocationSent` | Posizione inviata (nessun upload blob). |

---

## Policy

| Policy | Trigger | Azione |
|--------|---------|--------|
| **Upload prima di send** | Tipi con allegato | `UploadMedia` prima di RPC invio |
| **Location senza upload** | `SendLocation` | Solo coordinate in RPC |
| **Limiti dimensione** | Pre-upload | Rifiuto client se oltre soglia |
| **Voice minima** | `RecordVoiceStop` < 1 s | `VoiceRecordingCancelled` |
| **Web blob grande** | Persistenza locale | Solo cache RAM, non storage prefs |

---

## Tracciabilità SDD

| Elemento | Promessa |
|----------|----------|
| Foto/video limiti e HEIC | PROM-CHAT-MEDIA-001, 001b |
| Coda image/video | PROM-CHAT-MEDIA-007, PROM-OUTBOUND-SEND |
| Voice hold-to-send | SURF-CHAT (UX in media.md) |
