# Issue Triage

This document defines how issues are sorted in `Lkkisme/Cap`.

## Goals

Triage should:

- Protect users from security and release-trust problems.
- Keep Windows release issues visible.
- Separate fork-specific work from upstream-only work.
- Ask for reproducible information before committing to fixes.
- Avoid overstating support guarantees.

## Labels

Core labels:

- `needs-triage`: new issue or pull request that has not been reviewed.
- `bug`: confirmed or plausible defect.
- `enhancement`: feature request or improvement.
- `documentation`: documentation change.
- `windows`: Windows-specific issue.
- `release`: release, installer, updater, signing, SmartScreen, WDSI, WinGet, or packaging issue.
- `security`: security-sensitive report that should move to private handling when appropriate.
- `privacy`: privacy-sensitive behavior or report.
- `upstream-sync`: issue related to syncing upstream `CapSoftware/Cap`.
- `needs-repro`: needs reproduction steps or confirmation.
- `blocked`: waiting for external approval, user data, upstream change, or third-party service.
- `dependencies`: dependency update or dependency vulnerability.
- `rust`: Rust crate or desktop backend work.

## Priority

- P0: confirmed security vulnerability, compromised release artifact, malicious package, leaked signing secret, or release artifact substitution.
- P1: release blocker, broken Windows installer/update flow, privacy-impacting regression, or crash affecting the main recording workflow.
- P2: reproducible bug with workaround, documentation gap blocking setup, localization issue affecting common use.
- P3: small enhancement, cleanup, minor wording, or low-impact request.

## Triage Flow

1. Confirm the issue belongs to `Lkkisme/Cap`.
2. Add `needs-triage` if the report has not been reviewed.
3. Add area labels such as `windows`, `release`, `documentation`, `upstream-sync`, or `dependencies`.
4. Add severity or priority in the issue text when helpful.
5. Ask for missing reproduction details when needed.
6. Move security-sensitive details to private vulnerability reporting.
7. Close or transfer upstream-only issues with a pointer to `CapSoftware/Cap`.
8. Link fixed issues from pull requests or release notes.

## Closing Rules

An issue may be closed when:

- It is fixed and the release or commit is linked.
- It belongs only to upstream `CapSoftware/Cap`.
- It asks for bypassing authentication, subscriptions, organization policies, SmartScreen, or endpoint protection.
- It lacks requested reproduction details after reasonable follow-up time.
- It duplicates an existing issue.
- It is a support question answered by documentation.

## Security and Privacy

Do not keep secrets, private recordings, or exploit details in public issues. Ask the reporter to use GitHub private vulnerability reporting for security-sensitive reports.

Reports involving logs or recordings should be reviewed for accidental exposure of private data before they are quoted in follow-up comments.
