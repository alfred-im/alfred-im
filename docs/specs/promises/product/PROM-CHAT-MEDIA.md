# PROM-CHAT-MEDIA — Foto e video in chat

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-CHAT-MEDIA` |
| **Classe** | PRODUCT |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-19 |

Promessa di prodotto: invio e visualizzazione di **foto** (`image`) e **video** (`video`) in chat, con didascalia opzionale, upload su bucket `chat-media`, coda/retry allineata a GIF/voice.

---

## 1. Problema / obiettivo

L'utente può condividere foto e video nelle conversazioni 1:1 e nei broadcast di account gruppo, con didascalia testuale opzionale sotto il media.

---

## 2. Promesse

### MUST

| ID | Promessa |
|----|----------|
| **PROM-CHAT-MEDIA-001** | `content_type` `image`: MIME `image/jpeg`, `image/png`, `image/webp` in archivio; `media_url` + `media_mime` obbligatori; max **10 MB** |
| **PROM-CHAT-MEDIA-001b** | Il client **accetta HEIC/HEIF** da galleria/fotocamera (iPhone, social) e **converte in JPEG** prima dell’upload — l’utente non deve convertire manualmente |
| **PROM-CHAT-MEDIA-002** | `content_type` `video`: MIME `video/mp4`, `video/webm`; `media_url`, `media_mime`, `duration_seconds` obbligatori; max **50 MB** |
| **PROM-CHAT-MEDIA-003** | Didascalia opzionale in `body` (testo sotto il media in bolla e in anteprima inbox troncata) |
| **PROM-CHAT-MEDIA-004** | Upload path `chat-media/{auth.uid()}/{uuid}.{ext}` — stesso blob condiviso tra copie archivio |
| **PROM-CHAT-MEDIA-005** | Foto da **galleria/file picker** e da **fotocamera** (`image_picker`) |
| **PROM-CHAT-MEDIA-006** | Video solo da **file picker** (MP4/WebM) |
| **PROM-CHAT-MEDIA-007** | Coda `OutboundMessageQueue` estesa a `image` e `video` — [PROM-OUTBOUND-SEND](./PROM-OUTBOUND-SEND.md) |
| **PROM-CHAT-MEDIA-008** | Gruppi: stesso contratto via `broadcast_message_to_allowlist` |

### MUST NOT

| ID | Promessa |
|----|----------|
| **PROM-CHAT-MEDIA-010** | Video da fotocamera / registrazione live |
| **PROM-CHAT-MEDIA-011** | Unificare GIF statiche sotto `image` — GIF resta `gif` |

---


## 3. Modello (riferimento)

| Elemento | Artefatto |
|----------|-----------|
| Glossario / comandi | [docs/domain/media/](../../../domain/media/), [docs/domain/messaging/](../../../domain/messaging/) |
| UML | [docs/model/uml/media/media-state.puml](../../model/uml/media/media-state.puml) |
| Invio media | `PrepareImage` / `PrepareVideo` → `SendContent` (messaging) |

**Implementazione (non vincolante):** [docs/domain/media/README.md](../../../domain/media/README.md) · [docs/guides/media.md](../../../guides/media.md)


## 4. Superfici conformi

| Superficie | Stato | File |
|------------|-------|------|
| SURF-CHAT | `approved` | [SURF-CHAT.md](../../surfaces/SURF-CHAT.md) |
| SURF-GROUP-CONVERSATION | `approved` | [SURF-GROUP-CONVERSATION.md](../../surfaces/SURF-GROUP-CONVERSATION.md) |

---

## 5. Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| PROM-CHAT-MEDIA-001 | `mailbox_send_media_smoke.sql` (validazione RPC `image`); `image_bytes_test.dart` (magic bytes JPEG/PNG/WebP) |
| PROM-CHAT-MEDIA-001b | `image_bytes_test.dart` (sniff HEIC); `prepare_image_for_upload` via `chat_media_support_test.dart`; widget pending HEIC in `message_bubble_test.dart` |
| PROM-CHAT-MEDIA-002 | `mailbox_send_media_smoke.sql` (validazione RPC `video`); `video_file_extension_test.dart`; `messages_controller_media_test.dart` |
| PROM-CHAT-MEDIA-003 | `messages_controller_media_test.dart` (caption); `message_bubble_test.dart` (didascalia sotto foto) |
| PROM-CHAT-MEDIA-004 | `MessageMediaService` limiti in `chat_media_support_test.dart`; path upload in `message_media_service.dart` |
| PROM-CHAT-MEDIA-005–006 | `picked_file_bytes_test.dart`; flussi controller in `messages_controller_media_test.dart` |
| PROM-CHAT-MEDIA-007 | `chat_media_support_test.dart` (coda + `OutboundMediaCache`); `messages_controller_media_test.dart` (optimistic + retry path) |
| PROM-CHAT-MEDIA-008 | `group_messages_controller_media_test.dart`; `group_broadcast_smoke.sql` |
| PROM-CHAT-MEDIA (gate) | `bash scripts/test.sh gate` (**192** test Dart) |

Gate: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh`

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [SYS-MAILBOX](../system/SYS-MAILBOX.md) | Validazione RPC |
| [PROM-OUTBOUND-SEND](./PROM-OUTBOUND-SEND.md) | Coda client |
| [registry.md](../../registry.md) | Indice promesse |
