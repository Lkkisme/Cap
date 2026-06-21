# Maintainers

This repository is the public unofficial Chinese Windows-focused fork of `CapSoftware/Cap`, maintained under `Lkkisme/Cap`.

## Current Maintainer

Primary maintainer: Lkkisme

Lkkisme is responsible for day-to-day maintenance of this fork, including:

- Pull request review and merge decisions.
- Issue triage and labeling.
- Release preparation and release notes.
- Windows-specific build and packaging validation.
- Coordination with upstream `CapSoftware/Cap` changes.
- Repository security settings and access control.
- SignPath-related signing approval for this fork.

## Roles

### Primary Maintainer

The primary maintainer has final responsibility for repository direction, merge decisions, release timing, and project governance.

Current primary maintainer:

- Lkkisme

### Reviewer

Reviewers are responsible for checking pull requests for correctness, maintainability, security impact, and compatibility with the goals of this fork.

Current reviewer:

- Lkkisme

Pull requests should be reviewed before merge. For maintainer-authored changes, the maintainer should still document the review rationale, testing performed, and any upstream references used.

### Release Manager

The release manager is responsible for preparing releases, validating artifacts, publishing release notes, and coordinating signing or distribution steps.

Current release manager:

- Lkkisme

Release responsibilities include:

- Confirming the intended version and release scope.
- Running applicable build, lint, typecheck, and test commands.
- Validating Windows desktop artifacts before publication.
- Preparing release notes that distinguish upstream changes from fork-specific changes.
- Publishing GitHub releases when appropriate.
- Coordinating SignPath signing steps for release artifacts when available.

### Security Contact

Security contact:

- Lkkisme

Security issues should be reported privately when possible, especially for vulnerabilities affecting authentication, local file access, desktop permissions, update delivery, code signing, secrets, or build infrastructure.

If GitHub private vulnerability reporting is available for this repository, it should be used. Otherwise, contact the maintainer through GitHub with a minimal public message requesting a private security contact channel. Do not publish exploit details in a public issue before the maintainer has had a reasonable opportunity to assess and respond.

### Signing Approver

Signing approver:

- Lkkisme

This repository has been submitted to the SignPath Foundation process. The signing approver is responsible for approving signing requests only for releases or artifacts that belong to this fork and have passed the release validation process.

This repository must not claim that artifacts are SignPath-signed until signing is actually approved and completed for the specific artifact being distributed.

## Upstream Sync Responsibility

This fork tracks `CapSoftware/Cap` as its upstream source.

The primary maintainer is responsible for:

- Monitoring relevant upstream changes.
- Pulling or cherry-picking upstream fixes when appropriate.
- Reviewing upstream security fixes for impact on this fork.
- Keeping fork-specific Windows and Chinese localization changes clearly separated when practical.
- Avoiding misleading claims that fork-specific changes are endorsed by upstream.

When upstream changes are imported, release notes or pull request descriptions should clearly identify whether the change came from upstream or was created specifically for this fork.

## GitHub MFA Requirement

All maintainers, reviewers with write access, release managers, and signing approvers must have GitHub multi-factor authentication enabled.

GitHub MFA is currently enabled for Lkkisme.

Future maintainers must enable MFA before receiving repository write, release, package, signing, or administrative access.

## New Maintainer Process

New maintainers may be added when they have demonstrated sustained, trustworthy contributions to this fork.

A candidate should normally have:

- Multiple meaningful merged pull requests.
- Constructive issue triage or review participation.
- Familiarity with the upstream `CapSoftware/Cap` project structure.
- Understanding of this fork's Windows-specific and Chinese localization goals.
- A history of respectful collaboration.
- GitHub MFA enabled.

The primary maintainer may grant reviewer, triager, release, or maintainer permissions gradually. Administrative, release, and signing permissions should be granted only after the candidate has shown reliability over time.

When a new maintainer is added, this file should be updated with their role and responsibilities.

## Access Control

Repository access should follow least privilege.

- Triage access may be granted for issue management.
- Write access may be granted for trusted reviewers or maintainers.
- Release access should be limited to release managers.
- Signing approval should be limited to designated signing approvers.
- Administrative access should be limited to the primary maintainer unless a clear project need exists.

Access should be removed when a maintainer becomes inactive, no longer needs the role, or can no longer meet the repository's security requirements.

## What This Repository Does Not Claim

This repository must be clear about its status and must not overstate its relationship to upstream or external programs.

This repository does not claim:

- To be the official `CapSoftware/Cap` repository.
- To represent the upstream Cap maintainers.
- That fork-specific changes are endorsed by upstream.
- That Lkkisme is an upstream `CapSoftware/Cap` maintainer unless that becomes true and is documented upstream.
- That SignPath signing is approved or active until the SignPath Foundation process has actually approved this repository and specific artifacts have been signed.
- That OpenAI, Codex, or any OSS program has approved this repository unless approval has been granted.
- That releases from this fork are official upstream Cap releases.
- That security fixes from this fork have been accepted upstream unless an upstream pull request or release confirms it.

## Maintenance Status

This fork is maintained by Lkkisme for public Windows-focused and Chinese-language use cases. Maintenance includes issue triage, pull request review, release management, upstream synchronization, and security coordination for this repository.
