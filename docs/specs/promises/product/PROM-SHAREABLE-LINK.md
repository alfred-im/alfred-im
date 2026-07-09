# PROM-SHAREABLE-LINK — Link condivisibili stabili

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-SHAREABLE-LINK` |
| **Classe** | PRODUCT |
| **Status** | `implemented` |
| **Ultima revisione** | 2026-07-09 |

Promessa di prodotto: **formato URL condivisibile e stabile** verso profilo pubblico di un peer Alfred (account utente o gruppo) e verso la conversazione con quel peer. Il contratto è il **fragment `#`**; come la app naviga internamente è conseguenza, non oggetto della promessa.

---

## 1. Problema / obiettivo

L'utente condivide un link che punta a una **risorsa** (profilo o chat con un indirizzo IM), indipendente dall'account Alfred di chi apre il link. Il formato resta valido nel tempo e funziona su qualsiasi host dell'app (hash obbligatorio — non dipende da rewrite server tipo GitHub Pages).

---

## 2. Formato canonico

```
{origine}{base-path}#{indirizzo}           → profilo del peer
{origine}{base-path}#{indirizzo}/chat     → conversazione con il peer
```

| Segmento | Regola |
|----------|--------|
| `{origine}{base-path}` | Dove è deployata l'istanza (es. demo GitHub Pages, localhost). **Non** fa parte dell'identità stabile della risorsa. |
| `#` | **Obbligatorio** — navigazione tramite fragment. |
| `{indirizzo}` | Identità IM del peer: `username` **oppure** `username@server` — **equivalenti**, entrambi sempre validi. |
| `/chat` | Suffisso opzionale: apre la conversazione con quel peer sull'account Alfred in focus. |

### Esempi

| Link | Destinazione |
|------|--------------|
| `https://alfred-im.github.io/XmppTest/#test2` | Profilo di `test2` |
| `https://alfred-im.github.io/XmppTest/#test2/chat` | Chat con `test2` |
| `…/#mario@alfred.app` | Stesso peer in forma `username@server` (server locale `alfred.app`) |

### Gruppi

Account gruppo (`profile_kind = group`): **stessa struttura** — `#nomegruppo` (profilo), `#nomegruppo/chat` (conversazione).

### Fuori dal contratto link

Navigazione personale **senza** link pubblici: rubrica, allow list, **schermata modifica profilo** ([SURF-PROFILE](../../surfaces/SURF-PROFILE.md)), inbox generica.

**Nota:** condividere il proprio `#username` dalla sidebar account attivo **è** nel contratto (PROM-SHAREABLE-LINK-023) — non va confuso con il link alla schermata di modifica profilo.

---

## 3. Promesse

### MUST — formato e semantica

| ID | Promessa |
|----|----------|
| **PROM-SHAREABLE-LINK-001** | Fragment `#` obbligatorio per ogni link condivisibile |
| **PROM-SHAREABLE-LINK-002** | `{indirizzo}` accetta **sia** `username` **sia** `username@server` — nessuna distinzione semantica tra i due formati |
| **PROM-SHAREABLE-LINK-003** | `#indirizzo` → profilo pubblico del peer (scheda identità: allow, rubrica, ecc. — vedi [PROM-PEER-PROFILE](./PROM-PEER-PROFILE.md)) |
| **PROM-SHAREABLE-LINK-004** | `#indirizzo/chat` → conversazione con quel peer sull'account in focus — [PROM-CHAT-PEER-KEY](./PROM-CHAT-PEER-KEY.md) |
| **PROM-SHAREABLE-LINK-005** | Il link identifica la **risorsa**, non l'account Alfred del visitatore — nessun segmento «account viewer» nell'URL |
| **PROM-SHAREABLE-LINK-006** | Peer/gruppo **inesistente** o indirizzo non risolvibile → **risorsa non trovata** (404 o equivalente UI) |
| **PROM-SHAREABLE-LINK-007** | Link condivisibile **non** espone `profile_id`, `thread_id` né altri id interni |

### MUST — apertura e multi-account

| ID | Promessa |
|----|----------|
| **PROM-SHAREABLE-LINK-010** | **0 account** nel manifest → overlay auth obbligatorio ([PROM-MULTI-ACCOUNT](./PROM-MULTI-ACCOUNT.md)); **non** esiste modalità guest |
| **PROM-SHAREABLE-LINK-011** | Dopo aggiunta del primo account da link → aprire la risorsa del fragment (profilo o chat) |
| **PROM-SHAREABLE-LINK-012** | **≥1 account** → shell normale; la risorsa del link si apre nell'account in focus |

### MUST — Condividi

| ID | Promessa |
|----|----------|
| **PROM-SHAREABLE-LINK-020** | Pulsante **Condividi** in alto a destra sulla **scheda profilo peer** (overlay) — utenti e gruppi |
| **PROM-SHAREABLE-LINK-021** | Tap Condividi → **condivisione di sistema** (`share_plus` / foglio Share nativo / Web Share API) con URL completo `#indirizzo` (link **profilo**, senza `/chat`) — **non** copia negli appunti come azione primaria |
| **PROM-SHAREABLE-LINK-022** | Condividi **solo** su scheda profilo peer e sidebar account attivo — **nessun** pulsante Condividi in chat |
| **PROM-SHAREABLE-LINK-023** | Sidebar account in focus: pulsante **Condividi** a sinistra di «Chiudi account» — share di sistema del link profilo attivo (`#indirizzo`) |

### SHOULD

| ID | Promessa |
|----|----------|
| **PROM-SHAREABLE-LINK-030** | URL generato «pulito»: forma canonica preferita per peer locali (es. `#test2` invece di varianti ridondanti) |
| **PROM-SHAREABLE-LINK-031** | Normalizzazione in ingresso (case, spazi) — dettaglio implementativo; il link in uscita resta pulito |

### MUST NOT

| ID | Promessa |
|----|----------|
| **PROM-SHAREABLE-LINK-040** | Link pubblici verso rubrica, allow list o schermata modifica profilo ([SURF-PROFILE](../../surfaces/SURF-PROFILE.md)) |
| **PROM-SHAREABLE-LINK-041** | Path senza `#` come contratto condivisibile |
| **PROM-SHAREABLE-LINK-042** | Segmento URL legato all'account in focus del visitatore |
| **PROM-SHAREABLE-LINK-043** | Usare **solo** clipboard al posto del foglio Condividi di sistema |

### Federazione

Federazione **in pausa** — vedi [address-based-messaging.md](../../../decisions/address-based-messaging.md). Indirizzi su server non raggiungibili da questa istanza: gestione come oggi (non oggetto di questa promessa oltre a **risorsa non trovata**).

---

## 4. Contratto implementativo (orientativo)

| Elemento | Responsabilità |
|----------|----------------|
| `shareable_link.dart` | Parse/build URL; `shareShareableProfileLink` → `SharePlus.instance.share` |
| `shareable_link_platform_*` | Lettura fragment e `hashchange` (web) |
| `ShareableLinkController` | Pending target, risoluzione profilo, stato `notFound` |
| `ShareableLinkListener` | Applica fragment; `handleIfReady` dopo `sessionReady` |
| `app_shell.dart` | Mostra `ShareableLinkNotFoundScreen` o shell con listener |
| Risoluzione indirizzo | `ProfileService.findByUsername` — `username` e `username@alfred.app` locale |
| Pending link | Conservare fragment fino a manifest con ≥1 account |
| `PeerProfileOverlay` | Pulsante Condividi alto a destra → share di sistema URL profilo |
| `AccountSidebar` | Condividi account attivo a sinistra di «Chiudi account» |
| Risorsa assente | `ShareableLinkNotFoundScreen` — «Risorsa non trovata» |

**Non vincolante:** sincronizzazione URL ↔ navigazione interna quando l'utente naviga senza Condividi.

---

## 5. Superfici conformi

| Superficie | Stato | File |
|------------|-------|------|
| SURF-PEER-PROFILE | `implemented` | [SURF-PEER-PROFILE.md](../../surfaces/SURF-PEER-PROFILE.md) — Condividi |
| SURF-CHAT | `implemented` | [SURF-CHAT.md](../../surfaces/SURF-CHAT.md) — apertura da `#…/chat` |
| SURF-AUTH | `implemented` | [SURF-AUTH.md](../../surfaces/SURF-AUTH.md) — pending link con 0 account |
| SURF-ACCOUNT-SIDEBAR | `implemented` | [SURF-ACCOUNT-SIDEBAR.md](../../surfaces/SURF-ACCOUNT-SIDEBAR.md) — Condividi account attivo |

---

## 6. Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| PROM-SHAREABLE-LINK-001, 002 | `shareable_link_test.dart` — parse fragment, equivalenza formati |
| PROM-SHAREABLE-LINK-003, 006 | Scenario manuale / widget — `#test2` apre profilo; indirizzo assente → non trovato |
| PROM-SHAREABLE-LINK-004 | Scenario manuale — `#test2/chat` apre chat |
| PROM-SHAREABLE-LINK-010, 011 | Scenario manuale — 0 account → auth → profilo linkato |
| PROM-SHAREABLE-LINK-020, 021, 022 | `peer_profile_overlay_test.dart` — Condividi → `ShareParams` |
| PROM-SHAREABLE-LINK-023 | `account_sidebar_test.dart` — Condividi account attivo → `ShareParams` |
| PROM-SHAREABLE-LINK-007, 040–043 | Review spec — assenza id interni, path viewer, no clipboard primario |

Gate (post-implementazione): `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh`

---

## 7. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [registry.md](../../registry.md) | Indice promesse |
| [PROM-CHAT-PEER-KEY](./PROM-CHAT-PEER-KEY.md) | Chiave conversazione per peer |
| [PROM-PEER-PROFILE](./PROM-PEER-PROFILE.md) | Scheda profilo peer |
| [PROM-MULTI-ACCOUNT](./PROM-MULTI-ACCOUNT.md) | Manifest, overlay auth, focus |
| [address-based-messaging.md](../../../decisions/address-based-messaging.md) | Indirizzo IM |
