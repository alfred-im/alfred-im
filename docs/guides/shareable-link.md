# Link condivisibili

**Contratto**: [PROM-SHAREABLE-LINK](../specs/promises/product/PROM-SHAREABLE-LINK.md)

Solo client Flutter — nessuna migrazione Supabase.

## Formato

| Fragment | Destinazione |
|----------|--------------|
| `#username` | Scheda profilo peer |
| `#username/chat` | Conversazione 1:1 |
| `#username@server` | `@server` = `AppConfig.imServerId` |

Il link identifica la risorsa, non l'account di chi apre l'URL.

## Condividi

| Superficie | Azione |
|------------|--------|
| Scheda profilo peer | Pulsante **Condividi** → share di sistema |
| Sidebar account in focus | **Condividi** a sinistra di «Chiudi account» |

Nessun pulsante Condividi in chat — apertura chat da link solo via `#indirizzo/chat`.

## Ingresso

```
Fragment #  →  ShareableLinkListener  →  ShareableLinkController.applyFragment
            →  handleIfReady (dopo sessionReady)
                 ├─ profilo non trovato → ShareableLinkNotFoundScreen
                 ├─ #peer → showPeerProfileOverlay
                 └─ #peer/chat → openConversation
```

| Caso | Comportamento |
|------|---------------|
| 0 account | Overlay auth; dopo primo account → risorsa del fragment |
| Peer proprio | Fragment ignorato |

## File client

`shareable_link.dart`, `shareable_link_controller.dart`, `shareable_link_listener.dart`, `shareable_link_not_found_screen.dart`

## Test

`shareable_link_test.dart`, `peer_profile_overlay_test.dart`
