# Bug Fixes (Riferimento Tecnico)

Fix documentati per il client Flutter Alpha.

| File | PR | Problema |
|------|-----|----------|
| [flutter-inbox-stability.md](./flutter-inbox-stability.md) | #113, #114, #140, #152 | Inbox bloccata su auth race; provider; evoluzione multi-account |
| [auth-bootstrap-gotrue-revoke.md](./auth-bootstrap-gotrue-revoke.md) | #142 | Bootstrap `signOut` revoca refresh token; PKCE senza storage |
| [multi-account-chat-persistence-pr143.md](./multi-account-chat-persistence-pr143.md) | #143 | Logout locale, view per account, test regressione |
| [multi-account-single-active-gotrue-pr152.md](./multi-account-single-active-gotrue-pr152.md) | #152 | Inbox errata al switch web; una GoTrue attiva |

Architettura e testing: `docs/architecture/alpha-full-stack.md` §5.
