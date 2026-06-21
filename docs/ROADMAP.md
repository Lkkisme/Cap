# Roadmap

This roadmap describes the intended direction for `Lkkisme/Cap`, a public unofficial Chinese Windows-focused fork of `CapSoftware/Cap`. It is written to make the fork's maintenance scope, priorities, and limits clear.

The upstream Cap project has a large public footprint, including about 19.7k GitHub stars and 1.6k forks as background context checked on 2026-06-21. Those numbers belong to the upstream project and must not be presented as adoption evidence for this fork.

## Current Focus

The current focus is to make the fork understandable, buildable, and maintainable for Chinese Windows users and contributors.

Primary work areas:

- Keep the Windows desktop application usable and aligned with the upstream architecture.
- Document setup, build, and development workflows in Chinese where helpful.
- Preserve compatibility with upstream project structure, package management, and Rust workspace conventions.
- Identify fork-specific changes clearly so future contributors can understand what differs from upstream.
- Improve trust signals for reviewers by keeping roadmap, adoption, maintenance scope, and release notes honest and current.
- Complete the SignPath Foundation review and use it only after approval for verified Windows release artifacts.

## Next Milestones

## Milestone 1: Repository Clarity

- Document the fork's purpose and target users.
- Mark which documentation comes from upstream and which parts are fork-specific.
- Add or update contribution guidance for Windows users.
- Keep setup instructions reproducible from a clean checkout.

## Milestone 2: Windows Build Reliability

- Verify the desktop development path on Windows.
- Document required versions of Node, pnpm, Rust, Docker, and other tools.
- Track common build failures and their fixes.
- Avoid changing generated files or upstream-owned implementation areas unless required.

## Milestone 3: Upstream Compatibility

- Maintain a repeatable process for comparing this fork with `CapSoftware/Cap`.
- Record sync decisions in release notes or maintenance notes.
- Prefer small, reviewable fork-specific changes over large untracked divergence.
- Rebase, merge, or cherry-pick upstream changes only after checking local Windows impact.

## Milestone 4: Adoption Evidence

- Track only verifiable adoption indicators for this fork.
- Separate fork adoption from upstream project popularity.
- Record how metrics were collected, including date and source.
- Update `docs/adoption.md` when new public evidence exists.

## Milestone 5: Release Trust

- Publish releases only when the maintainer can describe what changed, what was tested, and what remains risky.
- Keep release notes specific to this fork.
- Include Windows-specific verification notes when available.
- Avoid unsupported claims about stability, security, usage, or production readiness.
- After SignPath approval, publish a new signed Windows release and record signature verification evidence.

## Non-Goals

This fork is not trying to replace the upstream Cap project.

Current non-goals:

- Claiming upstream adoption as adoption of this fork.
- Presenting the fork as widely used before there is evidence.
- Building an independent product roadmap unrelated to upstream without clear maintainer capacity.
- Supporting every platform equally.
- Promising enterprise readiness, security guarantees, or long-term support without the process and resources to back those claims.
- Rewriting large parts of the application only to differentiate from upstream.
- Adding features that make upstream syncing difficult unless there is a clear Windows or Chinese-user need.
- Bypassing upstream services, subscriptions, authentication, organization policies, SmartScreen, or endpoint protection.

## Upstream Sync

The fork should remain close enough to upstream that important fixes and improvements can still be evaluated and adopted.

Preferred sync approach:

- Track upstream changes regularly.
- Review upstream release notes, dependency changes, database changes, and desktop changes before syncing.
- Keep fork-specific patches small and documented.
- Resolve conflicts in favor of upstream behavior unless the fork has a documented reason to differ.
- Test Windows development and build paths after meaningful syncs.

When this fork intentionally diverges from upstream, the reason should be recorded in documentation, release notes, or the relevant pull request.

## Release Trust

Release trust is based on transparent maintenance, not inflated claims.

Each release should aim to include:

- A short summary of changes.
- Whether the release contains upstream sync work, fork-specific work, or both.
- The environment used for verification.
- Commands or workflows that were run.
- Known limitations.
- Any unverified areas.

A release should not claim broad adoption, production readiness, SmartScreen clearance, SignPath signing, or security assurance unless the project has direct evidence and a maintained process supporting those claims.
