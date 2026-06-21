# Upstream Relationship

This document explains how `Lkkisme/Cap` relates to `CapSoftware/Cap`.

## Summary

`Lkkisme/Cap` is a public, unofficial, Chinese Windows-focused downstream fork of the upstream Cap project.

GitHub may show an intermediate fork as the direct parent in the fork network. The canonical upstream project for attribution, sync review, and maintenance context is `CapSoftware/Cap`.

Upstream project:

https://github.com/CapSoftware/Cap

This fork:

https://github.com/Lkkisme/Cap

Unless explicitly stated otherwise, this fork does not represent the upstream Cap maintainers, Cap Software, Inc., or the official Cap release channel.

## Why This Fork Exists

The fork focuses on:

- Chinese-language documentation and user workflows.
- Windows direct-download release maintenance.
- Windows signing, SmartScreen, WDSI, WinGet, and installer verification work.
- Company-managed Windows environments where users may not be able to use app stores or local developer tooling.
- Publicly documenting release trust and maintenance status for this fork.

## What This Fork Does Not Claim

This fork does not claim:

- To be the official `CapSoftware/Cap` repository.
- To represent upstream maintainers.
- To own upstream adoption, stars, downloads, or reputation.
- To provide official upstream Cap releases.
- To have SignPath Foundation signed artifacts before a specific release has actually been signed and verified.
- To bypass upstream services, authentication, subscriptions, organization policies, SmartScreen, or endpoint security controls.

## Upstream Attribution

This repository preserves upstream attribution through:

- GitHub fork relationship.
- `LICENSE`.
- Links to the upstream project in README and policy documents.
- Release and maintenance notes that should distinguish upstream changes from fork-specific changes.

## Upstream-First Policy

Generic fixes should be considered for upstream first when practical.

Examples:

- Security fixes that affect upstream.
- Cross-platform bug fixes.
- Performance improvements that are not specific to this fork.
- Dependency or build fixes that apply to upstream.

Fork-specific work may remain downstream when it primarily concerns Chinese Windows distribution, release trust documentation, SignPath/WDSI preparation, or local user workflows that are outside upstream's current release process.

## Sync Expectations

The maintainer should:

- Monitor relevant upstream changes.
- Review upstream releases and security changes.
- Keep fork-specific patches understandable.
- Avoid large untracked divergence.
- Record meaningful sync decisions in pull requests, release notes, or maintenance documents.

## Application and Program Context

If this fork is used in applications for signing, open source support, or maintainer programs, the applicant must be clear that:

- The submitted repository is `https://github.com/Lkkisme/Cap`.
- The maintainer role applies to this fork.
- Upstream adoption is background context only.
- Fork adoption must be supported by fork-specific evidence.
