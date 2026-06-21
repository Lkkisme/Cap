# SignPath Foundation Eligibility Checklist

This checklist maps the public repository state to the SignPath Foundation open source signing requirements.

## Current Status

Application preparation is in progress.

Repository-side materials are prepared or being prepared in public.

Owner-side actions still required before completion:

- Confirm that the `Lkkisme` GitHub account uses multi-factor authentication.
- Provide first name, last name, and email for the SignPath account.
- Submit the SignPath Foundation application.
- Complete any SignPath account, email, MFA, or approval steps requested by SignPath.
- After approval, configure the SignPath project, signing policy, trusted GitHub build system, CI user token, and GitHub repository secrets.
- Publish a new signed Windows release and verify the signatures.
- Track the current state in `docs/signpath-foundation-status.md`.

## Requirement Checklist

| Requirement | Status | Public evidence |
| --- | --- | --- |
| Public repository | Ready | `https://github.com/Lkkisme/Cap` |
| Fork relationship | Ready | GitHub records this repository as a public fork of `CapSoftware/Cap`; the application draft documents the fork relationship. |
| Upstream signed builds | Ready | Upstream Cap distributes Windows builds signed by SignPath Foundation; this fork cannot reuse upstream signatures because it modifies the source. |
| OSI-approved open source license | Ready | `LICENSE`, `apps/desktop/src-tauri/Cargo.toml`, and `apps/desktop/src-tauri/tauri.conf.json` use AGPL-3.0-only for the app, with MIT components noted in the repository license file. |
| No proprietary project code | Ready | The source, build scripts, and workflows are public in this repository. Signed releases must be built from this repository by GitHub Actions. |
| Actively maintained | Ready | The repository has recent Windows release, signing, audit, and documentation work on `main`. |
| Already released in the form to be signed | Ready | The current GitHub Release page includes Windows installer assets; those assets are explicitly marked as old unsigned assets and must be replaced by a new signed release after approval. |
| Documented functionality | Ready | `README.md` describes Cap Chinese Edition as a Windows-focused screen recording application. |
| No malware or potentially unwanted behavior | Ready | The application is a screen recording tool. Windows release workflows include Microsoft Defender scans before publication. |
| No hacking or security bypass features | Ready | The application records user-selected screen, audio, and camera input; it is not a vulnerability scanner, exploitation tool, or security-bypass tool. |
| Privacy policy | Ready | `PRIVACY.md` describes local recording behavior, optional upload/share workflows, permissions, and network behavior. |
| Installation and uninstallation | Ready | Windows release assets include NSIS EXE and MSI installers. `Windows Installer Smoke Test` verifies silent install and uninstall behavior for signed releases. |
| Code signing policy on project home page | Ready | `README.md` links to `CODE_SIGNING_POLICY.md` using the required `Code signing policy` wording. |
| Code signing policy on release/download page | Ready | The current GitHub Release body links to `CODE_SIGNING_POLICY.md`, `PRIVACY.md`, the application draft, and this checklist. |
| SignPath application form answers | Ready except owner contact fields | `docs/signpath-foundation-form-answers.md` maps current form fields to prepared answers and lists the required owner-provided contact fields. |
| SignPath application status tracking | Ready | `docs/signpath-foundation-status.md` records the current application state, owner actions, and post-approval steps. |
| Team roles | Ready | `CODE_SIGNING_POLICY.md` lists the current maintainer, committer, reviewer, and signing approver. |
| MFA for repository and SignPath access | Owner action required | `CODE_SIGNING_POLICY.md` requires MFA, but the account owner must confirm that GitHub MFA is enabled and must enable SignPath MFA during onboarding. |
| Manual signing approval | Ready for setup | `CODE_SIGNING_POLICY.md` requires manual approval for SignPath Foundation release signing requests. This must be configured in SignPath after approval. |
| Own binaries only | Ready | `CODE_SIGNING_POLICY.md` prohibits signing unrelated third-party binaries as project binaries. The SignPath artifact configuration enforces project metadata for signed PE/MSI files. |
| Artifact metadata restrictions | Ready | `.github/signpath/artifact-configuration.xml` requires the release version parameter and enforces Cap Chinese Edition product metadata for signed Windows files. |
| Verifiable CI build source | Ready for setup | `.github/workflows/release-desktop.yml` submits GitHub Actions artifacts to SignPath and passes the release version parameter. SignPath origin verification and trusted build system settings must be configured after approval. |
| Release evidence | Ready | Windows release workflows generate checksums, artifact attestations, signature checks, Defender scans, installer smoke test results, WinGet materials, and WDSI submission materials for signed releases. |

## SignPath Submission Position

This fork should be submitted as a public, Chinese-localized fork of the upstream Cap screen recorder.

The request should ask SignPath Foundation to sign only Windows artifacts produced by GitHub Actions from this repository:

- Windows NSIS installer
- Windows MSI installer
- Windows portable ZIP internal EXE and eligible DLL files

Unsigned local builds, manually uploaded binaries, old release assets, and unrelated third-party binaries must not be submitted for SignPath Foundation signing.
