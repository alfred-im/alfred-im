# PROM-SHAREABLE-LINK — Link condivisibili stabili

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-SHAREABLE-LINK` |
| **Classe** | PRODUCT |
| **Status** | `approved` |
| **Ultima revisione** | 2026-09-13 |
| **PR origine** | #178 |
| **Amend** | equivalenza a strati §7.13–7.14 — distillazione [TEMP-chat-peer-key-address-drift.md](../../../tmp/TEMP-chat-peer-key-address-drift.md) §7 |

Promessa di prodotto: **formato URL condivisibile e stabile** verso profilo pubblico di un peer Alfred (account utente o gruppo) e verso la conversazione con quel peer. Il contratto è il **fragment `#`**; come la app naviga internamente è conseguenza, non oggetto della promessa.

---

## 1. Problema / obiettivo

L'utente condivide un link che punta a una **risorsa** (profilo o chat con un indirizzo IM), indipendente dall'account Alfred di chi apre il link. Il formato resta valido nel tempo e funziona su qualsiasi host dell'app (hash obbligatorio — non dipende da rewrite server).

---

## 2. Formato canonico

```
{origine}{base-path}#{indirizzo}           → profilo del peer
{origine}{base-path}#{indirizzo}/chat     → conversazione con il peer
```

| Segmento | Regola |
|----------|--------|
| `{origine}{base-path}` | Dove è deployata l'istanza (es. demo Fly, localhost). **Non** fa parte dell'identità stabile della risorsa. |
| `#` | **Obbligatorio** — navigazione tramite fragment. |
| `{indirizzo}` | Identità IM del peer: `username` **oppure** `username@server` — entrambi validi in ingresso. |
| `/chat` | Suffisso opzionale: apre la conversazione con quel peer sull'account Alfred in focus. |

### Esempi

| Link | Destinazione |
|------|--------------|
| `https://arkham-im.fly.dev/#test2` | Profilo di `test2` (istanza Arkham) |
| `https://arkham-im.fly.dev/#test2/chat` | Chat con `test2` (istanza Arkham) |
| `https://blackgate-im.fly.dev/#mario` | Profilo di `mario` (istanza Blackgate) |
| `https://blackgate-im.fly.dev/#mario/chat` | Chat con `mario` (istanza Blackgate) |
| `…/#mario@blackgate-im.fly.dev` | Profilo peer su altra istanza |
| `…/#mario@blackgate-im.fly.dev/chat` | Chat con peer su altra istanza |

### Gruppi

Account gruppo (`profile_kind = group`): **stessa struttura** — `#nomegruppo` (profilo), `#nomegruppo/chat` (conversazione).

### Fuori dal contratto link

Navigazione personale **senza** link pubblici: rubrica, allow list, **schermata modifica profilo** ([SURF-PROFILE](../../surfaces/SURF-PROFILE.md)), inbox generica.

**Nota:** condividere il proprio `#username` dalla sidebar account attivo **è** nel contratto (PROM-SHAREABLE-LINK-023) — non va confuso con il link alla schermata di modifica profilo.

---

## 3. Equivalenza a strati (link vs chiave messaggistica)

Due livelli distinti — **non** contraddizione da ridiscutere:

| Livello | `mario` vs `mario@mio_server` |
|---------|-------------------------------|
| **Link / lookup profilo locale** | Entrambe valide; se `@server` = istanza corrente, stesso profilo (`shareable_link.dart`: stesso `localUsername`, `normalizedAddress` può differire) |
| **Chiave `peer_address` / allow list / inbox / storico** | **Distinte** — stringhe diverse = conversazioni diverse — vedi [PROM-CHAT-PEER-KEY](./PROM-CHAT-PEER-KEY.md) §2 |
| **Link in uscita (Condividi)** | Forma canonica preferita: bare `username` (`canonicalShareableAddress`, PROM-SHAREABLE-LINK-030) |

Amend esplicito: non unificare i due livelli.

---

## 4. Promesse

### MUST — formato e semantica

| ID | Promessa |
|----|----------|
| **PROM-SHAREABLE-LINK-001** | Fragment `#` obbligatorio per ogni link condivisibile |
| **PROM-SHAREABLE-LINK-002** | `{indirizzo}` accetta **sia** `username` **sia** `username@server` — per **link e lookup profilo locale**, entrambe valide; per **chiave messaggistica** (`peer_address`), le forme sono **distinte** — vedi §3 |
| **PROM-SHAREABLE-LINK-003** | `#indirizzo` → profilo pubblico del peer (scheda identità: allow, rubrica, ecc. — vedi [PROM-PEER-PROFILE](./PROM-PEER-PROFILE.md)) |
| **PROM-SHAREABLE-LINK-004** | `#indirizzo/chat` → conversazione con quel peer sull'account in focus — [PROM-CHAT-PEER-KEY](./PROM-CHAT-PEER-KEY.md); **non** lasciare visibile chat con altro peer |
| **PROM-SHAREABLE-LINK-005** | Il link identifica la **risorsa**, non l'account Alfred del visitatore — nessun segmento «account viewer» nell'URL |
| **PROM-SHAREABLE-LINK-006** | Indirizzo **malformato** o peer **inesistente** (lookup locale fallito e nessun profilo federato) → **risorsa non trovata** (404 o equivalente UI). **Non** 404 solo perché il peer non ha `profiles.id` locale — indirizzi `user@other-server` validi aprono profilo/chat con fallback indirizzo grezzo finché wire profilo federato non è live |
| **PROM-SHAREABLE-LINK-007** | Link condivisibile **non** espone `profile_id`, `thread_id` né altri id interni |
| **PROM-SHAREABLE-LINK-008** | Apertura da fragment: `peer_address` dal fragment → chat/overlay; `get_profiles([…])` in async; fallback indirizzo grezzo |

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
| **PROM-SHAREABLE-LINK-021** | Tap Condividi → **condivisione di sistema** (foglio Share nativo / Web Share API) con URL completo `#indirizzo` (link **profilo**, senza `/chat`) — **non** copia negli appunti come azione primaria |
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
| **PROM-SHAREABLE-LINK-044** | `#indirizzo/chat` che lascia visibile chat con peer diverso da quello linkato |
| **PROM-SHAREABLE-LINK-045** | Rifiutare indirizzi `user@other-server` solo perché assenti da `profiles` locale |

---

## 5. Modello (riferimento)

| Elemento | Artefatto |
|----------|-----------|
| Glossario / comandi | [docs/domain/shareable-link/](../../../domain/shareable-link/) |
| UML | [docs/model/uml/shareable-link/](../../../model/uml/shareable-link/) — [seq-open-from-fragment.puml](../../../model/uml/shareable-link/seq-open-from-fragment.puml) |
| Statechart client | [client/lib/machines/shareable-link/](../../../../client/lib/machines/shareable-link/) |
| Apertura chat da link | `OpenSharedChat` → `OpenFromShareableLink` (navigation) — vedi [docs/domain/shareable-link/README.md](../../../domain/shareable-link/README.md) |

**Implementazione (non vincolante):** [docs/guides/shareable-link.md](../../../guides/shareable-link.md)

---

## 6. Superfici conformi

| Superficie | Stato | File |
|------------|-------|------|
| SURF-PEER-PROFILE | `approved` | [SURF-PEER-PROFILE.md](../../surfaces/SURF-PEER-PROFILE.md) — Condividi |
| SURF-CHAT | `approved` | [SURF-CHAT.md](../../surfaces/SURF-CHAT.md) — apertura da `#…/chat` |
| SURF-AUTH | `implemented` | [SURF-AUTH.md](../../surfaces/SURF-AUTH.md) — pending link con 0 account |
| SURF-ACCOUNT-SIDEBAR | `implemented` | [SURF-ACCOUNT-SIDEBAR.md](../../surfaces/SURF-ACCOUNT-SIDEBAR.md) — Condividi account attivo |

---

## 7. Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| PROM-SHAREABLE-LINK-001, 002 | `shareable_link_test.dart` — parse fragment, equivalenza formati link |
| PROM-SHAREABLE-LINK-003, 006, 008, 045 | Scenario manuale / widget — `#test2` apre profilo; `#mario@other-server` apre con fallback; indirizzo malformato → non trovato |
| PROM-SHAREABLE-LINK-004 | Scenario manuale — `#test2/chat` apre chat; `shareable_link_stale_chat_verification_test.dart` |
| PROM-SHAREABLE-LINK-010, 011 | Scenario manuale — 0 account → auth → profilo linkato |
| PROM-SHAREABLE-LINK-020, 021, 022 | `peer_profile_overlay_test.dart` — Condividi → `ShareParams` |
| PROM-SHAREABLE-LINK-023 | `account_sidebar_test.dart` — Condividi account attivo → `ShareParams` |
| PROM-SHAREABLE-LINK-007, 040–043 | Review spec — assenza id interni, path viewer, no clipboard primario |

Gate (post-implementazione): `bash scripts/check-spec-sync.sh` + `cd client && bash scripts/verify.sh`

---

## 8. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [registry.md](../../registry.md) | Indice promesse |
| [PROM-CHAT-PEER-KEY](./PROM-CHAT-PEER-KEY.md) | Chiave conversazione per `peer_address` |
| [PROM-PEER-PROFILE](./PROM-PEER-PROFILE.md) | Scheda profilo peer |
| [PROM-MULTI-ACCOUNT](./PROM-MULTI-ACCOUNT.md) | Manifest, overlay auth, focus |
| [address-based-messaging.md](../../../decisions/address-based-messaging.md) | Indirizzo IM |
