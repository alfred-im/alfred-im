# Condivisione posizione statica

> **Contratto canonico**: [SYS-MAILBOX.md](../specs/promises/system/SYS-MAILBOX.md) — evidenza implementativa PR #153.

**Stato**: implementato — client Flutter + migrazioni Supabase

## Contratto

| Campo | Valore |
|-------|--------|
| `content_type` | `location` |
| `latitude` | double, obbligatorio, range [-90, 90] |
| `longitude` | double, obbligatorio, range [-180, 180] |
| `body` | opzionale (etichetta futura; Alpha invia vuoto) |

Coordinate arrotondate a **5 decimali** lato client (`LocationConfig.coordinateDecimals` ≈ precisione al metro).

Nessun bucket storage — solo coordinate in Postgres.

## UX invio (`ChatInputBar`)

| Fase | Comportamento |
|------|---------------|
| Tap **pin** | Apre subito il box anteprima (area mappa con loader interno) |
| **Sharing** | Stream GPS; **Invia posizione** disabilitato fino alla prima coordinata |
| Overlay | `OverlayEntry` a schermo intero + velo semitrasparente — blocca **tutti** i tap sulla chat sotto |
| Affinamento | Il pin si aggiorna se il GPS migliora (`distanceFilter: 0`) |
| **Invia posizione** | Invia le coordinate **al momento del tap** (arrotondate) |
| **Annulla** | Pulsante o **tap sul velo** fuori dal pannello bianco → chiude stream e overlay senza inviare |
| Permesso negato | SnackBar con messaggio da `LocationServiceException` |
| Retry invio | `OutboundMessageQueue` con `latitude`/`longitude` in coda |

**Scelta**: anteprima obbligatoria prima dell'invio — niente invio al solo tap sul pin.

## UX ricezione (`LocationMessageContent`)

- Mappa **tile OSM** renderizzata in client (`flutter_map` + `tile.openstreetmap.org`) — **non** `staticmap.openstreetmap.de` (servizio defunto)
- Attribuzione «© OpenStreetMap» in bolla
- Coordinate formattate (es. `45.12345°N, 9.54321°E`)
- Tap → apre OpenStreetMap in browser (`url_launcher`)

## Client Flutter

| Area | File / componente |
|------|-------------------|
| Config | `lib/config/location_config.dart` |
| Modello lettura GPS | `lib/models/location_reading.dart` |
| Geolocalizzazione | `lib/services/location_service.dart` (`geolocator` stream) |
| Mappa condivisa | `lib/widgets/location_map_preview.dart` |
| Invio | `ChatInputBar` anteprima → `MessagesController.sendLocation(lat,lng)` → RPC |
| Bolla | `lib/widgets/location_message_content.dart` |
| Coda retry | `OutboundMessageQueue` — `OutboundContentKind.location` |

Dipendenze: `geolocator`, `flutter_map`, `latlong2`, `url_launcher`.

Permessi Android: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` in `AndroidManifest.xml`.

## Supabase

Migrazioni **due step** (enum PostgreSQL deve commitare prima dell'uso):

| File | Contenuto |
|------|-----------|
| `20260702120000_message_location_support.sql` | `ALTER TYPE … ADD VALUE 'location'` |
| `20260702120100_message_location_support.sql` | colonne `latitude`/`longitude`, CHECK, RPC, inbox, trigger outbox |

- RPC `send_message_to_profile` — 10 parametri (aggiunti `p_latitude`, `p_longitude`)
- `format_location_preview()` → preview inbox `📍 Posizione`
- `list_inbox`, `list_peer_messages`, `mark_peer_read`: includono `content_type = location`
- Outbox payload federato: `latitude`, `longitude` (bridge futuro → XEP-0080)

## Non in scope (Alpha)

- Posizione **live** con aggiornamenti periodici in chat
- Reverse geocoding (indirizzo testuale)
- Federazione XMPP (outbox pronta, bridge stub)
