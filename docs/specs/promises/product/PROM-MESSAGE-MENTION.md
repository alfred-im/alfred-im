# PROM-MESSAGE-MENTION — Tag `@username` in messaggi

| Campo | Valore |
|-------|--------|
| **Promessa ID** | `PROM-MESSAGE-MENTION` |
| **Classe** | PRODUCT |
| **Status** | `approved` |
| **Ultima revisione** | 2026-08-02 |

Promessa di prodotto: nel **rendering** del body testo, sequenze `@username` valide sono link che aprono la conversazione 1:1 con quel peer. Il body persistito resta testo puro; nessuna struttura mention nel DB.

---

## 1. Problema / obiettivo

L'utente può citare un account Alfred con `@username` nel messaggio; chi legge può aprire la chat con quel peer con un tap, come da compose o link condivisibile.

---

## 2. Promesse

### MUST

| ID | Promessa |
|----|----------|
| **PROM-MESSAGE-MENTION-001** | Nel body testo mostrato in bolla, `@username` con username valido (`AuthIdentity.isValidUsername`, 3–32 `[a-z0-9_]`) è link cliccabile (mittente e destinatario) |
| **PROM-MESSAGE-MENTION-002** | Tap sul link → conversazione 1:1 con quel peer sull'account Alfred in focus — stesso percorso di compose (`resolveAddress` + `openConversation`) |
| **PROM-MESSAGE-MENTION-003** | `@` dentro indirizzi email (`local@domain`) **non** è tag — no link su `@gmail` in `mario@gmail.com` |
| **PROM-MESSAGE-MENTION-004** | Peer/username non risolvibile → **risorsa non trovata** (stessa UI di link condivisibile inesistente: `ShareableLinkNotFoundScreen` / «Risorsa non trovata») |
| **PROM-MESSAGE-MENTION-005** | Nel **messaggio proprio** (`isMine`), `@` del **username dell'account in focus** non è link per chi lo legge come mittente; per altri lettori è link come ogni altro tag valido |
| **PROM-MESSAGE-MENTION-006** | Stesso rendering in chat 1:1 e chat gruppo (`MessageBubble` condiviso) |
| **PROM-MESSAGE-MENTION-007** | Account gruppo come target: `@nomegruppo` risolvibile come ogni username Alfred (user o group) |

### SHOULD

| ID | Promessa |
|----|----------|
| **PROM-MESSAGE-MENTION-010** | Anteprima inbox: testo grezzo con `@username` (nessun link in lista) — coerente con SURF-CHAT-008 |

### MUST NOT

| ID | Promessa |
|----|----------|
| **PROM-MESSAGE-MENTION-020** | Persistire markup o entità mention separata dal body testo |
| **PROM-MESSAGE-MENTION-021** | Username corto o invalido (`@ab`, `@bad-name`) come link — stesse regole di iscrizione |

---

## 3. Modello (riferimento)

| Elemento | Artefatto |
|----------|-----------|
| Glossario | [docs/domain/messaging/glossary.md](../../../domain/messaging/glossary.md) — mention display-only |
| Navigazione | [navigation](../../../domain/navigation/) — riuso `OpenFromCompose` / `openPeerOnFocusedAccount` |
| Statechart messaging | Nessuna nuova transizione — solo presentazione |

---

## 4. Superfici conformi

| Superficie | Stato | File |
|------------|-------|------|
| SURF-CHAT | `implemented` | [SURF-CHAT.md](../../surfaces/SURF-CHAT.md) |
| SURF-GROUP-CONVERSATION | `implemented` | [SURF-GROUP-CONVERSATION.md](../../surfaces/SURF-GROUP-CONVERSATION.md) |

---

## 5. Tracciabilità

| PROM-ID | Verifica |
|---------|----------|
| PROM-MESSAGE-MENTION-001–003 | `mention_text_test.dart` |
| PROM-MESSAGE-MENTION-004 | `mention_navigation` + scenario manuale |
| PROM-MESSAGE-MENTION-005 | `mention_text_test.dart`, `message_bubble_test.dart` |
| PROM-MESSAGE-MENTION-006 | `message_bubble_test.dart` (bolle condivise) |

---

## 6. Riferimenti

| Documento | Ruolo |
|-----------|--------|
| [PROM-SHAREABLE-LINK](./PROM-SHAREABLE-LINK.md) | UI «risorsa non trovata» |
| [PROM-CHAT-PEER-KEY](./PROM-CHAT-PEER-KEY.md) | Apertura chat per peer |
| [registry.md](../registry.md) | Indice promesse |
