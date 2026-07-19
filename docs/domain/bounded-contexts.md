# Bounded context — Alfred

**Ultima revisione**: 2026-07-19

Ogni riga è un **contesto delimitato** (DDD): propri glossario, comandi/eventi e diagrammi UML. I contesti comunicano tramite comandi ed eventi espliciti, non logica condivisa implicita nel codice.

| Contesto | Stato | Cartella dominio | Cartella UML | Statechart client | Promesse SDD correlate (esempi) |
|----------|-------|------------------|--------------|-------------------|--------------------------------|
| **auth** | `verified` | [auth/](./auth/) | `docs/model/uml/auth/` | `client/lib/machines/auth/` | SURF-AUTH |
| **multi-account** | `verified` | [multi-account/](./multi-account/) | `docs/model/uml/multi-account/` | `client/lib/machines/multi-account/` | PROM-MULTI-ACCOUNT |
| **navigation** | `verified` | [navigation/](./navigation/) | `docs/model/uml/navigation/` | `client/lib/machines/navigation/` | PROM-SHAREABLE-LINK (ingresso) |
| **notifications** | `verified` | [notifications/](./notifications/) | `docs/model/uml/notifications/` | `client/lib/machines/notifications/` | PROM-PUSH-NOTIFY, SURF-NOTIFICATIONS |
| **shareable-link** | `verified` | [shareable-link/](./shareable-link/) | `docs/model/uml/shareable-link/` | `client/lib/machines/shareable-link/` | PROM-SHAREABLE-LINK |
| **messaging** | `verified` | [messaging/](./messaging/) | `docs/model/uml/messaging/` | `client/lib/machines/messaging/` | SYS-MAILBOX, PROM-MESSAGE-STATUS |
| **contacts** | `verified` | [contacts/](./contacts/) | `docs/model/uml/contacts/` | `client/lib/machines/contacts/` | PROM-PERSONAL-CONTACTS, SURF-CONTACTS |
| **profile** | `verified` | [profile/](./profile/) | `docs/model/uml/profile/` | `client/lib/machines/profile/` | PROM-PROFILE-IDENTITY, SURF-PROFILE |
| **reception** | `verified` | [reception/](./reception/) | `docs/model/uml/reception/` | `client/lib/machines/reception/` | SYS-RECEPTION, PROM-RECEPTION-FILTER |
| **groups** | `verified` | [groups/](./groups/) | `docs/model/uml/groups/` | `client/lib/machines/groups/` | SYS-GROUP |
| **media** | `documented` | [media/](./media/) | `docs/model/uml/media/` | no (UI allegati chat) | PROM-CHAT-MEDIA |
| **delivery** | `documented` | [delivery/](./delivery/) | `docs/model/uml/delivery/` | no | SYS-DELIVERY |
| **federation** | `documented` | [federation/](./federation/) | `docs/model/uml/federation/` | no | bridge futuri |

Mappa relazioni: [context-map.puml](../model/context-map.puml).

## Dipendenze principali (solo riferimento)

```text
notifications ──OpenFromPushTap──► navigation
shareable-link ──OpenFromShareableLink──► navigation
navigation ──FocusAccount──► multi-account
multi-account ──sessione──► auth
messaging ──RPC──► reception, delivery
groups ──broadcast/owner──► delivery, reception
federation ──outbox queued──► delivery (consumer bridge stub)
```

## Stato modellazione

Tre livelli di maturità per contesto (governance — vedi [README.md](./README.md)):

| Stato | Significato | Gate `check-model-sync.sh` |
|-------|-------------|----------------------------|
| `documented` | Glossario, comandi/eventi e almeno un diagramma UML; statechart assente o solo mirror non cablato in produzione | nessun vincolo su macchina/test |
| `wired` | Statechart in `client/lib/machines/<context>/` usato dal runtime client | richiede dominio + UML + directory macchina |
| `verified` | `wired` + test unitari transizioni in `client/test/unit/<context>_machine_test.dart` | come `wired` + file test |

Contesti **`verified`** (produzione): auth, multi-account, navigation, notifications, shareable-link, messaging, contacts, profile, reception, groups.

Contesti **`documented`** (mirror o server-only, cablaggio futuro): media, delivery, federation.
