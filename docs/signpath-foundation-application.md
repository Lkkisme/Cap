# SignPath Foundation Application Draft

This document is a copy-ready draft for applying to SignPath Foundation open source code signing.

## Project Name

Cap Chinese Edition

## Repository

https://github.com/Lkkisme/Cap

## Upstream Project

https://github.com/CapSoftware/Cap

## Project Type

Chinese-localized fork of the open source Cap screen recorder.

## License

AGPLv3, with MIT-licensed components as described in the repository LICENSE file.

## Download Page

https://github.com/Lkkisme/Cap/releases

Current release page:

https://github.com/Lkkisme/Cap/releases/tag/cap-v0.4.3-cn

## Project Description

Cap Chinese Edition is a Chinese-localized fork of Cap, an open source screen recording application. The fork keeps the source public, preserves the upstream license, and focuses on making the Windows desktop application usable for Chinese-speaking users.

The application records screen content, microphone audio, system audio, and camera video when the user chooses to record. It can also export recordings locally or upload/share recordings through configured Cap services when the user signs in and chooses those workflows.

## Why SignPath Foundation Signing Is Requested

The upstream Cap project distributes a Windows installer signed by SignPath Foundation. This fork modifies the upstream project for Chinese localization, so the upstream binary signature cannot be reused.

The goal is to sign only Windows binaries built from this public fork by GitHub Actions, so users and organization IT teams can verify that the distributed installer was built from the public source code in this repository.

## Fork Relationship

The GitHub repository is a public fork. GitHub records the source repository as CapSoftware/Cap.

The signing release branches and tags are intended to stay based on upstream Cap source history, with fork-specific localization and packaging changes reviewed in this repository.

## Signing Scope

Requested signing scope:

- Windows NSIS installer
- Windows MSI installer
- Windows portable ZIP executable and DLL files

Only artifacts produced by GitHub Actions from this public repository should be submitted for signing.

## Existing SignPath Configuration

The repository includes a SignPath artifact configuration at:

`.github/signpath/artifact-configuration.xml`

The Windows release workflow already has a SignPath signing path and validates Authenticode signature status before a signed release is promoted.

## Code Signing Policy

https://github.com/Lkkisme/Cap/blob/main/CODE_SIGNING_POLICY.md

## Privacy Policy

https://github.com/Lkkisme/Cap/blob/main/PRIVACY.md

## Eligibility Checklist

https://github.com/Lkkisme/Cap/blob/main/docs/signpath-foundation-eligibility.md

## Form Answers

https://github.com/Lkkisme/Cap/blob/main/docs/signpath-foundation-form-answers.md

## Current Status

https://github.com/Lkkisme/Cap/blob/main/docs/signpath-foundation-status.md

## Maintainer and Roles

Current maintainer, committer, reviewer, and signing approver:

https://github.com/Lkkisme

External contributions require maintainer review before merge. Signing requests require maintainer approval.

## Build and Release Process

Windows release artifacts are built by GitHub Actions.

The intended signed release flow is:

1. Create a `cap-v*` release tag.
2. Build Windows artifacts in GitHub Actions.
3. Submit only CI-built artifacts to SignPath.
4. Verify Authenticode signatures and trusted timestamps.
5. Generate checksums and release evidence.
6. Run installer smoke tests and Defender scans.
7. Publish the signed release only after verification passes.

## Artifact Metadata Restrictions

The SignPath artifact configuration requires a release `version` parameter and enforces Cap Chinese Edition metadata on signed Windows files:

- PE product name: `Cap 中文版`
- PE product version: release version from `apps/desktop/src-tauri/Cargo.toml`
- PE company name: `Lkkisme`
- MSI subject: `Cap 中文版`
- MSI author: `Lkkisme`

This is intended to prevent unrelated third-party binaries from being signed as project binaries.

## Application Message

Hello SignPath Foundation team,

I would like to apply for free open source code signing for Cap Chinese Edition:

https://github.com/Lkkisme/Cap

This is a public Chinese-localized fork of the open source Cap screen recorder:

https://github.com/CapSoftware/Cap

The upstream project distributes Windows builds signed by SignPath Foundation. This fork modifies the source for Chinese localization and Windows packaging, so it cannot reuse upstream signatures.

I am requesting SignPath Foundation signing only for Windows artifacts built from this public fork by GitHub Actions:

- NSIS EXE installer
- MSI installer
- Portable ZIP internal EXE and eligible DLL files

The repository includes the public code signing policy, privacy policy, eligibility checklist, SignPath artifact configuration, and GitHub Actions workflow for submitting CI-built artifacts to SignPath.

Code signing policy:

https://github.com/Lkkisme/Cap/blob/main/CODE_SIGNING_POLICY.md

Privacy policy:

https://github.com/Lkkisme/Cap/blob/main/PRIVACY.md

Eligibility checklist:

https://github.com/Lkkisme/Cap/blob/main/docs/signpath-foundation-eligibility.md

SignPath artifact configuration:

https://github.com/Lkkisme/Cap/blob/main/.github/signpath/artifact-configuration.xml

I understand that SignPath Foundation signing requires verified GitHub build origin, signing policy restrictions, project metadata restrictions, manual signing approval, and MFA for repository and SignPath access.

Thank you for reviewing this application.

## Notes for Submission

Before submitting the application, confirm:

- The GitHub account has multi-factor authentication enabled.
- The repository is public.
- The repository license is visible.
- The code signing policy and privacy policy links are reachable.
- The eligibility checklist link is reachable.
- The form answers draft is reviewed and the owner has provided first name, last name, and email.
- The owner has confirmed the current status document and is ready to complete CAPTCHA and personal data consent.
- The release workflow builds from source and does not rely on manually uploaded local binaries for signed releases.
