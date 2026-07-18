# Contesto: media

**Stato modellazione:** `documented` (sotto-contesto di messaging)

Vedi [bounded-contexts.md](../bounded-contexts.md) e [metodo dominio](../README.md).

## Artefatti

| File | Stato |
|------|-------|
| [glossary.md](./glossary.md) | compilato |
| [commands-and-events.md](./commands-and-events.md) | compilato |
| [seq-voice-hold-send](../../model/uml/media/seq-voice-hold-send.puml) | compilato |
| [seq-media-upload](../../model/uml/media/seq-media-upload.puml) | compilato |

## Implementazione runtime

| Componente | Ruolo |
|------------|-------|
| `MessageMediaService` | Upload `chat-media` bucket |
| `MessagesController.send*` | Optimistic + coda + RPC |
| `ChatInputBar` | Voice hold, pin location, picker allegati |
| `VoiceRecordingService` | Registrazione WebM/Opus |
| `prepareImageForUpload` | HEIC → JPEG |

## SDD

[PROM-CHAT-MEDIA](../../specs/promises/product/PROM-CHAT-MEDIA.md) · [PROM-OUTBOUND-SEND](../../specs/promises/product/PROM-OUTBOUND-SEND.md)

## Guida operativa

[docs/guides/media.md](../../guides/media.md)
