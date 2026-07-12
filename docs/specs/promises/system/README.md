# Promesse SYSTEM — piattaforma

**Ultima revisione**: 2026-07-12

Le promesse **SYSTEM** sono il contratto tra client, piattaforma Supabase e bridge. Panoramica repository: [`README.md`](../../../../README.md). Il dettaglio backend resta nei documenti canonici sotto.

---

## Documenti canonici

| Documento | Contenuto |
|-----------|-----------|
| [../../contracts/schema.md](../../contracts/schema.md) | Tabelle, colonne, enum, RLS, bucket storage, vincoli |
| [../../contracts/rpc.md](../../contracts/rpc.md) | Firme RPC, parametri, semantica, mapping client |

Ogni modifica a schema o RPC **deve** aggiornare questi contratti e la promessa SYSTEM correlata (`SYS-*`).

---

## Promesse SYSTEM

| ID | File | Dominio |
|----|------|---------|
| SYS-MAILBOX | [SYS-MAILBOX.md](./SYS-MAILBOX.md) | Archivio, invio, inbox, lettura |
| SYS-GROUP | [SYS-GROUP.md](./SYS-GROUP.md) | Account gruppo, partecipazione, erogazione |
| SYS-PROFILE | [SYS-PROFILE.md](./SYS-PROFILE.md) | Profilo utente, avatar, RLS |
| SYS-CONTACTS | [SYS-CONTACTS.md](./SYS-CONTACTS.md) | Rubrica, `search_profiles` |
| SYS-RECEPTION | [SYS-RECEPTION.md](./SYS-RECEPTION.md) | Allow list, gate recapito |
| SYS-ACCOUNT-BOUNDARY | [SYS-ACCOUNT-BOUNDARY.md](./SYS-ACCOUNT-BOUNDARY.md) | Confine account (legge madre) |
| SYS-DELIVERY | [SYS-DELIVERY.md](./SYS-DELIVERY.md) | Outbox + worker delivery |

Indice completo: [registry.md](../../registry.md).

---

## Verifica

- Smoke SQL: `supabase/tests/*.sql`
- Gate: `bash scripts/check-spec-sync.sh`
- Integrazione live: `cd client && bash scripts/test.sh integration`

---

## Nuovo lavoro backend

1. Classificare quale promessa SYSTEM è toccata (o crearne una nuova in `draft`).
2. Aggiornare `contracts/schema.md` e/o `contracts/rpc.md`.
3. Aggiornare il file `SYS-*.md` con ID promessa e tracciabilità.
4. Nuovo lavoro **UX cross-cutting**: promessa PRODUCT + SURFACE (non duplicare regole in contratti).
