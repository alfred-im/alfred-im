# PROM-CHAT-MEDIA — Foto e video in chat

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-CHAT-MEDIA` |
| **Classe** | PRODUCT |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-13 |

Promessa di prodotto: invio e visualizzazione di **foto** (`image`) e **video** (`video`) in chat, con didascalia opzionale, upload su bucket `chat-media`, coda/retry allineata a GIF/voice.

---

## 1. Problema / obiettivo

L'utente può condividere foto e video nelle conversazioni 1:1 e nei broadcast di account gruppo, con didascalia testuale opzionale sotto il media.

---

## 2. Promesse

### MUST

| ID | Promessa |
|----|----------|
| **PROM-CHAT-MEDIA-001** | `content_type` `image`: MIME `image/jpeg`, `image/png`, `image/webp`; `media_url` + `media_mime` obbligatori; max **10 MB** |
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

## 3. Contratto implementativo

| Elemento | Responsabilità |
|----------|----------------|
| `ChatMediaConfig` | Limiti byte, MIME, estensioni |
| `MessageMediaService` | `uploadImage`, `uploadVideo` |
| `MessageService` | `sendImageToProfile`, `sendVideoToProfile`, broadcast analoghi |
| `MessagesController` | Optimistic + retry con didascalia |
| `GroupMessagesController` | Broadcast image/video |
| `ChatInputBar` | Menu allegati: galleria, fotocamera, video |
| `MessageBubble` | Rendering foto + player video inline |

---

## 4. Superfici conformi

| Superficie | Stato | File |
|------------|-------|------|
| SURF-CHAT | `approved` | [SURF-CHAT.md](../../surfaces/SURF-CHAT.md) |
| SURF-GROUP-CONVERSATION | `approved` | [SURF-GROUP-CONVERSATION.md](../../surfaces/SURF-GROUP-CONVERSATION.md) |

---

## 5. Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| PROM-CHAT-MEDIA-001–002 | `mailbox_send_media_smoke.sql` |
| PROM-CHAT-MEDIA-003–007 | `models_and_utils_test.dart`, `messages_controller_multi_account_test.dart` |
| PROM-CHAT-MEDIA-008 | `group_broadcast` smoke + widget test |
| PROM-CHAT-MEDIA | `bash scripts/test.sh gate` |

Gate: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh`

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [SYS-MAILBOX](../system/SYS-MAILBOX.md) | Validazione RPC |
| [PROM-OUTBOUND-SEND](./PROM-OUTBOUND-SEND.md) | Coda client |
| [registry.md](../../registry.md) | Indice promesse |
