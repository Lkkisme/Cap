param(
    [Parameter(Mandatory = $true)]
    [string]$Tag,
    [string]$Repository = "Lkkisme/Cap",
    [string]$OutputDirectory = "",
    [string]$ExpectedPublisherPattern = "",
    [string]$ProductName = "Cap $([char]0x4E2D)$([char]0x6587)$([char]0x7248)",
    [string]$GitHubToken = $env:GITHUB_TOKEN
)

$ErrorActionPreference = "Stop"

function Get-SafeFileName {
    param([string]$Name)

    $safe = $Name
    foreach ($char in [System.IO.Path]::GetInvalidFileNameChars()) {
        $safe = $safe.Replace($char, "_")
    }
    $safe
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path (Get-Location) ".release-verification\$Tag"
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$verifyParams = @{
    Tag = $Tag
    Repository = $Repository
    OutputDirectory = $OutputDirectory
    RequireValidSignatures = $true
    RequireTimestampedSignatures = $true
    RequireSignToolVerification = $true
    VerifyChecksums = $true
    VerifyAttestations = $true
    ScanWithDefender = $true
    GitHubToken = $GitHubToken
}

if (-not [string]::IsNullOrWhiteSpace($ExpectedPublisherPattern)) {
    $verifyParams.ExpectedPublisherPattern = $ExpectedPublisherPattern
}

& (Join-Path $PSScriptRoot "verify-windows-release.ps1") @verifyParams

$assetJsonPath = Join-Path $OutputDirectory "windows-release-assets.json"
if (-not (Test-Path -LiteralPath $assetJsonPath)) {
    throw "Asset metadata was not generated."
}

$metadata = Get-Content -Raw -Encoding UTF8 -LiteralPath $assetJsonPath | ConvertFrom-Json
$packageRoot = Join-Path $OutputDirectory "wdsi-submission-package"
$installersDir = Join-Path $packageRoot "installers"
$evidenceDir = Join-Path $packageRoot "evidence"
$textDir = Join-Path $packageRoot "submission-text"

New-Item -ItemType Directory -Path $installersDir -Force | Out-Null
New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null
New-Item -ItemType Directory -Path $textDir -Force | Out-Null

$evidenceFiles = @(
    "windows-smartscreen-report.md",
    "windows-release-assets.json",
    "SHA256SUMS.txt",
    "release-SHA256SUMS.txt"
)

foreach ($file in $evidenceFiles) {
    $source = Join-Path $OutputDirectory $file
    if (Test-Path -LiteralPath $source) {
        Copy-Item -LiteralPath $source -Destination (Join-Path $evidenceDir $file) -Force
    }
}

foreach ($asset in @($metadata.Assets)) {
    if ($asset.SignatureStatus -ne "Valid") {
        throw "$($asset.File) is not ready for WDSI because its signature status is $($asset.SignatureStatus)."
    }
    if ($asset.TimestampStatus -ne "Present") {
        throw "$($asset.File) is not ready for WDSI because its timestamp status is $($asset.TimestampStatus)."
    }
    if ($asset.SignToolStatus -ne "Valid") {
        throw "$($asset.File) is not ready for WDSI because its SignTool status is $($asset.SignToolStatus)."
    }
    if ($asset.ChecksumStatus -ne "Valid") {
        throw "$($asset.File) is not ready for WDSI because its checksum status is $($asset.ChecksumStatus)."
    }
    if ($asset.AttestationStatus -ne "Valid") {
        throw "$($asset.File) is not ready for WDSI because its attestation status is $($asset.AttestationStatus)."
    }
    if ($asset.DefenderStatus -ne "Valid") {
        throw "$($asset.File) is not ready for WDSI because its Microsoft Defender scan status is $($asset.DefenderStatus)."
    }

    Copy-Item -LiteralPath $asset.LocalPath -Destination (Join-Path $installersDir $asset.File) -Force

    $safeName = Get-SafeFileName -Name $asset.File
    $submissionTextPath = Join-Path $textDir "$safeName.txt"
    @(
        "Product: $ProductName",
        "Publisher: $($asset.Publisher)",
        "Repository: https://github.com/$Repository",
        "Release: $($metadata.ReleaseUrl)",
        "Tag: $Tag",
        "File: $($asset.File)",
        "SHA256: $($asset.Sha256)",
        "Signature status: $($asset.SignatureStatus)",
        "Signature timestamp: $($asset.TimestampStatus)",
        "Timestamp authority: $($asset.TimestampAuthority)",
        "SignTool verification: $($asset.SignToolStatus)",
        "Microsoft Defender scan: $($asset.DefenderStatus)",
        "Certificate thumbprint: $($asset.CertificateThumbprint)",
        "GitHub artifact attestation: $($asset.AttestationStatus)",
        "",
        "This is an open-source screen recording application distributed from the official GitHub repository. The submitted Windows package was built by GitHub Actions from the tagged release, is signed by the publisher with a trusted timestamp, has a matching release checksum, passed Microsoft Defender scanning on the audit runner, and has a valid GitHub artifact attestation for the official repository. Please review it as a false positive / SmartScreen reputation issue."
    ) | Set-Content -Encoding UTF8 -LiteralPath $submissionTextPath
}

$checklistPath = Join-Path $packageRoot "wdsi-submission-checklist.md"
@(
    "# WDSI Submission Checklist",
    "",
    "Product: $ProductName",
    "Repository: https://github.com/$Repository",
    "Release: $($metadata.ReleaseUrl)",
    "Tag: $Tag",
    "",
    "1. Go to https://www.microsoft.com/en-us/wdsi/filesubmission.",
    "2. Choose Software developer.",
    "3. Submit each Windows package from the installers directory.",
    "4. Paste the matching text from the submission-text directory.",
    "5. Attach or reference the evidence files if Microsoft asks for more context.",
    "",
    "The Windows packages in this bundle have valid Authenticode signatures, trusted Authenticode timestamps, passing signtool verify /pa /tw results, matching release checksums, passing Microsoft Defender scans, and valid GitHub artifact attestations."
) | Set-Content -Encoding UTF8 -LiteralPath $checklistPath

$zipPath = Join-Path $OutputDirectory "wdsi-submission-package-$Tag.zip"
Compress-Archive -Path (Join-Path $packageRoot "*") -DestinationPath $zipPath -Force

Write-Output "WDSI package: $packageRoot"
Write-Output "WDSI package archive: $zipPath"
