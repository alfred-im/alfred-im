# Handoff sessione — 2026-07-11

Documento per AI — **leggere prima di task multi-account, messaggistica, profilo peer, gruppi o UX liste**.

---

## Stato repository

| Item | Valore |
|------|--------|
| Branch `main` | PR su main **#108–#179** |
| Demo live | https://alfred-im.github.io/XmppTest/ — ultimo `deploy-pages` riuscito |
| **SDD** | Registro `docs/specs/registry.md`: **7 SYS**, 13 PROM, 12 SURF |
| Multi-account | **`PROM-MULTI-ACCOUNT`** + **`SURF-AUTH`**: manifest; **una** GoTrue in RAM (focus) |
| Messaggistica | **`SYS-MAILBOX`**: archivio per `owner_id`, outbox sempre |
| **Confine account** | **`SYS-ACCOUNT-BOUNDARY`**: RPC account solo `owner_id = auth.uid()` |
| **Delivery plane** | **`SYS-DELIVERY`**: worker `alfred_delivery.*` — unico attraversamento confine |
| **Ricerca liste** | **`PROM-LIST-FILTER`** + **`SURF-*`**: lente on-demand (`CollapsibleListSearch`) |
| **Ricezione filtrata** | **`SYS-RECEPTION`**: gate nel **worker**; rifiuto silenzioso (✓ senza ✓✓) |
| **Scheda profilo peer** | **`PROM-PEER-PROFILE`** + **`SURF-PEER-PROFILE`**: tap avatar → overlay |
| **Gruppi** | **`SYS-GROUP`**: erogazione via worker; UI autore |
| Chat media | Testo, GIF, voice (WebM), location (OSM) |
| Gate test | `verify.sh` (Dart) + `integration-ticks` (contratto spunte live) |

---

## Breaking change allow list (#161)

- Ogni account parte con **`reception_allowlist` vuota** → nessuno può consegnare messaggi finché non si aggiunge qualcuno in **Persone consentite** o dalla scheda profilo peer.
- Mittente non in lista: RPC **ok**, copia mittente (✓), **mai** `delivered_at` — worker segna `reception_rejected` in outbox; non è errore di invio.
- Rubrica (`contacts`) **≠** allow list.

---

## Contratto spunte (#179) — sintesi

| Spunta | Campi copia mittente | Chi imposta |
|--------|----------------------|-------------|
| ✓ | `delivered_at` null | Account mittente (accettato server) |
| ✓✓ grigie | `delivered_at` set | Worker `deliver` dopo gate destinatario |
| ✓✓ blu | `read_at` set | Lettore segna locale → worker `read_receipt` |

Test: `supabase/tests/delivery_ticks_smoke.sql`, `bash scripts/test.sh integration-ticks`.

---

## Ricerca liste (#132, #171) — sintesi

| Superficie | Widget | Filtro |
|------------|--------|--------|
| Inbox | `InboxPanel` + `CollapsibleListSearch` | `InboxController.filteredPeers` |
| Rubrica | `ContactsScreen` | `filterByQueryFields` su nome/username |
| Persone consentite | `AllowedPeopleScreen` | idem |

Contratto: `PROM-LIST-FILTER`, `SURF-INBOX`, `SURF-CONTACTS`, `SURF-ALLOWLIST`.

---

## Scheda profilo peer (#163, #176) — sintesi

| Elemento | Comportamento |
|----------|---------------|
| Apertura | Tap avatar peer Alfred |
| Allow | Switch «Consenti messaggi» → `reception_allowlist` |
| Chat | CTA «Inizia a chattare» → apre conversazione |

Doc: `docs/implementation/peer-profile-overlay.md`.

---

## Gruppi (#162, #179) — sintesi

| Concetto | Comportamento |
|----------|---------------|
| Invio umano→gruppo | Copia mittente + outbox → worker INSERT storico gruppo + `alfred_delivery.erogate_group_message` |
| Broadcast | Una riga archivio gruppo + outbox `group_erogate` |
| Spunte umano→gruppo | ✓✓ = recapito al **gruppo**; erogazione terzi non tocca spunte originali |

Doc: `docs/implementation/groups-client.md`, `SYS-GROUP`, `SYS-DELIVERY`.

---

## File chiave client

| Area | Path |
|------|------|
| Multi-account | `client/lib/services/account_manager.dart` · `docs/implementation/multi-account-client.md` |
| Invio / spunte UI | `message_service.dart`, `message.dart`, `message_bubble.dart` |

Smoke SQL: `delivery_ticks_smoke.sql`, `group_delivery_smoke.sql`, `group_broadcast_smoke.sql`, `mailbox_*.sql`, `reception_allowlist_*.sql`.

---

## Topic aperti

| Topic | Doc |
|-------|-----|
| Badge / realtime account in background | Rinviato — BroadcastChannel web |
| Multi-tab stesso browser | Last-write-wins (limite noto) |

---

**Riferimenti**: `PROJECT_MAP.md`, `docs/INDICE.md`, `docs/specs/registry.md`, `CHANGELOG.md`
