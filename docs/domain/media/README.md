# Modulo: media (sotto messaging)

**Stato modellazione:** `documented`

**Non è un bounded context runtime separato** — la preparazione allegati (voice, image, video, gif, location) è un **sottosistema del contesto messaging**. La cartella `docs/domain/media/` documenta glossario e comandi per chiarezza modellistica; l'esecuzione client passa da `MessagesControllerEffects` / `MessageMediaService`, non da una macchina `media` dedicata.

Sotto-contesto di **messaging** — vedi [mapping messaging](../messaging/README.md).

## Mapping dominio → implementazione

| Dominio | Codice |
|---------|--------|
| `PrepareVoiceMessage` | `RecordVoiceStart/Stop`, `SendVoice` |
| `PrepareImage` | `PickImage`, `SendImage` |
| `PrepareVideo` | `PickVideo`, `SendVideo` |
| `PrepareGif` | `SendGif` |
| `PrepareLocation` | `PickLocation`, `RefineLocation`, `SendLocation` |
| `AttachmentReady` | `MediaUploaded` / preview pronta |
| `AttachmentRejected` | `ImageFormatRejected`, limiti dimensione |

Implementazione: `MessageMediaService`, `VoiceRecordingService`, `MessagesController.send*`
