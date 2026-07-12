# Link condivisibili (`#indirizzo`)

> **Contratto canonico**: [PROM-SHAREABLE-LINK.md](../specs/promises/product/PROM-SHAREABLE-LINK.md) — evidenza implementativa PR #178.

**Stato**: `implemented` — solo client Flutter (nessuna migrazione Supabase)

## Formato

| Fragment | Destinazione |
|----------|--------------|
| `#username` | Scheda profilo peer (`PeerProfileOverlay`) |
| `#username/chat` | Conversazione 1:1 con quel peer (`ChatPeer`) |
| `#username@server` | Stesso contratto; `@server` deve coincidere con `AppConfig.imServerId` |

Il link identifica la **risorsa**, non l'account Alfred di chi apre l'URL. Nessun `profile_id` nell'URL.

## Condividi (uscita)

| Superficie | Controllo | Azione |
|------------|-----------|--------|
| Scheda profilo peer | Pulsante **Condividi** (alto a destra) | `shareShareableProfileLink` → foglio di sistema (`share_plus`) con URL `#indirizzo` profilo |
| Sidebar account in focus | **Condividi** a sinistra di «Chiudi account» | Stesso share del profilo attivo (`profileForSharing` + username da manifest) |

**Non** esiste pulsante Condividi in chat — apertura chat da link in ingresso solo via fragment `#indirizzo/chat`.

## Ingresso (navigazione)

```
URL con fragment #  →  ShareableLinkListener (hashchange web)
                    →  ShareableLinkController.applyFragment
                    →  handleIfReady (dopo sessionReady + ≥1 account)
                         ├─ profilo non trovato → ShareableLinkNotFoundScreen
                         ├─ #peer → showPeerProfileOverlay
                         └─ #peer/chat → AuthController.openConversation
```

| Caso | Comportamento |
|------|---------------|
| **0 account** nel manifest | Overlay auth obbligatorio (`SURF-AUTH-014`); dopo primo account → risorsa del fragment |
| **≥1 account** | Shell normale; risorsa nell'account in focus |
| Peer = profilo proprio | Fragment ignorato (nessun overlay su sé stessi) |
| Indirizzo non risolvibile | Schermata «risorsa non trovata» |

## Client Flutter

| Area | File |
|------|------|
| Parse / build URL | `lib/utils/shareable_link.dart` |
| Fragment web (`hashchange`) | `lib/utils/shareable_link_platform_web.dart` |
| Controller stato | `lib/providers/shareable_link_controller.dart` |
| Listener in shell | `lib/widgets/shareable_link_listener.dart` |
| 404 UI | `lib/screens/shareable_link_not_found_screen.dart` |
| Bootstrap lettura fragment | `lib/services/supabase_bootstrap.dart` |

## Test

| REQ | Verifica |
|-----|----------|
| PROM-SHAREABLE-LINK-001, 002, 030 | `client/test/unit/shareable_link_test.dart` |
| PROM-SHAREABLE-LINK-020, 021; SURF-PEER-PROFILE-025 | `client/test/widget/peer_profile_overlay_test.dart` |
| PROM-SHAREABLE-LINK-023; SURF-ACCOUNT-SIDEBAR-014 | `client/test/widget/account_sidebar_test.dart` |
| SURF-AUTH-014; fragment + sessione pronta | `client/test/widget/shareable_link_listener_test.dart` |

Gate: `cd client && bash scripts/verify.sh` (**161** test).
