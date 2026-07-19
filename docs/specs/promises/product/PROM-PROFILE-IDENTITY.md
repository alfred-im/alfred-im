# PROM-PROFILE-IDENTITY — Identità pubblica in UI

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-PROFILE-IDENTITY` |
| **Classe** | PRODUCT |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-19 |
| **PR origine** | #118 (username/email), #134 (avatar, pronomi, `ProfileSummary`) |

Promessa di prodotto: modello e widget condivisi per identità pubblica (`ProfileSummary`) su sidebar, inbox, chat, manifest multi-account e rubrica.

---

## 1. Problema / obiettivo

L'utente riconosce persone e account con nome, username, pronomi e avatar coerenti in tutta l'app. Dopo modifica profilo proprio, l'identità in sidebar e manifest si aggiorna senza riavvio.

Schema backend (`profiles`, bucket `avatars`): [SYS-PROFILE](../system/SYS-PROFILE.md) e [contracts/schema.md](../../contracts/schema.md).

---

## 2. Promesse

### MUST

| ID | Promessa |
|----|----------|
| **PROM-PROFILE-IDENTITY-001** | Identità pubblica unificata (id, nome, username opzionale, avatar, pronomi) — coerente in sidebar, inbox, manifest multi-account e rubrica |
| **PROM-PROFILE-IDENTITY-002** | Widget condivisi per avatar (foto o iniziale) e righe identità (nome, username, pronomi) |
| **PROM-PROFILE-IDENTITY-003** | Dopo salvataggio profilo proprio: identità aggiornata in sidebar e manifest senza riavvio app |
| **PROM-PROFILE-IDENTITY-004** | Peer in inbox: campi profilo peer (`peer_avatar_url`, `peer_pronouns`) da `list_inbox()` |
| **PROM-PROFILE-IDENTITY-005** | Risoluzione username → profilo: `find_profile_by_username` ritorna `avatar_url`, `pronouns` |

### SHOULD

| ID | Promessa |
|----|----------|
| **PROM-PROFILE-IDENTITY-010** | Stringhe opzionali (`bio`, `pronouns`) salvate come `null` se vuote dopo trim |
| **PROM-PROFILE-IDENTITY-011** | Fallback avatar: `CircleAvatar` con iniziale da `display_name` e colore deterministico per `id` |
| **PROM-PROFILE-IDENTITY-012** | `ProfileService.fetchSummariesByIds` per batch fetch profili pubblici |

### MUST NOT

| ID | Promessa |
|----|----------|
| **PROM-PROFILE-IDENTITY-020** | Esporre email in rubrica, ricerca profili o inbox |
| **PROM-PROFILE-IDENTITY-021** | Modificare `username` da schermata profilo (scope attuale) |

---


## 3. Modello (riferimento)

| Elemento | Artefatto |
|----------|-----------|
| Glossario / comandi | [docs/domain/profile/](../../../domain/profile/) |
| UML | [docs/model/uml/profile/](../../model/uml/profile/) |
| Statechart client | [client/lib/machines/profile/](../../../client/lib/machines/profile/) |

**Implementazione (non vincolante):** [docs/domain/profile/README.md](../../../domain/profile/README.md) · schema: [SYS-PROFILE](../system/SYS-PROFILE.md)


## 4. Superfici conformi

| Superficie | Stato | File |
|------------|-------|------|
| SURF-INBOX | `implemented` | [SURF-INBOX.md](../../surfaces/SURF-INBOX.md) — tile peer |
| SURF-CONTACTS | `implemented` | [SURF-CONTACTS.md](../../surfaces/SURF-CONTACTS.md) |
| SURF-ALLOWLIST | `implemented` | [SURF-ALLOWLIST.md](../../surfaces/SURF-ALLOWLIST.md) |
| Profilo proprio | `implemented` | `profile_screen.dart` |
| Shell sidebar | `implemented` | `account_sidebar.dart` |

---

## 5. Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| PROM-PROFILE-IDENTITY-001 | `models_and_utils_test.dart` — `ProfileSummary.fromProfilesRow` |
| PROM-PROFILE-IDENTITY-002, 011 | `models_and_utils_test.dart` — `avatarColorForId`; `profile_identity.dart` |
| PROM-PROFILE-IDENTITY-003 | `account_storage_test.dart`; `auth_controller.dart` `refreshProfile` |
| PROM-PROFILE-IDENTITY-004 | `20260628100000_inbox_peer_profile_fields.sql`; [SYS-MAILBOX](../system/SYS-MAILBOX.md) |
| PROM-PROFILE-IDENTITY-005 | `schema_smoke.sql` — `find_profile_by_username` |
| PROM-PROFILE-IDENTITY-010 | `models_and_utils_test.dart` — `UserProfile.fromJson` |
| PROM-PROFILE-IDENTITY-020 | [SYS-CONTACTS](../system/SYS-CONTACTS.md); RPC senza campo email |


Gate: `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh`

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [registry.md](../../registry.md) | Indice promesse |
| [SYS-PROFILE](../system/SYS-PROFILE.md) | Schema backend |
| [SURF-PROFILE](../../surfaces/SURF-PROFILE.md) | Binding superficie |
| [PROM-MULTI-ACCOUNT](./PROM-MULTI-ACCOUNT.md) | Manifest `OpenAccount.profile` |
| [PROM-PEER-PROFILE](./PROM-PEER-PROFILE.md) | Overlay identità peer |
