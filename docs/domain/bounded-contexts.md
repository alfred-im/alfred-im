# Bounded context — Alfred

**Ultima revisione**: 2026-07-18

Ogni riga è un **contesto delimitato** (DDD): propri glossario, comandi/eventi e diagrammi UML. I contesti comunicano tramite comandi ed eventi espliciti, non logica condivisa implicita nel codice.

| Contesto | Cartella dominio | Cartella UML | Statechart client | Promesse SDD correlate (esempi) |
|----------|------------------|--------------|-------------------|--------------------------------|
| **auth** | [auth/](./auth/) | `docs/model/uml/auth/` | `client/lib/machines/auth/` | SURF-AUTH |
| **multi-account** | [multi-account/](./multi-account/) | `docs/model/uml/multi-account/` | `client/lib/machines/multi-account/` | PROM-MULTI-ACCOUNT |
| **navigation** | [navigation/](./navigation/) | `docs/model/uml/navigation/` | `client/lib/machines/navigation/` | PROM-SHAREABLE-LINK (ingresso) |
| **messaging** | [messaging/](./messaging/) | `docs/model/uml/messaging/` | opzionale | SYS-MAILBOX, PROM-MESSAGE-STATUS |
| **reception** | [reception/](./reception/) | `docs/model/uml/reception/` | no | SYS-RECEPTION, PROM-RECEPTION-FILTER |
| **delivery** | [delivery/](./delivery/) | `docs/model/uml/delivery/` | no | SYS-DELIVERY |
| **contacts** | [contacts/](./contacts/) | `docs/model/uml/contacts/` | opzionale | PROM-PERSONAL-CONTACTS, SURF-CONTACTS |
| **groups** | [groups/](./groups/) | `docs/model/uml/groups/` | opzionale | SYS-GROUP |
| **media** | [media/](./media/) | `docs/model/uml/media/` | opzionale | PROM-CHAT-MEDIA |
| **notifications** | [notifications/](./notifications/) | `docs/model/uml/notifications/` | adapter → navigation | PROM-PUSH-NOTIFY, SURF-NOTIFICATIONS |
| **shareable-link** | [shareable-link/](./shareable-link/) | `docs/model/uml/shareable-link/` | adapter → navigation | PROM-SHAREABLE-LINK |
| **profile** | [profile/](./profile/) | `docs/model/uml/profile/` | opzionale | PROM-PROFILE-IDENTITY, SURF-PROFILE |
| **federation** | [federation/](./federation/) | `docs/model/uml/federation/` | no | bridge futuri |

## Dipendenze principali (solo riferimento)

```text
notifications ──OpenFromPushTap──► navigation
shareable-link ──OpenFromShareableLink──► navigation
navigation ──FocusAccount──► multi-account
multi-account ──sessione──► auth
messaging ──RPC──► reception, delivery
```

## Stato modellazione

| Stato | Significato |
|-------|-------------|
| `scheletro` | Cartella creata; glossario e UML da compilare |
| `draft` | Modello in bozza |
| `approved` | Modello congelato — si implementa |
| `implemented` | Codice allineato al modello su `main` |

Tutti i contesti sono **`scheletro`** tranne **notifications**, **multi-account** e **navigation** (`implemented`).
