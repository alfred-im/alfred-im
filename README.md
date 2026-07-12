# Alfred

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)
[![CI](https://github.com/alfred-im/alfred-im/actions/workflows/deploy-pages.yml/badge.svg)](https://github.com/alfred-im/alfred-im/actions/workflows/deploy-pages.yml)
[![Spec sync](https://github.com/alfred-im/alfred-im/actions/workflows/spec-sync.yml/badge.svg)](https://github.com/alfred-im/alfred-im/actions/workflows/spec-sync.yml)
[![Flutter](https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter&logoColor=white)](https://flutter.dev)

**Consent-first open-source messaging.**

*No message is delivered until the recipient has explicitly allowed the sender.*

Flutter web (PWA) · Supabase · Python bridges (federation planned)

**Try it:** https://alfred-im.github.io/alfred-im/

---

## Table of contents

- [About](#about)
- [Features](#features)
- [Architecture](#architecture)
- [Repository structure](#repository-structure)
- [Getting started](#getting-started)
- [Development](#development)
- [Testing](#testing)
- [Contributing](#contributing)
- [Documentation](#documentation)
- [Roadmap](#roadmap)
- [Security](#security)
- [License](#license)

---

## About

Alfred is open-source messaging software delivered as a **Flutter web app** (installable as a **PWA** on desktop and mobile browsers). Users are identified by **username**; conversations are **address-based**.

**Consent comes first:** each account controls who may reach them through a personal allow list. Senders who are not allowed are not delivered to — there is no silent inbox from unknown parties.

Alfred is **feminist-informed** software: consent, agency, and clear boundaries are architectural choices, not marketing copy. The allow list is how those values are enforced in the product — not an optional privacy mode.

The client talks to a Supabase platform layer (Postgres, Auth, Realtime, Storage). Native mobile or desktop builds are not a project focus today; the web client is the supported surface.

---

## Features

| Area | Status |
|------|--------|
| Email + password auth with public **username** | ✅ |
| **Multi-account** support | ✅ |
| Inbox + realtime chat (text, GIF, voice, location) | ✅ |
| Personal contacts (optional) | ✅ |
| **Allow list** — consent-based delivery | ✅ |
| Peer profiles and shareable `#username` links | ✅ |
| **Group accounts** | ✅ |
| Message delivery status (✓ / ✓✓) | ✅ |
| XMPP / Matrix federation | Planned (bridge stubs today) |

---

## Architecture

```
┌─────────────────────────────┐
│   Flutter web client (PWA)  │
└──────────────┬──────────────┘
               │ HTTPS
┌──────────────▼──────────────┐
│   Supabase platform         │
└──────────────┬──────────────┘
               │ (planned)
┌──────────────▼──────────────┐
│   bridge-xmpp / bridge-matrix│
└─────────────────────────────┘
```

Bridges are **stateless**; platform state lives in Supabase.

---

## Repository structure

```
.
├── client/           # Flutter application
├── supabase/         # Migrations and platform config
├── bridge-xmpp/      # XMPP bridge (stub)
├── bridge-matrix/    # Matrix bridge (stub)
├── docs/             # Technical documentation
├── PROJECT_MAP.md    # Detailed project map
└── CHANGELOG.md
```

---

## Getting started

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) (**stable** channel)
- **Dart** 3.12+ (see `client/pubspec.yaml`)
- [Git](https://git-scm.com/)

Optional — isolated local backend:

- [Docker](https://docs.docker.com/) and the [Supabase CLI](https://supabase.com/docs/guides/cli)

### Run the web client

```bash
git clone https://github.com/alfred-im/alfred-im.git
cd alfred-im/client
flutter pub get
flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0
```

Open http://localhost:8080/

See [`client/README.md`](client/README.md) for client-specific setup, including a local Supabase stack.

---

## Development

```bash
cd client
bash scripts/verify.sh          # required before push
bash scripts/verify.sh --build  # optional web build
```

When changing specs or database migrations:

```bash
bash scripts/check-spec-sync.sh
```

---

## Testing

| Suite | Command |
|-------|---------|
| CI gate | `cd client && bash scripts/test.sh gate` |
| Full catalog | [`client/scripts/test/README.md`](client/scripts/test/README.md) |

---

## Contributing

Feedback and bug reports are welcome via [GitHub Issues](https://github.com/alfred-im/alfred-im/issues). Pull requests are welcome when they align with the project's direction.

Alfred uses **Spec-Driven Development (SDD)** — see [`docs/specs/README.md`](docs/specs/README.md) and the [promise registry](docs/specs/registry.md). Use the [pull request template](.github/PULL_REQUEST_TEMPLATE.md).

Before opening a PR, run:

```bash
cd client && bash scripts/verify.sh
bash scripts/check-spec-sync.sh   # when specs or migrations change
```

This project is actively developed with AI assistance; there is no separate `CONTRIBUTING.md` yet. For agent-oriented workflow notes, see [`AGENTS.md`](AGENTS.md).

Please read our [Code of Conduct](CODE_OF_CONDUCT.md).

---

## Documentation

| Document | Purpose |
|----------|---------|
| [`PROJECT_MAP.md`](PROJECT_MAP.md) | Full project map |
| [`docs/INDICE.md`](docs/INDICE.md) | Documentation index |
| [`docs/architecture/full-stack.md`](docs/architecture/full-stack.md) | Architecture overview |
| [`docs/decisions/README.md`](docs/decisions/README.md) | Architecture decision records (ADR) |
| [`client/README.md`](client/README.md) | Client-specific notes |

---

## Roadmap

- Federation via XMPP and Matrix bridges — **planned**

---

## Security

Please **do not** report security vulnerabilities in public GitHub Issues.

Use [GitHub Security Advisories](https://github.com/alfred-im/alfred-im/security/advisories/new) to report them privately. See [SECURITY.md](SECURITY.md).

---

## License

Copyright © 2026 im.alfred

Licensed under the [GNU General Public License v3.0 or later](LICENSE).
