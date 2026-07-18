## Descrizione

<!-- Cosa cambia e perché -->

## Modello (DDD / UML / Statechart)

- [ ] **Solo theme / refactor 1:1** — nessun cambio di comportamento nel modello
- [ ] **Modello aggiornato** — metodo: `docs/domain/README.md`

| Campo | Valore |
|-------|--------|
| Bounded context | <!-- es. navigation, messaging --> |
| `docs/domain/<context>/` | <!-- glossary, commands-and-events --> |
| `docs/model/uml/<context>/` | <!-- *-state.puml, seq-*.puml --> |
| `client/lib/machines/<context>/` | <!-- se UI a stati; altrimenti N/A --> |

Comandi / stati / transizioni toccati: <!-- es. FocusAccount, InboxVisible; oppure N/A -->

## Spec-Driven Development (SDD)

- [ ] **Solo cosmetica theme** (colori, spacing, font — nessuna promessa toccata)
- [ ] **Promesse aggiornate** — registro: `docs/specs/registry.md`

| Classe | ID promessa | Stato | File |
|--------|-------------|-------|------|
| SYSTEM / PRODUCT / SURFACE | <!-- es. PROM-LIST-FILTER, SURF-CONTACTS --> | `draft` \| `approved` \| `implemented` | <!-- path --> |

- ID toccati: <!-- es. PROM-LIST-FILTER-010, SURF-CONTACTS-001, SYS-MAILBOX-020, oppure N/A -->

## Verifica

- [ ] `cd client && bash scripts/verify.sh`
- [ ] `bash scripts/check-spec-sync.sh` (se toccate `docs/specs/` o `supabase/migrations/`)

## Registro

- [ ] `docs/specs/registry.md` aggiornato se nuove promesse o cambio stato
- [ ] `CHANGELOG.md` aggiornato se merge su `main` (vedi checklist post-merge in `docs/specs/README.md`)
