# SignPath Foundation Status

Last updated: 2026-06-21

## Goal

Obtain SignPath Foundation free open source code signing for the `Lkkisme/Cap` Windows fork, then publish a new Windows release containing SignPath Foundation signed EXE, MSI, and portable ZIP artifacts.

## Current State

Status: ready for owner-assisted application submission.

Repository-side preparation is complete:

- Public repository: `https://github.com/Lkkisme/Cap`
- Code signing policy: `https://github.com/Lkkisme/Cap/blob/main/CODE_SIGNING_POLICY.md`
- Privacy policy: `https://github.com/Lkkisme/Cap/blob/main/PRIVACY.md`
- SignPath application draft: `https://github.com/Lkkisme/Cap/blob/main/docs/signpath-foundation-application.md`
- Eligibility checklist: `https://github.com/Lkkisme/Cap/blob/main/docs/signpath-foundation-eligibility.md`
- Application form answers: `https://github.com/Lkkisme/Cap/blob/main/docs/signpath-foundation-form-answers.md`
- Release page links: current `cap-v0.4.3-cn` release body links the code signing policy, privacy policy, application draft, eligibility checklist, and form answers.

## Application Form

Application page:

https://signpath.org/apply.html

Detected form:

- Portal ID: `145110231`
- Form ID: `bf62807d-bb72-4e45-9bde-1f3a53ba2472`

The form includes reCAPTCHA and personal account fields. It cannot be fully submitted by automation without owner participation.

## Owner Action Required

The repository owner must provide or confirm:

- First name
- Last name
- Email address for the SignPath account
- GitHub MFA is enabled
- Agreement to the SignPath Foundation Code of Conduct
- Agreement to SignPath storing and processing personal data for the application
- reCAPTCHA completion
- Final Submit click

## After Application Submission

After the application is submitted, record the submission confirmation or SignPath email response here.

If approved, complete these steps:

1. Configure the SignPath project.
2. Configure the release signing policy.
3. Configure the artifact configuration using `.github/signpath/artifact-configuration.xml`.
4. Configure GitHub as the trusted build system.
5. Add GitHub repository variables and secrets for SignPath.
6. Run `Windows Signing Check`.
7. Publish a new `cap-v*` Windows release.
8. Verify Authenticode status is `Valid`.
9. Verify publisher is SignPath Foundation.
10. Verify EXE, MSI, and portable ZIP contents are signed and recorded in release evidence.

## Not Complete Yet

The goal is not complete until SignPath Foundation approval is received and a new signed Windows release is published and verified.
