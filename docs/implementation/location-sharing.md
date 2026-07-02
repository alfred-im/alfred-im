# Condivisione posizione statica

**Stato**: implementato — client Flutter + migrazioni Supabase (`20260702120000`, `20260702120100`).

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

| Azione | Comportamento |
|--------|---------------|
| Pulsante **pin** (accanto a GIF) | Legge GPS corrente e invia |
| Permesso negato | SnackBar / messaggio errore in `MessagesController` |
| Retry | `OutboundMessageQueue` con `latitude`/`longitude` in coda |

## UX ricezione (`LocationMessageContent`)

- Anteprima mappa statica OpenStreetMap (`staticmap.openstreetmap.de`, nessuna API key)
- Coordinate formattate (es. `45.12345°N, 9.54321°E`)
- Tap → apre OpenStreetMap in browser (`url_launcher`)

## Client Flutter

| Area | File / componente |
|------|-------------------|
| Config | `lib/config/location_config.dart` |
| Geolocalizzazione | `lib/services/location_service.dart` (`geolocator`) |
| Invio | `MessagesController.sendLocation` → RPC `send_message_to_profile` |
| Bolla | `lib/widgets/location_message_content.dart` |
| Coda retry | `OutboundMessageQueue` — `OutboundContentKind.location` |

Dipendenze aggiunte: `geolocator`, `url_launcher`.

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

- Posizione **live** con aggiornamenti periodici
- Reverse geocoding (indirizzo testuale)
- Federazione XMPP (outbox pronta, bridge stub)
