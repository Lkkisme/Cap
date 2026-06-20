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

        $hostName = $uri.Host.ToLowerInvariant()
        $path = Get-StorePathWithoutLocale -Path $uri.AbsolutePath.ToLowerInvariant()

        if ($hostName -eq "apps.microsoft.com") {
            return $path.StartsWith("/detail/") -or $path.StartsWith("/store/detail/") -or $path.StartsWith("/store/apps/")
        }

        if ($hostName -eq "www.microsoft.com" -or $hostName -eq "microsoft.com") {
            return $path.StartsWith("/store/apps/") -or $path.StartsWith("/store/productid/") -or $path.StartsWith("/p/")
        }

        return $false
    } catch {
        return $false
    }
}

function Get-StorePathWithoutLocale {
    param([string]$Path)

    $segments = @($Path.Split("/", [System.StringSplitOptions]::RemoveEmptyEntries))
    if ($segments.Count -gt 0 -and $segments[0] -match '^[a-z]{2}-[a-z]{2}$') {
        if ($segments.Count -eq 1) {
            return "/"
        }
        return "/" + ($segments[1..($segments.Count - 1)] -join "/")
    }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return "/"
    }

    $Path
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

function Test-TrustedWindowsDownloadUrl {
    param([string]$Value)

    if (Test-OfficialMicrosoftStoreUrl -Value $Value) {
        return $true
    }

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    try {
        $uri = [System.Uri]::new($Value.Trim())
        if ($uri.Scheme -ne "https") {
            return $false
        }

        $hostName = $uri.Host.ToLowerInvariant()
        if ($uri.IsLoopback -or $hostName -eq "cap.so" -or $hostName -eq "www.cap.so" -or $hostName -eq "github.com") {
            return $false
        }

        return $uri.AbsolutePath.ToLowerInvariant().StartsWith("/download")
    } catch {
        return $false
    }
}

function Test-TrustedWindowsAssetBaseUrl {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    try {
        $normalized = $Value.Trim().Replace("{tag}", "cap-v0.0.0").Replace("{filename}", "Cap-CN.exe")
        $uri = [System.Uri]::new($normalized)
        if ($uri.Scheme -ne "https") {
            return $false
        }

        $hostName = $uri.Host.ToLowerInvariant()
        if ($uri.IsLoopback -or $hostName -eq "cap.so" -or $hostName -eq "www.cap.so" -or $hostName -eq "github.com" -or $hostName.EndsWith(".github.com") -or $hostName -eq "githubusercontent.com" -or $hostName.EndsWith(".githubusercontent.com")) {
            return $false
        }

        return $true
    } catch {
        return $false
    }
}

function Get-ConfiguredWindowsAssetBaseUrl {
    $candidates = @(
        $env:WINDOWS_RELEASE_ASSET_BASE_URL,
        $env:CAP_WINDOWS_RELEASE_ASSET_BASE_URL,
        $env:NEXT_PUBLIC_WINDOWS_RELEASE_ASSET_BASE_URL
    )

    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
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

function Test-WorkflowContainsText {
    param(
        [string]$Path,
        [string]$Name,
        [string]$Text,
        [string]$Detail,
        [string]$NextAction
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $content = Get-Content -Raw -LiteralPath $Path
    if ($content.Contains($Text)) {
        Add-Check -Area "Update safety" -Item $Name -Status "pass" -Detail $Detail
    } else {
        Add-Check -Area "Update safety" -Item $Name -Status "fail" -Detail "$Path does not contain $Text." -NextAction $NextAction
    }
}

function Test-WorkflowOmitsText {
    param(
        [string]$Path,
        [string]$Name,
        [string]$Text,
        [string]$Detail,
        [string]$NextAction
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $content = Get-Content -Raw -LiteralPath $Path
    if ($content.Contains($Text)) {
        Add-Check -Area "Update safety" -Item $Name -Status "fail" -Detail "$Path still contains $Text." -NextAction $NextAction
    } else {
        Add-Check -Area "Update safety" -Item $Name -Status "pass" -Detail $Detail
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

function Get-ReleaseQuarantineResult {
    param(
        [string]$Tag,
        [string]$Repository,
        [string]$OutputRoot
    )

    $safeTag = ($Tag -replace '[^A-Za-z0-9._-]', '-').ToLowerInvariant()
    $quarantineDirectory = Join-Path $OutputRoot "latest-release-quarantine-$safeTag"
    $params = @{
        Repository = $Repository
        Tag = $Tag
        Mode = "report"
        OutputDirectory = $quarantineDirectory
    }

    & (Join-Path $PSScriptRoot "protect-windows-release-assets.ps1") @params | Out-Null

    $jsonPath = Join-Path $quarantineDirectory "windows-release-quarantine-report.json"
    if (-not (Test-Path -LiteralPath $jsonPath)) {
        throw "Windows release quarantine report was not generated."
    }

    Get-Content -Raw -LiteralPath $jsonPath | ConvertFrom-Json
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
Test-WorkflowFile -Path (Join-Path $repoRoot ".github\workflows\windows-release-asset-mirror.yml") -Name "Windows Release Asset Mirror"
Test-WorkflowFile -Path (Join-Path $repoRoot "scripts\write-windows-build-env.ps1") -Name "Windows build environment writer"
Test-WorkflowFile -Path (Join-Path $repoRoot "scripts\sync-windows-release-assets.ps1") -Name "Windows release asset mirror script"

Test-WorkflowContainsText -Path (Join-Path $repoRoot "scripts\write-windows-build-env.ps1") -Name "Windows Release updater check" -Text "VITE_DISABLE_UPDATER=true" -Detail "Windows Release builds disable the desktop updater UI and use the guarded download page for manual downloads." -NextAction "Restore VITE_DISABLE_UPDATER=true in the Windows Release build environment writer."
Test-WorkflowContainsText -Path (Join-Path $repoRoot ".github\workflows\release-desktop.yml") -Name "Windows Release download URL writer" -Text "write-windows-build-env.ps1" -Detail "Windows Release writes download URLs through the shared validation script." -NextAction "Use scripts/write-windows-build-env.ps1 when creating the Windows Release .env file."
Test-WorkflowContainsText -Path (Join-Path $repoRoot ".github\workflows\windows-store-package.yml") -Name "Windows Store download URL writer" -Text "write-windows-build-env.ps1" -Detail "Windows Store Package writes download URLs through the shared validation script." -NextAction "Use scripts/write-windows-build-env.ps1 when creating the Windows Store Package .env file."
Test-WorkflowContainsText -Path (Join-Path $repoRoot ".github\workflows\windows-msix-store-package.yml") -Name "Windows MSIX download URL writer" -Text "write-windows-build-env.ps1" -Detail "Windows MSIX Store Package writes download URLs through the shared validation script." -NextAction "Use scripts/write-windows-build-env.ps1 when creating the Windows MSIX Store Package .env file."
Test-WorkflowOmitsText -Path (Join-Path $repoRoot ".github\workflows\release-desktop.yml") -Name "Windows Release upstream web URL" -Text "VITE_SERVER_URL=https://cap.so" -Detail "Windows Release no longer hardcodes the upstream cap.so URL into signed desktop builds." -NextAction "Remove hardcoded cap.so from Windows Release build environment."
Test-WorkflowOmitsText -Path (Join-Path $repoRoot ".github\workflows\windows-store-package.yml") -Name "Windows Store upstream web URL" -Text "VITE_SERVER_URL=https://cap.so" -Detail "Windows Store Package no longer hardcodes the upstream cap.so URL into signed desktop builds." -NextAction "Remove hardcoded cap.so from Windows Store Package build environment."
Test-WorkflowOmitsText -Path (Join-Path $repoRoot ".github\workflows\windows-msix-store-package.yml") -Name "Windows MSIX upstream web URL" -Text "VITE_SERVER_URL=https://cap.so" -Detail "Windows MSIX Store Package no longer hardcodes the upstream cap.so URL into Store packages." -NextAction "Remove hardcoded cap.so from Windows MSIX Store Package build environment."
Test-WorkflowContainsText -Path (Join-Path $repoRoot "scripts\write-windows-build-env.ps1") -Name "Windows Store updater check" -Text "VITE_DISABLE_UPDATER=true" -Detail "Windows Store EXE/MSI packages disable the desktop updater UI and rely on Store or verified release distribution." -NextAction "Restore VITE_DISABLE_UPDATER=true in the Windows build environment writer."
Test-WorkflowContainsText -Path (Join-Path $repoRoot "scripts\write-windows-build-env.ps1") -Name "Windows MSIX updater check" -Text "VITE_DISABLE_UPDATER=true" -Detail "Windows MSIX packages disable the desktop updater UI and rely on Microsoft Store distribution." -NextAction "Restore VITE_DISABLE_UPDATER=true in the Windows build environment writer."
Test-WorkflowContainsText -Path (Join-Path $repoRoot ".github\workflows\release-desktop.yml") -Name "Windows Release signing gate" -Text ".\scripts\validate-windows-signing.ps1 -RequireSigning" -Detail "Windows Release always requires a configured Windows signing provider before producing installer assets." -NextAction "Restore the required signing gate before building Windows release installers."
Test-WorkflowOmitsText -Path (Join-Path $repoRoot ".github\workflows\release-desktop.yml") -Name "Windows Release unsigned input" -Text "require_signing:" -Detail "Windows Release no longer exposes a manual unsigned installer switch." -NextAction "Remove the require_signing workflow input from Windows Release."
Test-WorkflowOmitsText -Path (Join-Path $repoRoot ".github\workflows\release-desktop.yml") -Name "Windows Release unsigned path" -Text "-AllowUnsigned" -Detail "Windows Release no longer invokes unsigned signing validation." -NextAction "Remove the unsigned validation path from Windows Release."
Test-WorkflowContainsText -Path (Join-Path $repoRoot ".github\workflows\release-desktop.yml") -Name "Windows Release portable ZIP" -Text "portable.zip" -Detail "Windows Release stages a portable ZIP containing the signed desktop app binaries." -NextAction "Restore portable ZIP staging in Windows Release."
Test-WorkflowContainsText -Path (Join-Path $repoRoot ".github\workflows\release-desktop.yml") -Name "Windows Release portable ZIP gate" -Text "windows-x64-portable\.zip$" -Detail "Windows Release publish gate requires the portable ZIP before public release." -NextAction "Restore the portable ZIP asset requirement before publishing Windows releases."
Test-WorkflowContainsText -Path (Join-Path $repoRoot "scripts\protect-windows-release-assets.ps1") -Name "Windows portable ZIP quarantine" -Text 'Contains("portable")' -Detail "Windows release quarantine treats portable ZIP files as protected Windows release assets." -NextAction "Restore portable ZIP detection in protect-windows-release-assets.ps1."
Test-WorkflowContainsText -Path (Join-Path $repoRoot ".github\workflows\windows-release-audit.yml") -Name "Windows Release Audit attestations permission" -Text "attestations: read" -Detail "Windows Release Audit can verify GitHub artifact attestations for release assets." -NextAction "Grant attestations: read before calling gh attestation verify."
Test-WorkflowContainsText -Path (Join-Path $repoRoot ".github\workflows\windows-installer-smoke-test.yml") -Name "Windows Installer Smoke Test attestations permission" -Text "attestations: read" -Detail "Windows Installer Smoke Test can verify GitHub artifact attestations before installing assets." -NextAction "Grant attestations: read before calling gh attestation verify."
Test-WorkflowContainsText -Path (Join-Path $repoRoot ".github\workflows\windows-winget-manifest.yml") -Name "Windows WinGet Manifest attestations permission" -Text "attestations: read" -Detail "Windows WinGet Manifest can verify GitHub artifact attestations before generating package metadata." -NextAction "Grant attestations: read before calling gh attestation verify."
Test-WorkflowContainsText -Path (Join-Path $repoRoot ".github\workflows\windows-wdsi-package.yml") -Name "Windows WDSI Package attestations permission" -Text "attestations: read" -Detail "Windows WDSI Package can verify GitHub artifact attestations before preparing Defender submission evidence." -NextAction "Grant attestations: read before calling gh attestation verify."
Test-WorkflowContainsText -Path (Join-Path $repoRoot ".github\workflows\windows-release-asset-mirror.yml") -Name "Windows Release Asset Mirror evidence gate" -Text "protect-windows-release-assets.ps1" -Detail "Windows Release Asset Mirror verifies release evidence before uploading Windows packages to the trusted mirror." -NextAction "Verify release evidence with protect-windows-release-assets.ps1 before mirroring assets."
Test-WorkflowContainsText -Path (Join-Path $repoRoot ".github\workflows\windows-release-asset-mirror.yml") -Name "Windows Release Asset Mirror sync script" -Text "sync-windows-release-assets.ps1" -Detail "Windows Release Asset Mirror uploads only the verified Windows package and evidence asset set." -NextAction "Restore scripts/sync-windows-release-assets.ps1 in the mirror workflow."
Test-WorkflowContainsText -Path (Join-Path $repoRoot "scripts\sync-windows-release-assets.ps1") -Name "Windows Release Asset Mirror package set gate" -Text "Windows EXE, MSI, and portable ZIP are all required before mirroring." -Detail "The mirror upload script refuses incomplete Windows package sets." -NextAction "Restore the complete Windows package set gate in scripts/sync-windows-release-assets.ps1."
Test-WorkflowContainsText -Path (Join-Path $repoRoot "scripts\sync-windows-release-assets.ps1") -Name "Windows Release Asset Mirror evidence set gate" -Text 'windows-wdsi-submission-text-$safeTag.zip' -Detail "The mirror upload script requires SmartScreen, smoke test, WinGet, and WDSI evidence before uploading." -NextAction "Restore the required evidence asset list in scripts/sync-windows-release-assets.ps1."
Test-WorkflowContainsText -Path (Join-Path $repoRoot ".github\workflows\windows-store-package.yml") -Name "Windows Store signing gate" -Text ".\scripts\validate-windows-signing.ps1 -RequireSigning" -Detail "Windows Store EXE/MSI packages always require a configured Windows signing provider." -NextAction "Restore the required signing gate before generating Store EXE/MSI submission packages."
Test-WorkflowContainsText -Path (Join-Path $repoRoot ".github\workflows\windows-store-package.yml") -Name "Windows Store signature manifest gate" -Text '$params.RequireValidSignature = $true' -Detail "Windows Store submission packages require valid Authenticode signatures in the generated package manifest." -NextAction "Restore RequireValidSignature for Store EXE/MSI submission package generation."
Test-WorkflowContainsText -Path (Join-Path $repoRoot "scripts\new-windows-store-submission-package.ps1") -Name "Windows Store product update JSON" -Text "microsoft-store-product-update.json" -Detail "Windows Store submission packages include the product-update JSON used by Microsoft Store Submission." -NextAction "Restore microsoft-store-product-update.json generation in scripts/new-windows-store-submission-package.ps1."
Test-WorkflowContainsText -Path (Join-Path $repoRoot ".github\workflows\windows-store-package.yml") -Name "Windows Store automatic MSI/EXE submission" -Text "microsoft/store-submission@v1" -Detail "Windows Store Package can submit MSI/EXE package updates to Partner Center when explicit publishing inputs and secrets are configured." -NextAction "Restore the optional microsoft/store-submission@v1 steps."
Test-WorkflowContainsText -Path (Join-Path $repoRoot ".github\workflows\windows-store-package.yml") -Name "Windows Store public package URL gate" -Text "package_url_base must point to your own versioned CDN or deployed website" -Detail "Automatic Store MSI/EXE submission rejects GitHub Releases, localhost, and upstream cap.so package URL bases." -NextAction "Restore package_url_base validation before automatic Store submission."
Test-WorkflowContainsText -Path (Join-Path $repoRoot ".github\workflows\windows-msix-store-package.yml") -Name "Windows MSIX Store CLI version" -Text "microsoft/microsoft-store-apppublisher@v1.3" -Detail "Windows MSIX Store Package uses the current Microsoft Store CLI setup action." -NextAction "Update microsoft-store-apppublisher to a current pinned version."
Test-WorkflowContainsText -Path (Join-Path $repoRoot ".github\workflows\windows-msix-store-package.yml") -Name "Windows MSIX explicit publish input" -Text "--inputFile" -Detail "Windows MSIX Store publishing passes the generated MSIX explicitly to msstore publish." -NextAction "Pass the generated MSIX with --inputFile when publishing to Microsoft Store."
Test-WorkflowContainsText -Path (Join-Path $repoRoot ".github\workflows\release-desktop.yml") -Name "Windows release artifact retention" -Text "retention-days: 1" -Detail "Windows Release transfer artifacts are retained briefly to reduce accidental installer distribution through Actions artifacts." -NextAction "Set short retention on Windows Release installer transfer artifacts."
Test-WorkflowContainsText -Path (Join-Path $repoRoot ".github\workflows\windows-store-package.yml") -Name "Windows Store artifact retention" -Text "retention-days: 14" -Detail "Windows Store submission artifacts have bounded retention and are not a long-lived public download channel." -NextAction "Set bounded retention on Windows Store submission artifacts."
Test-WorkflowContainsText -Path (Join-Path $repoRoot ".github\workflows\windows-msix-store-package.yml") -Name "Windows MSIX artifact retention" -Text "retention-days: 14" -Detail "Windows MSIX submission artifacts have bounded retention and are not a long-lived public download channel." -NextAction "Set bounded retention on Windows MSIX submission artifacts."
Test-WorkflowContainsText -Path (Join-Path $repoRoot "apps\web\utils\platform.tsx") -Name "Windows primary download route" -Text 'return "/download/windows";' -Detail "Client download buttons send Windows users through the guarded Windows download route." -NextAction "Route Windows client downloads through /download/windows instead of linking directly to GitHub assets."
Test-WorkflowContainsText -Path (Join-Path $repoRoot "apps\web\app\(site)\download\[platform]\route.ts") -Name "Windows download status fallback" -Text 'new URL("/download/windows-status", request.url)' -Detail "Windows download aliases fall back to the verification status page when no trusted download is available." -NextAction "Restore the /download/windows-status fallback for Windows download aliases."
Test-WorkflowContainsText -Path (Join-Path $repoRoot "apps\web\app\(site)\download\[platform]\route.ts") -Name "Windows portable ZIP route" -Text 'getLatestWindowsDownload("portable")' -Detail "The website exposes the portable ZIP only through the verified Windows download resolver." -NextAction 'Restore the portable ZIP alias through getLatestWindowsDownload("portable").'
Test-WorkflowContainsText -Path (Join-Path $repoRoot "apps\web\utils\releases.ts") -Name "Windows complete package set check" -Text "function hasWindowsPackageSet" -Detail "Web release verification models the required Windows EXE, MSI, and portable ZIP package set." -NextAction "Restore hasWindowsPackageSet in apps/web/utils/releases.ts."
Test-WorkflowContainsText -Path (Join-Path $repoRoot "apps\web\utils\releases.ts") -Name "Windows release evidence package gate" -Text "hasWindowsPackageSet(assets) &&" -Detail "Web release evidence rejects Windows downloads unless EXE, MSI, and portable ZIP are all present." -NextAction "Require hasWindowsPackageSet before returning verified Windows release asset evidence."
Test-WorkflowContainsText -Path (Join-Path $repoRoot "apps\web\utils\releases.ts") -Name "Windows release object package gate" -Text "release.hasWindowsPackageSet &&" -Detail "Web release objects require the complete Windows package set before exposing verified Windows downloads." -NextAction "Require release.hasWindowsPackageSet in hasVerifiedWindowsEvidence."
Test-WorkflowContainsText -Path (Join-Path $repoRoot "apps\web\utils\releases.ts") -Name "Windows release asset mirror" -Text "WINDOWS_RELEASE_ASSET_BASE_URL" -Detail "Verified Windows downloads can be routed through a project-controlled HTTPS release asset mirror." -NextAction "Restore WINDOWS_RELEASE_ASSET_BASE_URL support in apps/web/utils/releases.ts."
Test-WorkflowContainsText -Path (Join-Path $repoRoot "apps\web\utils\releases.ts") -Name "Windows release asset mirror GitHub rejection" -Text 'hostname.endsWith(".github.com")' -Detail "The Windows release asset mirror rejects GitHub URLs so the mirror is not just a disguised GitHub Release redirect." -NextAction "Reject GitHub hostnames in Windows release asset mirror validation."
Test-WorkflowContainsText -Path (Join-Path $repoRoot "apps\web\__tests__\unit\releases.test.ts") -Name "Windows release asset mirror tests" -Text "uses the configured Windows release asset base URL" -Detail "Web tests cover trusted Windows asset mirror URL generation." -NextAction "Restore unit coverage for Windows release asset mirror behavior."
Test-WorkflowContainsText -Path (Join-Path $repoRoot "apps\web\app\api\releases\tauri\[version]\[target]\[arch]\route.ts") -Name "Windows updater release gate" -Text "hasVerifiedWindowsReleaseAssetEvidence(assets, release.tag_name)" -Detail "Windows auto-update metadata is withheld until release assets satisfy the Windows verification gate." -NextAction "Restore the Windows hasVerifiedWindowsReleaseAssetEvidence guard in the Tauri updater API."
Test-WorkflowContainsText -Path (Join-Path $repoRoot "apps\web\app\(site)\download\windows-status\page.tsx") -Name "Windows status verification gate" -Text "hasVerifiedWindowsEvidence(release)" -Detail "The Windows status page only promotes releases that satisfy the full verification gate." -NextAction "Restore hasVerifiedWindowsEvidence on the Windows status page."
Test-WorkflowContainsText -Path (Join-Path $repoRoot "apps\web\app\(site)\download\versions\page.tsx") -Name "Windows versions verification gate" -Text "hasVerifiedWindowsEvidence(release)" -Detail "The versions page only exposes Windows release assets after the full verification gate passes." -NextAction "Restore hasVerifiedWindowsEvidence before linking Windows assets on the versions page."
Test-WorkflowContainsText -Path (Join-Path $repoRoot "apps\desktop\src\utils\download-links.ts") -Name "Desktop guarded download link" -Text "CAP_DOWNLOAD_URL" -Detail "Desktop manual update links open the guarded web download page instead of GitHub Releases." -NextAction "Restore CAP_DOWNLOAD_URL for desktop manual update links."
Test-WorkflowContainsText -Path (Join-Path $repoRoot "apps\desktop\src\utils\download-links.ts") -Name "Desktop guarded versions link" -Text "CAP_PREVIOUS_VERSIONS_URL" -Detail "Desktop previous-version links open the guarded versions page instead of GitHub Releases." -NextAction "Restore CAP_PREVIOUS_VERSIONS_URL for desktop previous-version links."
Test-WorkflowContainsText -Path (Join-Path $repoRoot "apps\desktop\src\utils\download-links.ts") -Name "Desktop configured download URL" -Text "VITE_DOWNLOAD_URL" -Detail "Desktop manual update links can be pinned to a trusted Windows download URL at build time." -NextAction "Restore VITE_DOWNLOAD_URL handling in apps/desktop/src/utils/download-links.ts."
Test-WorkflowContainsText -Path (Join-Path $repoRoot "apps\desktop\src\utils\download-links.ts") -Name "Desktop configured versions URL" -Text "VITE_PREVIOUS_VERSIONS_URL" -Detail "Desktop previous-version links can be pinned to a trusted versions URL at build time." -NextAction "Restore VITE_PREVIOUS_VERSIONS_URL handling in apps/desktop/src/utils/download-links.ts."
Test-WorkflowContainsText -Path (Join-Path $repoRoot "scripts\write-windows-build-env.ps1") -Name "Windows download URL variable" -Text "WINDOWS_DOWNLOAD_URL" -Detail "Windows distributable builds require an explicit trusted download URL." -NextAction "Require WINDOWS_DOWNLOAD_URL before creating Windows release build environments."
Test-WorkflowOmitsText -Path (Join-Path $repoRoot "apps\desktop\src\utils\download-links.ts") -Name "Desktop direct GitHub release link" -Text "CAP_RELEASES_URL" -Detail "Desktop manual update links no longer bypass download verification through a direct GitHub Releases URL." -NextAction "Remove CAP_RELEASES_URL from desktop download links."
Test-WorkflowContainsText -Path (Join-Path $repoRoot "build_package.bat") -Name "Root local Windows package guard" -Text "CAP_ALLOW_LOCAL_UNSIGNED_WINDOWS_BUILD" -Detail "The root local packaging script refuses unsigned Windows distribution builds unless explicitly enabled for local testing." -NextAction "Restore the CAP_ALLOW_LOCAL_UNSIGNED_WINDOWS_BUILD guard in build_package.bat."
Test-WorkflowContainsText -Path (Join-Path $repoRoot "apps\desktop\build_installer.bat") -Name "Desktop local Windows package guard" -Text "CAP_ALLOW_LOCAL_UNSIGNED_WINDOWS_BUILD" -Detail "The desktop local packaging script refuses unsigned Windows distribution builds unless explicitly enabled for local testing." -NextAction "Restore the CAP_ALLOW_LOCAL_UNSIGNED_WINDOWS_BUILD guard in apps/desktop/build_installer.bat."
Test-WorkflowContainsText -Path (Join-Path $repoRoot "apps\desktop\autofix_build.ps1") -Name "Desktop autofix local Windows package guard" -Text "CAP_ALLOW_LOCAL_UNSIGNED_WINDOWS_BUILD" -Detail "The desktop autofix packaging script refuses unsigned Windows distribution builds unless explicitly enabled for local testing." -NextAction "Restore the CAP_ALLOW_LOCAL_UNSIGNED_WINDOWS_BUILD guard in apps/desktop/autofix_build.ps1."

$storeUrl = Get-ConfiguredStoreUrl
if ($storeUrl) {
    Add-Check -Area "Microsoft Store" -Item "Store download URL" -Status "pass" -Detail "Official Microsoft Store URL is configured."
} else {
    Add-Check -Area "Microsoft Store" -Item "Store download URL" -Status "warning" -Detail "No official Microsoft Store URL is configured for /download/windows." -NextAction "After Store approval, set NEXT_PUBLIC_WINDOWS_STORE_URL, WINDOWS_STORE_URL, or CAP_WINDOWS_STORE_URL to the official Microsoft Store HTTPS URL."
}

$windowsDownloadUrl = $env:WINDOWS_DOWNLOAD_URL
if (Test-TrustedWindowsDownloadUrl -Value $windowsDownloadUrl) {
    Add-Check -Area "Distribution path" -Item "Windows download URL" -Status "pass" -Detail "WINDOWS_DOWNLOAD_URL points to a trusted Windows download surface."
} else {
    Add-Check -Area "Distribution path" -Item "Windows download URL" -Status "fail" -Detail "WINDOWS_DOWNLOAD_URL is missing or does not point to Microsoft Store or an HTTPS /download page controlled by this project." -NextAction "Set the GitHub variable WINDOWS_DOWNLOAD_URL to the approved Microsoft Store URL or to the deployed site /download/windows route before building Windows packages."
}

$windowsAssetBaseUrl = Get-ConfiguredWindowsAssetBaseUrl
if (Test-TrustedWindowsAssetBaseUrl -Value $windowsAssetBaseUrl) {
    Add-Check -Area "Distribution path" -Item "Windows release asset mirror" -Status "pass" -Detail "Windows release asset downloads are configured to use a trusted project-controlled HTTPS base URL."
} elseif (-not [string]::IsNullOrWhiteSpace($windowsAssetBaseUrl)) {
    Add-Check -Area "Distribution path" -Item "Windows release asset mirror" -Status "fail" -Detail "Windows release asset mirror URL is not a trusted public HTTPS base URL." -NextAction "Set WINDOWS_RELEASE_ASSET_BASE_URL to your own versioned CDN or deployed website URL, not GitHub Releases, localhost, or upstream cap.so."
} else {
    Add-Check -Area "Distribution path" -Item "Windows release asset mirror" -Status "warning" -Detail "No project-controlled Windows release asset mirror is configured." -NextAction "Set WINDOWS_RELEASE_ASSET_BASE_URL after publishing signed release assets to your own versioned HTTPS CDN or website path."
}

$mirrorUploadInputNames = @(
    "WINDOWS_RELEASE_ASSET_BUCKET",
    "WINDOWS_RELEASE_ASSET_AWS_ACCESS_KEY_ID_SET",
    "WINDOWS_RELEASE_ASSET_AWS_SECRET_ACCESS_KEY_SET"
)
$missingMirrorUploadInputs = @()
foreach ($name in $mirrorUploadInputNames) {
    if ($name.EndsWith("_SET")) {
        if (-not (ConvertTo-Bool ([Environment]::GetEnvironmentVariable($name)))) {
            $missingMirrorUploadInputs += $name
        }
    } elseif ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
        $missingMirrorUploadInputs += $name
    }
}

if (Test-TrustedWindowsAssetBaseUrl -Value $windowsAssetBaseUrl -and $missingMirrorUploadInputs.Count -eq 0) {
    Add-Check -Area "Distribution path" -Item "Windows release asset mirror upload" -Status "pass" -Detail "Windows release asset mirror upload inputs are configured."
} elseif (Test-TrustedWindowsAssetBaseUrl -Value $windowsAssetBaseUrl) {
    Add-Check -Area "Distribution path" -Item "Windows release asset mirror upload" -Status "fail" -Detail "Missing Windows release asset mirror upload inputs: $($missingMirrorUploadInputs -join ', ')." -NextAction "Configure WINDOWS_RELEASE_ASSET_BUCKET and the Windows release asset AWS access key secrets before publishing mirrored downloads."
} else {
    Add-Check -Area "Distribution path" -Item "Windows release asset mirror upload" -Status "warning" -Detail "Windows release asset mirror upload is not configured." -NextAction "Configure the mirror URL, bucket, and upload secrets before using Windows Release Asset Mirror."
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

$providerAliases = @{
    "trusted-signing" = "azure-artifact-signing"
    "azure-trusted-signing" = "azure-artifact-signing"
}

if (-not [string]::IsNullOrWhiteSpace($provider) -and $providerAliases.ContainsKey($provider)) {
    $provider = $providerAliases[$provider]
}

$validProviders = @("azure-artifact-signing", "signpath", "pfx")
$hasValidProvider = $false
if ([string]::IsNullOrWhiteSpace($provider)) {
    Add-Check -Area "Code signing" -Item "Signing provider" -Status "warning" -Detail "WINDOWS_SIGNING_PROVIDER is not configured." -NextAction "Set WINDOWS_SIGNING_PROVIDER to azure-artifact-signing, trusted-signing, signpath, or pfx, then run Windows Signing Check."
} elseif ($validProviders -contains $provider) {
    $hasValidProvider = $true
    Add-Check -Area "Code signing" -Item "Signing provider" -Status "pass" -Detail "WINDOWS_SIGNING_PROVIDER is '$provider'."
} else {
    Add-Check -Area "Code signing" -Item "Signing provider" -Status "fail" -Detail "Unsupported WINDOWS_SIGNING_PROVIDER '$provider'." -NextAction "Use azure-artifact-signing, trusted-signing, signpath, or pfx."
}

if (Test-RegexValue -Value $env:WINDOWS_SIGNING_PUBLISHER_PATTERN) {
    Add-Check -Area "Code signing" -Item "Publisher pattern" -Status "pass" -Detail "WINDOWS_SIGNING_PUBLISHER_PATTERN is configured and is a valid regex."
} elseif ($hasValidProvider) {
    Add-Check -Area "Code signing" -Item "Publisher pattern" -Status "fail" -Detail "WINDOWS_SIGNING_PUBLISHER_PATTERN is missing or invalid while a signing provider is configured." -NextAction "Set it to a regex matching the Authenticode subject of the real publisher certificate before building signed Windows releases."
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

if ($storeUrl -or $hasValidProvider) {
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
            $hasPortableZip = @($assetNames | Where-Object { $_ -match "windows.*portable.*\.zip$" }).Count -gt 0
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
            if (-not $hasPortableZip) { $missingEvidence += "Windows portable ZIP" }
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
                Add-Check -Area "Latest release" -Item "$($latestRelease.tag_name) evidence assets" -Status "pass" -Detail "Latest public Windows release has all download gate evidence assets."
            } else {
                $evidenceStatus = if ($storeUrl) { "warning" } else { "fail" }
                Add-Check -Area "Latest release" -Item "$($latestRelease.tag_name) evidence assets" -Status $evidenceStatus -Detail "Missing evidence: $($missingEvidence -join ', ')." -NextAction "Publish a new signed Windows release through the Windows Release workflow, or configure the official Microsoft Store URL."
            }

            try {
                $quarantineResult = Get-ReleaseQuarantineResult -Tag $latestRelease.tag_name -Repository $Repository -OutputRoot $outputFullPath
                if ([bool]$quarantineResult.verifiedWindowsRelease) {
                    Add-Check -Area "Latest release" -Item "$($latestRelease.tag_name) evidence manifest" -Status "pass" -Detail "Release asset manifest confirms valid signature, timestamp, SignTool, checksum, attestation, and Defender status for each Windows release package."
                } else {
                    $manifestStatus = if ($storeUrl) { "warning" } else { "fail" }
                    $manifestFailures = @($quarantineResult.manifestFailures)
                    if ($manifestFailures.Count -gt 0) {
                        Add-Check -Area "Latest release" -Item "$($latestRelease.tag_name) evidence manifest" -Status $manifestStatus -Detail "Release asset manifest is not valid: $($manifestFailures -join ' ')" -NextAction "Publish a new signed Windows release through the Windows Release workflow, then let Windows Release Audit regenerate the manifest."
                    } else {
                        Add-Check -Area "Latest release" -Item "$($latestRelease.tag_name) evidence manifest" -Status $manifestStatus -Detail "Release evidence is present but does not satisfy every verified Windows release gate." -NextAction "Review the generated quarantine report before promoting this Release."
                    }
                }
            } catch {
                $manifestValidationStatus = if ($storeUrl) { "warning" } else { "fail" }
                Add-Check -Area "Latest release" -Item "$($latestRelease.tag_name) evidence manifest" -Status $manifestValidationStatus -Detail "Release asset manifest could not be validated: $($_.Exception.Message)" -NextAction "Re-run with GITHUB_TOKEN available or inspect the Release evidence manifest manually."
            }
        } else {
            $releaseStatus = if ($storeUrl) { "warning" } else { "fail" }
            Add-Check -Area "Latest release" -Item "Public cap-v release" -Status $releaseStatus -Detail "No public cap-v release was found." -NextAction "Publish a signed Windows release, or configure the official Microsoft Store URL after Store approval."
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
