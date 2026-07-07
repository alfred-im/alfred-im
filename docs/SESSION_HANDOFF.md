# Handoff sessione — 2026-07-07

Documento per AI — **leggere prima di task multi-account, messaggistica, profilo peer o gruppi**.

---

## Stato repository

| Item | Valore |
|------|--------|
| Branch `main` | PR Alpha **#108–#163** |
| Alpha live | https://alfred-im.github.io/XmppTest/ — ultimo `deploy-alpha` riuscito |
| Multi-account | Manifest tutti gli account; **una** GoTrue in RAM (focus) |
| Messaggistica | Modello **caselle** (`MAILBOX-*`): archivio per `owner_id`, outbox sempre, spunte `delivered_at`/`read_at` |
| **Ricezione filtrata** | **`RECEPTION-ALLOWLIST`**: allow list sempre attiva; lista vuota = nessun recapito; rifiuto silenzioso (✓ senza ✓✓) |
| **Scheda profilo peer** | **`PEER-PROFILE`**: tap avatar → overlay fullscreen; switch Allow + rubrica (immediati, senza dialog) |
| **Gruppi** | **`GROUP-CORE` + `GROUP-DELIVERY`**: account `profile_kind = group`; partecipazione allow list bidirezionale; erogazione automatica; shell senza inbox; `original_author_id` canonico; UI autore avatar+nome |
| Chat media | Testo, GIF, voice (WebM), location (OSM) |
| Gate test | **108** test (`verify.sh`) |

---

## Breaking change allow list (#161)

- Ogni account parte con **`reception_allowlist` vuota** → nessuno può consegnare messaggi finché non si aggiunge qualcuno in **Persone consentite** (icona inbox accanto a Contatti) **oppure** dalla scheda profilo peer (tap avatar).
- Account esistenti: **nessuna** voce pre-popolata; aggiunta manuale obbligatoria per ripristinare recapito.
- Mittente non in lista: RPC **ok**, copia mittente su server (✓), **mai** `delivered_at` (no ✓✓) — non è errore di invio.
- Rubrica (`contacts`) **≠** allow list.

---

## Scheda profilo peer (#163) — sintesi

| Elemento | Comportamento |
|----------|---------------|
| Apertura | Tap avatar peer Alfred (inbox, chat, autore gruppo, allow list, rubrica internal) |
| UI | Overlay fullscreen — avatar, nome, `@username`, pronomi |
| Allow | Switch «Consenti messaggi» → `reception_allowlist` (subito) |
| Rubrica | Pulsante aggiungi/rimuovi → `contacts` (subito) |
| Self | Profilo proprio: nessun overlay peer |

Doc: `docs/implementation/peer-profile-overlay.md`, spec `PEER-PROFILE.spec.md`.

---

## Gruppi (#162) — sintesi

| Concetto | Comportamento |
|----------|---------------|
| Identità | Gruppo = account Alfred (`profile_kind = group`), registrazione con email reale |
| Partecipazione | Solo allow list **bidirezionale** — nessuna membership / inviti |
| Shell gruppo | No `list_inbox`; `GroupConversationScreen` + allow list + profilo |
| Invio umano→gruppo | Storico gruppo + erogazione automatica ai membri in allow list |
| Broadcast | **Una** riga storico gruppo + fan-out proxy (`broadcast_message_to_allowlist`) |
| Autore UI | `original_author_id` = chi ha scritto; header con avatar + `display_name` (tap → scheda profilo peer) |
| Spunte umano→gruppo | ✓✓ = recapito al **gruppo**; erogazione verso terzi non tocca spunte originali |

Doc: `docs/implementation/groups-client.md`, spec `GROUP-CORE`, `GROUP-DELIVERY`.

---

## File chiave client

| Area | Path |
|------|------|
| Overlay profilo peer | `client/lib/widgets/peer_profile_overlay.dart` |
| Allow list UI lista | `client/lib/screens/allowed_people_screen.dart` |
| Shell gruppo | `client/lib/screens/group_conversation_screen.dart` |
| Multi-account | `client/lib/services/account_manager.dart` |

Smoke SQL gruppi: `supabase/tests/group_schema_smoke.sql`, `group_delivery_smoke.sql`, `group_broadcast_smoke.sql`.

---

## Topic aperti

| Topic | Doc |
|-------|-----|
| Badge / realtime account in background | Rinviato — serve fix BroadcastChannel o upstream |
| Multi-tab stesso browser | Last-write-wins (limite noto) |
| «Disconnetti ovunque» (revoca globale) | Futuro opzionale — logout locale già in `AccountSession.close()` (`single-device-logout-open.md`) |
| Bridge federazione (consumer outbox) | Stub health only — gate allow list anche su bridge (fase B) |
| Preview inbox autore gruppo (REQ-020) | SHOULD non implementato — prefisso autore in `list_inbox` preview |

---

## Indice doc

`docs/INDICE.md`
