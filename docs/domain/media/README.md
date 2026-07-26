# Modulo: media (sotto messaging)

**Stato modellazione:** `documented`

**Non è un bounded context runtime separato** — la preparazione allegati (voice, image, video, gif, location) è un **sottosistema del contesto messaging**. La cartella `docs/domain/media/` documenta glossario e comandi per chiarezza modellistica; **nessuno statechart `media` in produzione** (stati UML astratti, vedi sotto).

Sotto-contesto di **messaging** — vedi [mapping messaging](../messaging/README.md). Guida implementativa: [docs/guides/media.md](../../guides/media.md).

## Artefatti

| Livello | File |
|---------|------|
| Dominio | [glossary.md](./glossary.md), [commands-and-events.md](./commands-and-events.md) |
| UML | [media-state.puml](../../model/uml/media/media-state.puml) |
| Statechart | — (contesto `documented`; preparazione in `ChatInputBar`, invio in messaging) |

## Mapping dominio → implementazione

La preparazione (fasi `Preparing` / eventi `Attachment*`) vive nella UI composer; l'invio persiste il messaggio tramite **messaging** (`SendContent`).

### Comandi

| Dominio | Preparazione (UI) | Invio (`SendContent`) |
|---------|-------------------|------------------------|
| `PrepareVoiceMessage` | `ChatInputBar` + `VoiceRecordingService` (`start` / `stop` / `cancel`) | `MessagesController.sendVoice` → `MessagingCoordinator` → `MessagesControllerEffects.sendVoice` → `MessageMediaService.uploadVoice` |
| `PrepareImage` | `ChatInputBar` (galleria / fotocamera, `image_picker`) | `MessagesController.sendImage` → `MessagesControllerEffects.sendImage` (`prepareImageForUpload`, `MessageMediaService.uploadImage`) |
| `PrepareVideo` | `ChatInputBar` (file picker video) | `MessagesController.sendVideoFromPicker` → `MessagesControllerEffects.sendVideoFromPicker` |
| `PrepareGif` | `ChatInputBar` (file picker `.gif`) | `MessagesController.sendGif` → `MessagesControllerEffects.sendGif` |
| `PrepareLocation` | `ChatInputBar` (overlay mappa: affinamento GPS + conferma) | `MessagesController.sendLocation` → `MessagesControllerEffects.sendLocation` |

**Gruppi (broadcast):** stessi comandi di dominio; facade `GroupMessagesController.send*` → `GroupMessagesCoordinator` (upload + `broadcast_message_to_allowlist`).

### Eventi

| Dominio | Codice |
|---------|--------|
| `AttachmentReady` | Anteprima ottimistica (`OutboundMediaCache`, `pending://`) e/o upload completato prima della RPC |
| `AttachmentRejected` | `UnsupportedImageFormatException` (immagine), superamento limiti `ChatMediaConfig` / `VoiceConfig`, `MessageMediaService` size check |
| `AttachmentCancelled` | `VoiceRecordingService.cancel`, annullo overlay posizione in `ChatInputBar` |

### Componenti

| Componente | Ruolo |
|------------|-------|
| `ChatInputBar` | Composer: picker, registrazione vocale, overlay posizione |
| `VoiceRecordingService` | Cattura audio (fasi UI `_VoicePhase`) |
| `MessageMediaService` | Upload bucket `chat-media` |
| `OutboundMediaCache` | Anteprima locale media in coda |
| `MessagesController` / `GroupMessagesController` | Facade UI invio |
| `MessagesControllerEffects` / `GroupMessagesCoordinator` | Upload, coda, RPC messaggio |
