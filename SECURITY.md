# Security Policy

## Supported Versions

This repository is a public Windows-focused fork of `CapSoftware/Cap`. Security fixes are handled on a best-effort basis for:

- The current default branch of `Lkkisme/Cap`.
- The latest public release artifacts published by this fork.
- Active code paths used by the Windows desktop app, Tauri/Rust backend, Next.js web app, CLI, update/download flow, and shared packages.

Older tags, abandoned branches, unofficial builds, locally modified binaries, and third-party redistributions are not guaranteed to receive security fixes.

## Reporting a Vulnerability

Report suspected vulnerabilities privately whenever possible.

Preferred method:

- Use GitHub private vulnerability reporting for this repository: https://github.com/Lkkisme/Cap/security/advisories/new

If that link is unavailable:

- Open a public GitHub issue with only a brief, non-sensitive summary.
- Do not include exploit code, secrets, crash dumps with private data, recordings, tokens, or full reproduction details in the public issue.
- Ask for a private contact path so details can be shared safely.

A good report includes:

- Affected component, such as Tauri desktop, Rust crate, Next.js route, CLI, release/download flow, or dependency.
- A clear impact statement.
- Reproduction steps or proof of concept, if safe to share privately.
- Affected commit, tag, release, or downloaded artifact.
- Operating system and environment details.
- Whether the issue also appears to affect upstream `CapSoftware/Cap`.

## Response Expectations

This project is maintained on a best-effort basis. The expected process is:

- Acknowledge a private report as soon as practical.
- Triage severity and affected versions.
- Confirm whether the issue is specific to this fork or should also be coordinated with upstream.
- Develop and test a fix before public disclosure when possible.
- Credit the reporter if requested and appropriate.
- Publish release notes or an advisory when the fix is available.

No guaranteed service-level agreement is promised.

## Security Boundaries

In scope:

- Remote code execution, local privilege escalation, sandbox escape, command injection, path traversal, authentication bypass, authorization bypass, or arbitrary file access.
- Vulnerabilities in the Tauri desktop app, Rust services, screen/audio/camera recording pipeline, Next.js API routes, CLI, shared packages, and updater or download logic.
- Issues that could cause recordings, metadata, credentials, API keys, cookies, or user files to be exposed without user intent.
- Supply-chain risks in build, packaging, release, dependency, or direct-download workflows.
- Windows-specific risks, including installer/download integrity, executable reputation, and unsafe handling of local files or protocols.

Out of scope:

- Vulnerabilities only affecting unsupported versions or heavily modified local builds.
- Reports that only state that a binary is unsigned, unknown to SmartScreen, or has low reputation, without a concrete exploit or integrity issue.
- Social engineering, phishing, or attacks requiring the user to intentionally run unrelated malicious software.
- Denial-of-service issues without a meaningful security impact.
- Dependency vulnerability reports without evidence that the vulnerable code path is reachable in this project.
- Scanner-only reports with no reproduction steps or practical impact.
- Issues in upstream `CapSoftware/Cap` that are not present in this fork, though upstream-impacting issues are still welcome as coordination notes.

## Privacy

Cap is a screen recorder. Security reports may involve sensitive content such as screen recordings, microphone audio, camera video, file paths, project names, browser state, cookies, or tokens.

Minimize private data in reports. Do not upload real recordings, credentials, personal documents, or customer data unless absolutely necessary, and only through a private reporting channel.

The project should not intentionally collect or publish private recording content without user action. Any behavior that exposes local recordings, upload credentials, share links, account data, or metadata beyond the user's intent should be treated as security-sensitive.

## Release Signing and Download Integrity

This fork may provide Windows direct downloads and public release artifacts. Unless a release explicitly states otherwise, do not assume that artifacts are code signed.

The project has submitted a SignPath Foundation application and is waiting for review. SignPath signing is not active until the application is approved, the signing project is configured, a new release is signed, and the signatures are verified for that specific release.

A SmartScreen warning by itself is not considered a vulnerability. Reports about tampered downloads, mismatched checksums, unsafe update behavior, misleading release metadata, compromised build credentials, or release artifact substitution are in scope.

## Coordinated Disclosure

Do not publicly disclose exploit details before maintainers have had a reasonable opportunity to investigate and prepare a fix.

When a vulnerability affects both this fork and upstream `CapSoftware/Cap`, coordinated disclosure with upstream is preferred. The goal is to protect users first, avoid unnecessary surprise, and publish accurate information once fixes or mitigations are available.

Public advisories should avoid overstating impact, should identify affected versions or artifacts as precisely as possible, and should clearly distinguish confirmed issues from suspected risks.
