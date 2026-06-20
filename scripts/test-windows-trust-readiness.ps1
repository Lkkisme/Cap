param(
    [string]$Repository = $env:GITHUB_REPOSITORY,
    [string]$OutputDirectory = "windows-trust-readiness",
    [string]$StoreProductId = "",
    [switch]$FailOnMissing
)

$ErrorActionPreference = "Stop"

function ConvertTo-Bool {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    $normalized = $Value.Trim().ToLowerInvariant()
    $normalized -in @("1", "true", "yes", "y")
}

function Add-Check {
    param(
        [string]$Area,
        [string]$Item,
        [ValidateSet("pass", "warning", "fail")]
        [string]$Status,
        [string]$Detail,
        [string]$NextAction = ""
    )

    $script:checks += [pscustomobject]@{
        Area = $Area
        Item = $Item
        Status = $Status
        Detail = $Detail
        NextAction = $NextAction
    }
}

function Test-OfficialMicrosoftStoreUrl {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    try {
        $uri = [System.Uri]::new($Value.Trim())
        if ($uri.Scheme -ne "https") {
            return $false
        }

        $hosts = @("apps.microsoft.com", "www.microsoft.com", "microsoft.com")
        return $hosts -contains $uri.Host.ToLowerInvariant()
    } catch {
        return $false
    }
}

function Get-ConfiguredStoreUrl {
    $candidates = @(
        $env:NEXT_PUBLIC_WINDOWS_STORE_URL,
        $env:WINDOWS_STORE_URL,
        $env:CAP_WINDOWS_STORE_URL
    )

    foreach ($candidate in $candidates) {
        if (Test-OfficialMicrosoftStoreUrl -Value $candidate) {
            return $candidate.Trim()
        }
    }

    $null
}

function Test-RegexValue {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    try {
        [regex]::new($Value) | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Test-WorkflowFile {
    param(
        [string]$Path,
        [string]$Name
    )

    if (Test-Path -LiteralPath $Path) {
        Add-Check -Area "Automation" -Item $Name -Status "pass" -Detail "$Path exists."
    } else {
        Add-Check -Area "Automation" -Item $Name -Status "fail" -Detail "$Path is missing." -NextAction "Restore the workflow before publishing Windows releases."
    }
}

function Get-GitHubJson {
    param([string]$Uri)

    $headers = @{
        Accept = "application/vnd.github+json"
        "User-Agent" = "Cap-Windows-Trust-Readiness"
        "X-GitHub-Api-Version" = "2022-11-28"
    }

    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
        $headers.Authorization = "Bearer $env:GITHUB_TOKEN"
    }

    Invoke-RestMethod -Headers $headers -Uri $Uri
}

$checks = @()
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$outputFullPath = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
    [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputDirectory))
}

if (Test-Path -LiteralPath $outputFullPath) {
    Remove-Item -LiteralPath $outputFullPath -Recurse -Force
}
New-Item -ItemType Directory -Path $outputFullPath -Force | Out-Null

try {
    & (Join-Path $PSScriptRoot "validate-windows-app-metadata.ps1")
    Add-Check -Area "Package identity" -Item "Windows metadata" -Status "pass" -Detail "Tauri and Cargo Windows metadata are stable."
} catch {
    Add-Check -Area "Package identity" -Item "Windows metadata" -Status "fail" -Detail $_.Exception.Message -NextAction "Fix package identity metadata before creating signed releases or Store packages."
}

Test-WorkflowFile -Path (Join-Path $repoRoot ".github\workflows\release-desktop.yml") -Name "Windows Release"
Test-WorkflowFile -Path (Join-Path $repoRoot ".github\workflows\windows-signing-check.yml") -Name "Windows Signing Check"
Test-WorkflowFile -Path (Join-Path $repoRoot ".github\workflows\windows-release-audit.yml") -Name "Windows Release Audit"
Test-WorkflowFile -Path (Join-Path $repoRoot ".github\workflows\windows-installer-smoke-test.yml") -Name "Windows Installer Smoke Test"
Test-WorkflowFile -Path (Join-Path $repoRoot ".github\workflows\windows-msix-store-package.yml") -Name "Windows MSIX Store Package"
Test-WorkflowFile -Path (Join-Path $repoRoot ".github\workflows\windows-store-package.yml") -Name "Windows Store Package"
Test-WorkflowFile -Path (Join-Path $repoRoot ".github\workflows\windows-winget-manifest.yml") -Name "Windows WinGet Manifest"
Test-WorkflowFile -Path (Join-Path $repoRoot ".github\workflows\windows-wdsi-package.yml") -Name "Windows WDSI Package"

$storeUrl = Get-ConfiguredStoreUrl
if ($storeUrl) {
    Add-Check -Area "Microsoft Store" -Item "Store download URL" -Status "pass" -Detail "Official Microsoft Store URL is configured."
} else {
    Add-Check -Area "Microsoft Store" -Item "Store download URL" -Status "warning" -Detail "No official Microsoft Store URL is configured for /download/windows." -NextAction "After Store approval, set NEXT_PUBLIC_WINDOWS_STORE_URL, WINDOWS_STORE_URL, or CAP_WINDOWS_STORE_URL to the official Microsoft Store HTTPS URL."
}

$storeCredentialNames = @(
    "AZURE_AD_APPLICATION_CLIENT_ID_SET",
    "AZURE_AD_APPLICATION_SECRET_SET",
    "AZURE_AD_TENANT_ID_SET",
    "SELLER_ID_SET"
)
$missingStoreCredentials = @($storeCredentialNames | Where-Object { -not (ConvertTo-Bool ([Environment]::GetEnvironmentVariable($_))) })
if ($missingStoreCredentials.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($StoreProductId)) {
    Add-Check -Area "Microsoft Store" -Item "Partner Center publishing" -Status "pass" -Detail "Partner Center credential indicators and store product id are present."
} elseif ($missingStoreCredentials.Count -eq 0) {
    Add-Check -Area "Microsoft Store" -Item "Partner Center publishing" -Status "warning" -Detail "Partner Center credential indicators are present, but no store_product_id was provided to this readiness run." -NextAction "Run this workflow with the Store product ID before using publish_to_store=true."
} else {
    Add-Check -Area "Microsoft Store" -Item "Partner Center publishing" -Status "warning" -Detail "Missing Partner Center credential indicators: $($missingStoreCredentials -join ', ')." -NextAction "Configure AZURE_AD_APPLICATION_CLIENT_ID, AZURE_AD_APPLICATION_SECRET, AZURE_AD_TENANT_ID, and SELLER_ID before automatic Store publishing."
}

$provider = $env:WINDOWS_SIGNING_PROVIDER
if ($provider) {
    $provider = $provider.Trim().ToLowerInvariant()
}

$validProviders = @("azure-artifact-signing", "signpath", "pfx")
if ([string]::IsNullOrWhiteSpace($provider)) {
    Add-Check -Area "Code signing" -Item "Signing provider" -Status "warning" -Detail "WINDOWS_SIGNING_PROVIDER is not configured." -NextAction "Set WINDOWS_SIGNING_PROVIDER to azure-artifact-signing, signpath, or pfx, then run Windows Signing Check."
} elseif ($validProviders -contains $provider) {
    Add-Check -Area "Code signing" -Item "Signing provider" -Status "pass" -Detail "WINDOWS_SIGNING_PROVIDER is '$provider'."
} else {
    Add-Check -Area "Code signing" -Item "Signing provider" -Status "fail" -Detail "Unsupported WINDOWS_SIGNING_PROVIDER '$provider'." -NextAction "Use azure-artifact-signing, signpath, or pfx."
}

if (Test-RegexValue -Value $env:WINDOWS_SIGNING_PUBLISHER_PATTERN) {
    Add-Check -Area "Code signing" -Item "Publisher pattern" -Status "pass" -Detail "WINDOWS_SIGNING_PUBLISHER_PATTERN is configured and is a valid regex."
} else {
    Add-Check -Area "Code signing" -Item "Publisher pattern" -Status "warning" -Detail "WINDOWS_SIGNING_PUBLISHER_PATTERN is missing or invalid." -NextAction "Set it to a regex matching the Authenticode subject of the real publisher certificate."
}

$providerRequirements = @{
    "azure-artifact-signing" = @(
        "AZURE_ARTIFACT_SIGNING_ENDPOINT",
        "AZURE_ARTIFACT_SIGNING_ACCOUNT_NAME",
        "AZURE_ARTIFACT_SIGNING_CERTIFICATE_PROFILE_NAME",
        "AZURE_CLIENT_ID_SET",
        "AZURE_TENANT_ID_SET",
        "AZURE_SUBSCRIPTION_ID_SET"
    )
    "signpath" = @(
        "SIGNPATH_API_TOKEN_SET",
        "SIGNPATH_ORGANIZATION_ID_SET",
        "SIGNPATH_PROJECT_SLUG_SET",
        "SIGNPATH_SIGNING_POLICY_SLUG_SET",
        "SIGNPATH_ARTIFACT_CONFIGURATION_SLUG_SET"
    )
    "pfx" = @(
        "WINDOWS_CERTIFICATE_PFX_BASE64_SET",
        "WINDOWS_CERTIFICATE_PFX_PASSWORD_SET"
    )
}

if ($validProviders -contains $provider) {
    $missingSigningInputs = @()
    foreach ($name in $providerRequirements[$provider]) {
        if ($name.EndsWith("_SET")) {
            if (-not (ConvertTo-Bool ([Environment]::GetEnvironmentVariable($name)))) {
                $missingSigningInputs += $name
            }
        } elseif ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
            $missingSigningInputs += $name
        }
    }

    if ($missingSigningInputs.Count -eq 0) {
        Add-Check -Area "Code signing" -Item "Provider inputs" -Status "pass" -Detail "Required inputs for '$provider' are present."
    } else {
        Add-Check -Area "Code signing" -Item "Provider inputs" -Status "fail" -Detail "Missing inputs for '$provider': $($missingSigningInputs -join ', ')." -NextAction "Configure the missing GitHub variables or secrets, then run Windows Signing Check."
    }
}

if ($storeUrl -or ($validProviders -contains $provider)) {
    Add-Check -Area "Distribution path" -Item "Primary trust path" -Status "pass" -Detail "A Store URL or code signing provider is configured."
} else {
    Add-Check -Area "Distribution path" -Item "Primary trust path" -Status "fail" -Detail "Neither Microsoft Store URL nor code signing provider is configured." -NextAction "Prioritize Microsoft Store approval or configure a Windows signing provider."
}

if (-not [string]::IsNullOrWhiteSpace($Repository)) {
    try {
        $repo = Get-GitHubJson -Uri "https://api.github.com/repos/$Repository"
        if ($repo.private -eq $false) {
            Add-Check -Area "Repository" -Item "Visibility" -Status "pass" -Detail "$Repository is public."
        } else {
            Add-Check -Area "Repository" -Item "Visibility" -Status "warning" -Detail "$Repository is private." -NextAction "Public downloads and reputation building work best from the public official repository."
        }

        $releases = @(Get-GitHubJson -Uri "https://api.github.com/repos/$Repository/releases?per_page=20" | Where-Object { -not $_.draft -and -not $_.prerelease -and $_.tag_name -like "cap-v*" })
        $latestRelease = $releases | Select-Object -First 1
        if ($latestRelease) {
            $assetNames = @($latestRelease.assets | ForEach-Object { $_.name.ToLowerInvariant() })
            $safeTag = ($latestRelease.tag_name -replace '[^A-Za-z0-9._-]', '-').ToLowerInvariant()
            $hasExe = @($assetNames | Where-Object { $_ -match "windows.*\.exe$" }).Count -gt 0
            $hasMsi = @($assetNames | Where-Object { $_ -match "windows.*\.msi$" }).Count -gt 0
            $hasChecksums = $assetNames -contains "sha256sums.txt"
            $hasAuditReport = $assetNames -contains "windows-smartscreen-report-$safeTag.md"
            $hasAuditJson = $assetNames -contains "windows-release-assets-$safeTag.json"
            $hasSmokeReport = $assetNames -contains "windows-installer-smoke-test-report-$safeTag.md"
            $hasSmokeJson = $assetNames -contains "windows-installer-smoke-test-results-$safeTag.json"
            $hasWingetManifest = $assetNames -contains "windows-winget-manifest-$safeTag.zip"
            $hasWingetSubmission = $assetNames -contains "windows-winget-submission-$safeTag.md"
            $hasWdsiChecklist = $assetNames -contains "windows-wdsi-submission-checklist-$safeTag.md"
            $hasWdsiText = $assetNames -contains "windows-wdsi-submission-text-$safeTag.zip"

            $missingEvidence = @()
            if (-not $hasExe) { $missingEvidence += "Windows EXE" }
            if (-not $hasMsi) { $missingEvidence += "Windows MSI" }
            if (-not $hasChecksums) { $missingEvidence += "SHA256SUMS.txt" }
            if (-not $hasAuditReport) { $missingEvidence += "SmartScreen report" }
            if (-not $hasAuditJson) { $missingEvidence += "release asset JSON" }
            if (-not $hasSmokeReport) { $missingEvidence += "installer smoke report" }
            if (-not $hasSmokeJson) { $missingEvidence += "installer smoke JSON" }
            if (-not $hasWingetManifest) { $missingEvidence += "WinGet manifest" }
            if (-not $hasWingetSubmission) { $missingEvidence += "WinGet submission" }
            if (-not $hasWdsiChecklist) { $missingEvidence += "WDSI checklist" }
            if (-not $hasWdsiText) { $missingEvidence += "WDSI submission text" }

            if ($missingEvidence.Count -eq 0) {
                Add-Check -Area "Latest release" -Item $latestRelease.tag_name -Status "pass" -Detail "Latest public Windows release has all download gate evidence."
            } else {
                Add-Check -Area "Latest release" -Item $latestRelease.tag_name -Status "warning" -Detail "Missing evidence: $($missingEvidence -join ', ')." -NextAction "Publish a new signed Windows release through the Windows Release workflow."
            }
        } else {
            Add-Check -Area "Latest release" -Item "Public cap-v release" -Status "warning" -Detail "No public cap-v release was found." -NextAction "Publish a signed Windows release when signing or Store packaging is ready."
        }
    } catch {
        Add-Check -Area "Repository" -Item "GitHub API" -Status "warning" -Detail $_.Exception.Message -NextAction "Re-run with GITHUB_TOKEN available or inspect the repository manually."
    }
}

$reportPath = Join-Path $outputFullPath "windows-trust-readiness-report.md"
$jsonPath = Join-Path $outputFullPath "windows-trust-readiness.json"
$statusRank = @{
    pass = 0
    warning = 1
    fail = 2
}
$worstStatus = ($checks | Sort-Object { $statusRank[$_.Status] } -Descending | Select-Object -First 1).Status
if ([string]::IsNullOrWhiteSpace($worstStatus)) {
    $worstStatus = "fail"
}

$summary = [pscustomobject]@{
    Repository = $Repository
    GeneratedAt = (Get-Date).ToUniversalTime().ToString("o")
    WorstStatus = $worstStatus
    Checks = $checks
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 -LiteralPath $jsonPath

$lines = @()
$lines += "# Windows Trust Readiness"
$lines += ""
$lines += "Repository: $Repository"
$lines += "Generated: $($summary.GeneratedAt)"
$lines += "Overall status: $worstStatus"
$lines += ""
$lines += "| Area | Item | Status | Detail | Next action |"
$lines += "| --- | --- | --- | --- | --- |"
foreach ($check in $checks) {
    $lines += "| $($check.Area) | $($check.Item) | $($check.Status) | $($check.Detail.Replace('|', '/')) | $($check.NextAction.Replace('|', '/')) |"
}
$lines += ""
$lines += "## Recommended order"
$lines += ""
$lines += "1. Prefer Microsoft Store approval and configure the official Store HTTPS URL for `/download/windows`."
$lines += "2. Configure a real Windows signing provider and run `Windows Signing Check` until the probe signs and verifies."
$lines += "3. Publish a new `cap-v*` Windows release through `Windows Release` with signing required."
$lines += "4. Confirm the release audit, installer smoke test, WinGet manifest, and WDSI package workflows pass."
$lines += "5. If Microsoft still flags the signed installer, submit the generated WDSI package as a software developer."
$lines | Set-Content -Encoding UTF8 -LiteralPath $reportPath

Get-Content -LiteralPath $reportPath

if ($FailOnMissing -and ($checks | Where-Object { $_.Status -eq "fail" })) {
    throw "Windows trust readiness has failing checks."
}
