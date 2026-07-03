# PROFILE — Profilo utente Alfred

| Campo | Valore |
|-------|--------|
| **Spec ID** | `PROFILE` |
| **Layer** | capability |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-03 |
| **ADR** | — (identità pubblica username: PR #118) |
| **PR** | #118 (username/email), #134 (avatar, pronomi, `ProfileSummary`) |
| **Correlata** | [MSG-INBOX](./MSG-INBOX.spec.md), [AUTH-MULTI](./AUTH-MULTI.spec.md) |

Documento per AI — contratto profilo Alfred: dati pubblici, modifica self-service, avatar, esposizione in UI.

---

## 1. Problema / obiettivo

Ogni utente Alfred ha un profilo pubblico (`profiles`) legato 1:1 a `auth.users`. L’utente modifica nome visualizzato, bio, pronomi e foto; **username** e **email** sono identità stabili (non editabili in schermata profilo). I dati pubblici compaiono in sidebar, inbox, chat e manifest multi-account.

---

## 2. Requisiti

### MUST

- Tabella `profiles`: `id` (= `auth.uid()`), `username`, `display_name`, `bio`, `avatar_url`, `pronouns`, `created_at`, `updated_at`.
- `username`: formato `^[a-z0-9_]{3,32}$`, univoco case-insensitive; impostato in **registrazione** — **non** modificabile da `ProfileScreen` Alpha.
- Email GoTrue: solo lettura in UI profilo; usata per login/recupero (#118).
- Modifica profilo proprio: UPDATE diretto su `profiles` via RLS `profiles_update_own` (`id = auth.uid()`).
- Campi editabili Alpha: `display_name` (obbligatorio), `bio`, `pronouns`, `avatar_url`.
- Avatar: upload bucket `avatars`, path `{userId}/avatar.{jpg|png|webp}`, max **2 MB**, URL pubblico; upsert sullo stesso path.
- Modello UI unificato **`ProfileSummary`**: `id`, `displayName`, `username?`, `avatarUrl?`, `pronouns?` — usato da sidebar, inbox (`ChatPeer`), `OpenAccount`, rubrica.
- Widget condivisi: `ProfileAvatar` (foto o iniziale colorata), `ProfileIdentityLines` (nome, `@username`, pronomi).
- Dopo salvataggio: `AuthController.refreshProfile()` → aggiorna manifest account (`OpenAccount.profile`).
- Peer in inbox: RPC `list_inbox()` espone `peer_avatar_url`, `peer_pronouns` (#134).
- Risoluzione username → profilo: `find_profile_by_username` ritorna `avatar_url`, `pronouns`.

### SHOULD

- Stringhe opzionali (`bio`, `pronouns`) salvate come `null` se vuote dopo trim.
- Fallback avatar: `CircleAvatar` con iniziale da `display_name` e colore deterministico per `id`.
- `ProfileService.fetchSummariesByIds` per batch fetch profili pubblici.

### MUST NOT

- Esporre email in rubrica, ricerca profili o inbox.
- Modificare `username` da schermata profilo Alpha.
- Avatar fuori dalla cartella `auth.uid()` in bucket `avatars`.

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
- `ChatPanel` header — identità controparte
- `ChatPeer` — identità chat (con o senza storico inbox)

---

## 5. Verifica

| Tipo | Riferimento |
|------|-------------|
| Gate | `cd client && bash scripts/verify.sh` |
| Manuale | Modifica nome/pronomi/bio; upload avatar; verifica sidebar e inbox peer |

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [alpha-full-stack.md](../../architecture/alpha-full-stack.md) | Panoramica |
| [MSG-INBOX](./MSG-INBOX.spec.md) | Campi peer in `list_inbox` |
| [AUTH-MULTI](./AUTH-MULTI.spec.md) | Manifest `OpenAccount.profile` |

**Codice**: `client/lib/models/profile_summary.dart`, `services/profile_service.dart`, `services/profile_avatar_service.dart`, `screens/profile_screen.dart`, `widgets/profile_identity.dart`
