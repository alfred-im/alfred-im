# PROFILE — Profilo utente Alfred

| Campo | Valore |
|-------|--------|
| **Spec ID** | `PROFILE` |
| **Layer** | capability |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-03 |
| **ADR** | — (identità pubblica username: PR #118) |
| **PR** | #118 (username/email), #134 (avatar, pronomi, `ProfileSummary`) |
| **Correlata** | [MAILBOX-INBOX](./MAILBOX-INBOX.spec.md), [AUTH-MULTI](./AUTH-MULTI.spec.md) |

Documento per AI — contratto profilo Alfred: dati pubblici, modifica self-service, avatar, esposizione in UI.

---

## 1. Problema / obiettivo

Ogni utente Alfred ha un profilo pubblico (`profiles`) legato 1:1 a `auth.users`. L’utente modifica nome visualizzato, bio, pronomi e foto; **username** e **email** sono identità stabili (non editabili in schermata profilo). I dati pubblici compaiono in sidebar, inbox, chat e manifest multi-account.

---

## 2. Requisiti

### MUST

| ID | Requisito |
|----|-----------|
| **PROFILE-REQ-001** | Tabella `profiles`: `id` (= `auth.uid()`), `username`, `display_name`, `bio`, `avatar_url`, `pronouns`, `created_at`, `updated_at` |
| **PROFILE-REQ-002** | `username`: formato `^[a-z0-9_]{3,32}$`, univoco case-insensitive; impostato in **registrazione** — **non** modificabile da `ProfileScreen` Alpha |
| **PROFILE-REQ-003** | Email GoTrue: solo lettura in UI profilo; usata per login/recupero (#118) |
| **PROFILE-REQ-004** | Modifica profilo proprio: UPDATE diretto su `profiles` via RLS `profiles_update_own` (`id = auth.uid()`) |
| **PROFILE-REQ-005** | Campi editabili Alpha: `display_name` (obbligatorio), `bio`, `pronouns`, `avatar_url` |
| **PROFILE-REQ-006** | Avatar: upload bucket `avatars`, path `{userId}/avatar.{jpg\|png\|webp}`, max **2 MB**, URL pubblico; upsert sullo stesso path |
| **PROFILE-REQ-007** | Modello UI unificato **`ProfileSummary`**: `id`, `displayName`, `username?`, `avatarUrl?`, `pronouns?` — usato da sidebar, inbox (`ChatPeer`), `OpenAccount`, rubrica |
| **PROFILE-REQ-008** | Widget condivisi: `ProfileAvatar` (foto o iniziale colorata), `ProfileIdentityLines` (nome, `@username`, pronomi) |
| **PROFILE-REQ-009** | Dopo salvataggio: `AuthController.refreshProfile()` → aggiorna manifest account (`OpenAccount.profile`) |
| **PROFILE-REQ-010** | Peer in inbox: RPC `list_inbox()` espone `peer_avatar_url`, `peer_pronouns` (#134) |
| **PROFILE-REQ-011** | Risoluzione username → profilo: `find_profile_by_username` ritorna `avatar_url`, `pronouns` |

### SHOULD

| ID | Requisito |
|----|-----------|
| **PROFILE-REQ-012** | Stringhe opzionali (`bio`, `pronouns`) salvate come `null` se vuote dopo trim |
| **PROFILE-REQ-013** | Fallback avatar: `CircleAvatar` con iniziale da `display_name` e colore deterministico per `id` |
| **PROFILE-REQ-014** | `ProfileService.fetchSummariesByIds` per batch fetch profili pubblici |

### MUST NOT

| ID | Requisito |
|----|-----------|
| **PROFILE-REQ-015** | Esporre email in rubrica, ricerca profili o inbox |
| **PROFILE-REQ-016** | Modificare `username` da schermata profilo Alpha |
| **PROFILE-REQ-017** | Avatar fuori dalla cartella `auth.uid()` in bucket `avatars` |

---

## 3. Fuori scope

- Cambio username post-registrazione.
- Avatar privati / signed URL (Alpha: bucket pubblico `avatars`).
- Ricerca utenti (`search_profiles`) — backlog spec **CONTACTS**.
- Profilo federato esterno (`user@server`).
- Verifica username disponibilità (`check_username_available`) — flusso registrazione, non edit profilo.

---

## 4. Contratto

### 4.1 Backend

| Elemento | Comportamento |
|----------|---------------|
| `profiles` | RLS: SELECT authenticated; UPDATE solo propria riga |
| `profiles.pronouns` | Testo libero opzionale (#134) |
| Bucket `avatars` | Pubblico; MIME jpeg/png/webp; 2 MB; RLS cartella = `auth.uid()` |
| `list_inbox()` | Join `profiles` → `peer_avatar_url`, `peer_pronouns` |
| `find_profile_by_username` | Ritorna `id`, `username`, `display_name`, `avatar_url`, `pronouns` |

Migrazioni: `20260624200000_alfred_domain_schema.sql`, `20260628000000_profile_pronouns_avatars.sql`, `20260628100000_inbox_peer_profile_fields.sql`.

Nessuna RPC dedicata `update_profile` — client usa PostgREST `.from('profiles').update()`.

### 4.2 Client

| Componente | Responsabilità |
|------------|----------------|
| `ProfileSummary` | DTO unificato identità pubblica |
| `UserProfile` | Profilo completo (`summary` + `bio` + timestamp) |
| `ProfileService` | `updateProfile`, `findByUsername`, `fetchSummariesByIds` |
| `ProfileAvatarService` | `uploadAvatar` → URL pubblico |
| `ProfileController` | Stato save/upload; delega ai service |
| `ProfileScreen` | Form edit; picker immagine; email/username read-only |
| `OpenAccount.profile` | Snapshot in manifest multi-account |

### 4.3 UX profilo

| Campo | UI |
|-------|-----|
| Email | Read-only, disabilitato |
| Username | `@username` read-only sotto avatar |
| Nome visualizzato | Editabile |
| Pronomi | Editabile, hint esempi |
| Bio | Editabile, multilinea |
| Foto | Tap camera → file picker → upload + save |

### 4.4 Dove appare `ProfileSummary`

- `AccountSidebar` — account in focus e lista account
- `InboxPeerTile` — avatar + nome peer
- `ChatPanel` header — identità controparte (tap avatar → [PEER-PROFILE](./PEER-PROFILE.spec.md))
- `ChatPeer` — identità chat (con o senza storico inbox)
- Overlay peer — tap avatar → `PeerProfileOverlay` (allow + rubrica)

---

## 5. Tracciabilità

| REQ-ID | Verifica |
|--------|----------|
| PROFILE-REQ-001 | `schema_smoke.sql` — tabella `profiles`; migrazione `20260624200000_alfred_domain_schema.sql` |
| PROFILE-REQ-002, REQ-016 | `profile_screen.dart` — username read-only; registrazione `auth_screen.dart` |
| PROFILE-REQ-003 | `profile_screen.dart` — email disabilitata |
| PROFILE-REQ-004, REQ-005 | `profile_service.dart` — `.from('profiles').update()`; RLS in migrazioni domain |
| PROFILE-REQ-006, REQ-017 | `20260628000000_profile_pronouns_avatars.sql` — bucket + policy cartella `auth.uid()`; `profile_avatar_service.dart` |
| PROFILE-REQ-007 | `models_and_utils_test.dart` — `ProfileSummary.fromProfilesRow` |
| PROFILE-REQ-008, REQ-013 | `models_and_utils_test.dart` — `avatarColorForId`; `widgets/profile_identity.dart` |
| PROFILE-REQ-009 | `account_storage_test.dart` — `OpenAccount.profile` round-trip; `auth_controller.dart` `refreshProfile` |
| PROFILE-REQ-010 | `20260628100000_inbox_peer_profile_fields.sql`; `MAILBOX-INBOX.spec.md` REQ-003 |
| PROFILE-REQ-011 | `schema_smoke.sql` — `find_profile_by_username`; migrazione inbox peer fields |
| PROFILE-REQ-012 | `models_and_utils_test.dart` — `UserProfile.fromJson` (pronouns opzionali) |
| PROFILE-REQ-015 | `CONTACTS.spec.md`; RPC `search_profiles` / `list_inbox` — nessun campo email |

Gate: `cd client && bash scripts/verify.sh` · Manuale: modifica nome/pronomi/bio; upload avatar; verifica sidebar e inbox peer

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [alpha-full-stack.md](../../architecture/alpha-full-stack.md) | Panoramica |
| [MAILBOX-INBOX](./MAILBOX-INBOX.spec.md) | Campi peer in `list_inbox` |
| [AUTH-MULTI](./AUTH-MULTI.spec.md) | Manifest `OpenAccount.profile` |

**Codice**: `client/lib/models/profile_summary.dart`, `services/profile_service.dart`, `services/profile_avatar_service.dart`, `screens/profile_screen.dart`, `widgets/profile_identity.dart`
