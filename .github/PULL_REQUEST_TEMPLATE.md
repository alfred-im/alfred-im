## Descrizione

<!-- Cosa cambia e perché -->

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
- [ ] `CHANGELOG.md` / `alpha-pr-registry.md` aggiornati se merge su `main`
