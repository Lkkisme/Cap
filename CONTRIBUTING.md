# Contributing to Lkkisme/Cap

Thank you for contributing to `Lkkisme/Cap`.

This repository is a public fork of the upstream Cap project. The upstream project is maintained at `CapSoftware/Cap`, while this fork is maintained separately for Chinese-speaking users, Windows-focused workflows, and fork-specific release trust work.

Open issues and pull requests against this repository:

https://github.com/Lkkisme/Cap

Do not send fork-specific issues or pull requests to `CapSoftware/Cap`.

## Fork Relationship

`Lkkisme/Cap` tracks and adapts the upstream Cap project, but it is not the canonical upstream repository.

This fork may contain changes for:

- Windows development and packaging
- Chinese user workflows
- China-facing documentation or deployment needs
- Localized fixes that are not appropriate for upstream
- Experiments needed by this fork before upstream submission

Generic bug fixes, security fixes, performance improvements, and broadly useful platform-neutral changes should follow an upstream-first policy when possible. If a fix clearly benefits the original Cap project without being specific to this fork, contributors should consider submitting it upstream first, then syncing it into this fork.

## Development Setup

This repository is a Turborepo monorepo with:

- `apps/desktop`: Tauri v2 and SolidStart desktop app
- `apps/web`: Next.js web app
- `apps/cli`: Rust CLI
- `packages/*`: shared TypeScript packages
- `crates/*`: Rust media, recording, rendering, and camera crates
- `scripts/*`, `infra/`, and `packages/local-docker/`: tooling and local services

Required runtime versions:

- Node.js 20
- pnpm 10.x
- Rust 1.88 or newer
- Docker for MySQL and MinIO when local services are needed

Install dependencies:

```bash
pnpm install
```

Set up the environment:

```bash
pnpm env-setup
pnpm cap-setup
```

Run the full development environment:

```bash
pnpm dev
```

Run only the desktop app:

```bash
pnpm dev:desktop
```

Run only the web app:

```bash
pnpm dev:web
```

Build the repository:

```bash
pnpm build
```

Build a desktop release locally:

```bash
pnpm tauri:build
```

Database workflow:

```bash
pnpm db:generate
pnpm db:push
pnpm db:studio
```

Docker helpers:

```bash
pnpm docker:up
pnpm docker:stop
pnpm docker:clean
```

Quality checks:

```bash
pnpm lint
pnpm format
pnpm typecheck
```

Rust checks:

```bash
cargo build -p <crate>
cargo test -p <crate>
```

## Coding Standards

TypeScript and JavaScript code is formatted with Biome. Use 2-space indentation.

Rust code must pass `rustfmt` and the workspace lint rules.

Naming conventions:

- Files: kebab-case
- Components: PascalCase
- Rust modules: snake_case
- Rust crates: kebab-case

Do not add code comments. Code should be self-explanatory through names, types, and structure.

## Generated Files

Do not manually edit generated files.

This includes:

- `**/tauri.ts`
- `**/queries.ts`
- `apps/desktop/src-tauri/gen/**`

If generated output is stale, update the source files and run the appropriate generator instead of editing generated files directly.

## Windows Distribution Policy

Do not distribute unsigned Windows builds as official releases.

Unsigned Windows binaries, installers, or archives may only be used for local testing or clearly labeled internal test builds. Public Windows distribution must be signed or explicitly marked as unofficial, unsafe for general installation, and not endorsed as a release artifact.

This matters because this fork focuses on Windows users who may rely on Windows SmartScreen, installer trust, and clear artifact provenance.

## Testing Expectations

Before opening a pull request, run the checks relevant to your change.

For TypeScript or JavaScript changes, run:

```bash
pnpm format
pnpm lint
pnpm typecheck
```

For Rust changes, run:

```bash
cargo fmt
cargo build -p <crate>
cargo test -p <crate>
```

For database schema changes, run:

```bash
pnpm db:generate
pnpm db:push
```

For UI changes, include screenshots or screen recordings when useful.

For desktop recording, media, export, upload, or authentication flows, test the real workflow whenever practical. These areas are user-facing and privacy-sensitive.

## Privacy and Security

Cap handles sensitive user data, including screen recordings, audio, camera input, local files, authentication state, uploads, and cloud storage.

Contributions must respect these rules:

- Do not log secrets, tokens, cookies, credentials, recording contents, or private file paths unnecessarily.
- Do not weaken authentication, authorization, upload validation, or storage isolation.
- Do not introduce silent network calls that send user data to third-party services.
- Do not collect analytics, telemetry, or diagnostics without clear user consent and maintainer approval.
- Do not commit `.env` files, credentials, signing keys, certificates, or private service configuration.
- Treat screen, microphone, and camera permissions as sensitive.
- Prefer explicit user action before recording, uploading, sharing, or exporting private content.

Security-sensitive issues should be reported privately when possible instead of being fully disclosed in a public issue. See `SECURITY.md`.

## Pull Requests

Pull requests should be focused and easy to review.

A good pull request includes:

- A clear description of the problem and solution
- Linked issues when applicable
- Screenshots or GIFs for UI changes
- Notes about database migrations, environment variables, or release impact
- A summary of tests run
- Any known limitations

Use conventional commit style when possible:

```text
feat: add windows recording fallback
fix: handle upload retry failure
chore: update local setup docs
improve: clarify chinese windows install flow
refactor: simplify export state handling
docs: update contributing guide
```

## Issue Reports

Open issues in `Lkkisme/Cap`, not `CapSoftware/Cap`, when the issue is about this fork.

Useful issue reports include:

- Operating system and version
- App version or commit hash
- Reproduction steps
- Expected behavior
- Actual behavior
- Logs or screenshots when safe to share
- Whether the problem also exists in upstream Cap, if known

For Windows issues, include:

- Windows edition and version
- CPU architecture
- Whether the app was installed, built locally, or run from a development environment
- Any SmartScreen, antivirus, permission, microphone, camera, or screen capture warnings

## Chinese and Windows Focus

This fork intentionally prioritizes Chinese-speaking users and Windows workflows.

Contributions are especially welcome when they improve:

- Windows installation and reliability
- Desktop recording behavior on Windows
- Chinese documentation
- Chinese user onboarding
- China-friendly development and deployment workflows
- Clear handling of permissions, signing, privacy, and local setup

Keep changes practical, transparent, and easy to audit.
