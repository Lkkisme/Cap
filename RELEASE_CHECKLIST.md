# Release Checklist

This checklist is for public Windows releases from `Lkkisme/Cap`.

The current public `cap-v0.4.3-cn` release is a prerelease and is not a recommended signed Windows release. It contains Windows EXE, MSI, and portable ZIP assets, but they are not SignPath Foundation signed and do not have the full release evidence set.

## Preconditions

- The release is built from the public `Lkkisme/Cap` repository.
- The release tag uses the `cap-v*` pattern.
- The release scope is documented.
- Fork-specific changes are separated from upstream sync work where practical.
- `README.md`, `PRIVACY.md`, `SECURITY.md`, `CODE_SIGNING_POLICY.md`, and release notes are current.
- No secrets, credentials, private certificates, or local-only binaries are committed.

## Before SignPath Approval

Do not publish a recommended Windows release as signed or SmartScreen-clean.

Allowed:

- Draft releases.
- Prereleases clearly marked as unsigned or incomplete.
- Local developer builds.
- Documentation and workflow validation.

Not allowed:

- Claiming SignPath approval before approval is received.
- Renaming old unsigned assets as signed assets.
- Promoting unsigned EXE/MSI/ZIP assets as recommended Windows downloads.

## After SignPath Approval

Complete these steps before recommending the release to ordinary Windows users:

1. Configure the SignPath project, signing policy, artifact configuration, and trusted GitHub build system.
2. Add required GitHub Variables and Secrets.
3. Run `Windows Signing Check`.
4. Confirm the signing probe is `Valid`.
5. Create a new `cap-v*` tag or run `Windows Release`.
6. Confirm EXE and MSI Authenticode signatures are `Valid`.
7. Extract portable ZIP and confirm internal EXE/DLL signatures are `Valid`.
8. Confirm trusted timestamps are present.
9. Confirm publisher matches the expected SignPath Foundation certificate subject.
10. Wait for `Windows Release Audit`.
11. Wait for `Windows Installer Smoke Test`.
12. Wait for `Windows WinGet Manifest`.
13. Wait for `Windows WDSI Package`.
14. Confirm `SHA256SUMS.txt` is present.
15. Confirm `windows-release-assets-<tag>.json` is present and valid.
16. Confirm `windows-smartscreen-report-<tag>.md` is present.
17. Confirm installer smoke test report and JSON are present.
18. Confirm WinGet and WDSI evidence assets are present.
19. Publish the release only after the evidence gate passes.

## Release Notes

Release notes should include:

- Release tag.
- Whether this is a prerelease or recommended release.
- Upstream sync summary, if any.
- Fork-specific changes.
- Windows artifact names.
- Signing status.
- Known limitations.
- Verification steps or evidence links.

Do not claim broad adoption, enterprise readiness, guaranteed SmartScreen clearance, or security assurance without evidence.

## Rollback or Quarantine

If a public release contains unsafe or incomplete Windows assets:

- Mark it as prerelease.
- Remove direct download recommendations.
- Use `Windows Release Quarantine` if appropriate.
- Publish a corrected release with a new tag instead of replacing signed assets silently.

## WDSI Follow-Up

If a signed release is still blocked by Microsoft Defender or SmartScreen:

- Download the generated WDSI package.
- Submit the affected file through https://www.microsoft.com/en-us/wdsi/filesubmission as a software developer.
- Record the submission ID and Microsoft response in release notes or the SignPath status document.
