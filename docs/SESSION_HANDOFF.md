# Handoff sessione — 2026-07-09

Documento per AI — **leggere prima di task multi-account, messaggistica, profilo peer, gruppi o UX liste**.

---

## Stato repository

| Item | Valore |
|------|--------|
| Branch `main` | PR su main **#108–#176** |
| Demo live | https://alfred-im.github.io/XmppTest/ — ultimo `deploy-pages` riuscito |
| **SDD** | Registro `docs/specs/registry.md`: 5 SYS, 13 PROM, 12 SURF (incluso `SURF-APP-SHELL` in `SURF-AUTH`) |
| Multi-account | **`PROM-MULTI-ACCOUNT`** + **`SURF-AUTH`**: manifest; **una** GoTrue in RAM (focus) |
| Messaggistica | **`SYS-MAILBOX`**: archivio per `owner_id`, outbox sempre, spunte `delivered_at`/`read_at` |
| **Ricerca liste** | **`PROM-LIST-FILTER`** + **`SURF-*`**: lente on-demand (`CollapsibleListSearch`) |
| **Ricezione filtrata** | **`SYS-RECEPTION`** + **`PROM-RECEPTION-FILTER`**: allow list sempre attiva; rifiuto silenzioso |
| **Scheda profilo peer** | **`PROM-PEER-PROFILE`** + **`SURF-PEER-PROFILE`**: tap avatar → overlay; Allow + rubrica + CTA «Inizia a chattare» |
| **Gruppi** | **`SYS-GROUP`** + **`SURF-GROUP-*`**: `profile_kind = group`; erogazione automatica; UI autore |
| Chat media | Testo, GIF, voice (WebM), location (OSM) |
| Gate test | **144** test (`verify.sh`) |

---

## Breaking change allow list (#161)

- Ogni account parte con **`reception_allowlist` vuota** → nessuno può consegnare messaggi finché non si aggiunge qualcuno in **Persone consentite** (icona inbox accanto a Contatti) **oppure** dalla scheda profilo peer (tap avatar).
- Account esistenti: **nessuna** voce pre-popolata; aggiunta manuale obbligatoria per ripristinare recapito.
- Mittente non in lista: RPC **ok**, copia mittente su server (✓), **mai** `delivered_at` (no ✓✓) — non è errore di invio.
- Rubrica (`contacts`) **≠** allow list.

---

## Ricerca liste (#132, #171) — sintesi

| Superficie | Widget | Filtro |
|------------|--------|--------|
| Inbox | `InboxPanel` + `CollapsibleListSearch` | `InboxController.filteredPeers` |
| Rubrica | `ContactsScreen` | `filterByQueryFields` su nome/username |
| Persone consentite | `AllowedPeopleScreen` | idem |

Contratto: `PROM-LIST-FILTER`, `SURF-INBOX`, `SURF-CONTACTS`, `SURF-ALLOWLIST`.  
**Non** applicare il pattern lente alle bottom sheet «Aggiungi contatto/persona».

---

## Scheda profilo peer (#163, #176) — sintesi

| Elemento | Comportamento |
|----------|---------------|
| Apertura | Tap avatar peer Alfred (inbox, chat, autore gruppo, allow list, rubrica internal) |
| UI | Overlay fullscreen — avatar, nome, `@username`, pronomi |
| Allow | Switch «Consenti messaggi» → `reception_allowlist` (subito) |
| Rubrica | Pulsante aggiungi/rimuovi → `contacts` (subito) |
| Chat | CTA sticky «Inizia a chattare» in basso → chiude overlay e apre conversazione |
| Self | Profilo proprio: nessun overlay peer |

Doc: `docs/implementation/peer-profile-overlay.md`, promesse `PROM-PEER-PROFILE`, `SURF-PEER-PROFILE`.

---

## Gruppi (#162) — sintesi

| Concetto | Comportamento |
|----------|---------------|
| Identità | Gruppo = account Alfred (`profile_kind = group`), registrazione con email reale |
| Partecipazione | Solo allow list **bidirezionale** — nessuna membership / inviti |
| Shell gruppo | `GroupHomePanel` (home) → `GroupConversationScreen` quando `groupChatOpen`; no `list_inbox` |
| Invio umano→gruppo | Storico gruppo + erogazione automatica ai membri in allow list |
| Broadcast | **Una** riga storico gruppo + fan-out proxy (`broadcast_message_to_allowlist`) |
| Autore UI | `original_author_id` = chi ha scritto; header con avatar + `display_name` (tap → scheda profilo peer) |
| Spunte umano→gruppo | ✓✓ = recapito al **gruppo**; erogazione verso terzi non tocca spunte originali |

Doc: `docs/implementation/groups-client.md`, promessa `SYS-GROUP`.

---

## File chiave client

| Area | Path |
|------|------|
| Ricerca liste condivisa | `client/lib/widgets/collapsible_list_search.dart` |
| Overlay profilo peer | `client/lib/widgets/peer_profile_overlay.dart` |
| Allow list UI lista | `client/lib/screens/allowed_people_screen.dart` |
| Rubrica | `client/lib/screens/contacts_screen.dart` |
| Shell gruppo home | `client/lib/widgets/group_home_panel.dart` |
| Shell gruppo chat | `client/lib/screens/group_conversation_screen.dart` |
| Multi-account | `client/lib/services/account_manager.dart` · guida `docs/implementation/multi-account-client.md` |

Smoke SQL gruppi: `supabase/tests/group_schema_smoke.sql`, `group_delivery_smoke.sql`, `group_broadcast_smoke.sql`.

---

## Topic aperti

| Topic | Doc |
|-------|-----|
| Badge / realtime account in background | Rinviato — serve fix BroadcastChannel o upstream |
| Multi-tab stesso browser | Last-write-wins (limite noto) |
| «Disconnetti ovunque» (revoca globale) | Futuro opzionale — logout locale già in `AccountSession.close()` (`single-device-logout-open.md`) |
| Bridge federazione (consumer outbox) | Stub health only — gate allow list anche su bridge (fase B) |
| Preview inbox autore gruppo (SYS-GROUP-033) | SHOULD non implementato — prefisso autore in `list_inbox` preview |

---

## Indice doc

`docs/INDICE.md` · registro promesse: `docs/specs/registry.md`
