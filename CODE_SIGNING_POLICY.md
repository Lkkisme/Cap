# Code Signing Policy

This policy describes how Cap Chinese Edition handles Windows code signing.

## Project

Cap Chinese Edition is a Chinese-localized fork of [CapSoftware/Cap](https://github.com/CapSoftware/Cap).

Repository: [https://github.com/Lkkisme/Cap](https://github.com/Lkkisme/Cap)

Upstream source: [https://github.com/CapSoftware/Cap](https://github.com/CapSoftware/Cap)

License: AGPLv3, with MIT-licensed components as described in [LICENSE](LICENSE)

## Signing Provider

This project is preparing to apply for open source code signing through SignPath.

After approval, Windows release artifacts are expected to use:

Free code signing provided by [SignPath.io](https://signpath.io/), certificate by [SignPath Foundation](https://signpath.org/).

Current status: Windows artifacts in existing releases are not yet signed by SignPath Foundation.

The project home page, release pages, and download pages should link to this page using the term `Code signing policy`.

## Scope

Only Windows release artifacts built from this public repository may be submitted for signing.

Signed artifacts may include:

- Windows NSIS installers
- Windows MSI installers
- Windows portable ZIP contents, including executable and DLL files inside the ZIP

Unsigned local builds, manually uploaded local binaries, and binaries not produced by the trusted GitHub Actions release workflow must not be submitted for SignPath Foundation signing.

## Release Rules

Signed Windows releases must be built from source by GitHub Actions.

Signed Windows releases must use a `cap-v*` release tag.

Signed Windows releases must pass the Windows release workflow, signing checks, release audit, installer smoke test, Defender scan, checksum generation, and release evidence checks before being promoted for end users.

If a release artifact is replaced, a new release tag must be created instead of silently replacing a public signed artifact.

Every SignPath Foundation release signing request must use GitHub as a trusted build system, provide origin metadata for the repository, branch, commit, and workflow run, and require manual approval in SignPath before signing.

The SignPath artifact configuration must enforce project metadata for signed Windows PE and MSI files. Project PE files must identify the product as `Cap 中文版`, use the release version from `apps/desktop/src-tauri/Cargo.toml`, and identify the company as `Lkkisme`. MSI files must identify the subject as `Cap 中文版` and author as `Lkkisme`.

## Team Roles

Current maintainer, committer, reviewer, and signing approver:

- [Lkkisme](https://github.com/Lkkisme)

External contributions must be reviewed by the repository maintainer before merge.

Signing requests must be approved by the repository maintainer.

All committers, reviewers, and signing approvers must use multi-factor authentication for GitHub and SignPath access.

If more maintainers are added, this policy must be updated with the new committer, reviewer, and approver roles before those maintainers approve signed releases.

## Privacy Policy

The project privacy policy is available at [PRIVACY.md](PRIVACY.md).

## Security Expectations

The project must not include malware, potentially unwanted software, or functionality intended to bypass security controls.

The project must not sign unrelated third-party binaries as project binaries.

If upstream open source components are included, they must remain attributable to their upstream projects and must not be misrepresented as original project code.

## Verification

Users can verify signed Windows files with:

```powershell
Get-AuthenticodeSignature .\Cap-CN.exe
```

A valid signed release should show a valid Authenticode signature and a trusted timestamp.
