param(
    [Parameter(Mandatory = $true)]
    [string]$Tag,
    [string]$Repository = "Lkkisme/Cap",
    [string]$OutputDirectory = "",
    [switch]$RequireValidSignatures,
    [switch]$VerifyChecksums,
    [switch]$VerifyAttestations,
    [string]$ExpectedPublisherPattern = "",
    [string]$GitHubToken = $env:GITHUB_TOKEN
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path (Get-Location) ".release-verification\$Tag"
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$headers = @{
    "User-Agent" = "cap-windows-release-verifier"
    "Accept" = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}

if (-not [string]::IsNullOrWhiteSpace($GitHubToken)) {
    $headers["Authorization"] = "Bearer $GitHubToken"
}

$releaseUrl = "https://api.github.com/repos/$Repository/releases/tags/$Tag"
$release = Invoke-RestMethod -Uri $releaseUrl -Headers $headers
$assets = @($release.assets | Where-Object { $_.name -match "windows" -and $_.name -match "\.(exe|msi)$" })
$checksumAsset = $release.assets | Where-Object { $_.name -eq "SHA256SUMS.txt" } | Select-Object -First 1

if ($assets.Count -eq 0) {
    throw "No Windows EXE/MSI assets found on release tag '$Tag'."
}

if ($VerifyChecksums -and -not $checksumAsset) {
    throw "Release tag '$Tag' does not include SHA256SUMS.txt."
}

$expectedHashes = @{}
$releaseChecksumPath = ""

if ($checksumAsset) {
    $releaseChecksumPath = Join-Path $OutputDirectory "release-SHA256SUMS.txt"
    $existingChecksumFile = Get-Item -LiteralPath $releaseChecksumPath -ErrorAction SilentlyContinue
    if (-not $existingChecksumFile -or $existingChecksumFile.Length -ne $checksumAsset.size) {
        Invoke-WebRequest -Uri $checksumAsset.browser_download_url -Headers $headers -OutFile $releaseChecksumPath
    }

    foreach ($line in Get-Content -LiteralPath $releaseChecksumPath) {
        if ($line -match "^\s*([A-Fa-f0-9]{64})\s+\*?(.+?)\s*$") {
            $expectedHashes[$matches[2]] = $matches[1].ToUpperInvariant()
        }
    }
}

if ($VerifyChecksums -and $expectedHashes.Count -eq 0) {
    throw "Release tag '$Tag' has no parseable SHA256 entries."
}

$ghCommand = $null
if ($VerifyAttestations) {
    $ghCommand = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $ghCommand) {
        throw "GitHub CLI 'gh' is required when -VerifyAttestations is used."
    }

    if (-not [string]::IsNullOrWhiteSpace($GitHubToken) -and [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
        $env:GITHUB_TOKEN = $GitHubToken
    }
}

$rows = @()

foreach ($asset in $assets) {
    $filePath = Join-Path $OutputDirectory $asset.name
    $existingFile = Get-Item -LiteralPath $filePath -ErrorAction SilentlyContinue
    if (-not $existingFile -or $existingFile.Length -ne $asset.size) {
        Invoke-WebRequest -Uri $asset.browser_download_url -Headers $headers -OutFile $filePath
    }

    $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $filePath
    $signature = Get-AuthenticodeSignature -LiteralPath $filePath
    $publisher = ""
    $thumbprint = ""
    $notBefore = ""
    $notAfter = ""

    if ($signature.SignerCertificate) {
        $publisher = $signature.SignerCertificate.Subject
        $thumbprint = $signature.SignerCertificate.Thumbprint
        $notBefore = $signature.SignerCertificate.NotBefore.ToString("u")
        $notAfter = $signature.SignerCertificate.NotAfter.ToString("u")
    }

    $attestationStatus = if ($VerifyAttestations) { "NotVerified" } else { "NotRequested" }

    $checksumStatus = "NoReleaseChecksum"
    if ($expectedHashes.Count -gt 0) {
        if ($expectedHashes.ContainsKey($asset.name)) {
            if ($expectedHashes[$asset.name] -eq $hash.Hash.ToUpperInvariant()) {
                $checksumStatus = "Valid"
            } else {
                $checksumStatus = "Mismatch"
            }
        } else {
            $checksumStatus = "MissingFromReleaseChecksum"
        }
    }

    if ($VerifyChecksums -and $checksumStatus -ne "Valid") {
        throw "$($asset.name) checksum status is $checksumStatus."
    }

    if ($RequireValidSignatures -and $signature.Status -ne "Valid") {
        throw "$($asset.name) signature is $($signature.Status): $($signature.StatusMessage)"
    }

    if (-not [string]::IsNullOrWhiteSpace($ExpectedPublisherPattern) -and $signature.Status -eq "Valid" -and $publisher -notmatch $ExpectedPublisherPattern) {
        throw "$($asset.name) publisher '$publisher' does not match expected pattern '$ExpectedPublisherPattern'."
    }

    if ($VerifyAttestations) {
        & $ghCommand.Source attestation verify $filePath --repo $Repository
        if ($LASTEXITCODE -ne 0) {
            throw "$($asset.name) GitHub artifact attestation verification failed."
        }
        $attestationStatus = "Valid"
    }

    $rows += [pscustomobject]@{
        File = $asset.name
        Sha256 = $hash.Hash
        ChecksumStatus = $checksumStatus
        AttestationStatus = $attestationStatus
        SignatureStatus = $signature.Status.ToString()
        SignatureMessage = $signature.StatusMessage
        Publisher = $publisher
        CertificateThumbprint = $thumbprint
        CertificateNotBefore = $notBefore
        CertificateNotAfter = $notAfter
        DownloadUrl = $asset.browser_download_url
        LocalPath = $filePath
    }
}

$checksumPath = Join-Path $OutputDirectory "SHA256SUMS.txt"
$rows | ForEach-Object { "$($_.Sha256)  $($_.File)" } | Set-Content -Encoding UTF8 -Path $checksumPath

$reportPath = Join-Path $OutputDirectory "windows-smartscreen-report.md"
$lines = @()
$lines += "# Windows SmartScreen Verification Report"
$lines += ""
$lines += "Repository: https://github.com/$Repository"
$lines += "Release: $($release.html_url)"
$lines += "Tag: $Tag"
$lines += "Generated: $((Get-Date).ToUniversalTime().ToString("u"))"
$lines += ""
$lines += "## Assets"
$lines += ""
$lines += "| File | SHA256 | Release checksum | Attestation | Signature | Publisher |"
$lines += "| --- | --- | --- | --- | --- | --- |"

foreach ($row in $rows) {
    $lines += '| `{0}` | `{1}` | `{2}` | `{3}` | `{4}` | {5} |' -f $row.File, $row.Sha256, $row.ChecksumStatus, $row.AttestationStatus, $row.SignatureStatus, $row.Publisher
}

$lines += ""
$lines += "## SmartScreen Readiness"
$lines += ""

$invalidSignatures = @($rows | Where-Object { $_.SignatureStatus -ne "Valid" })
$invalidChecksums = @($rows | Where-Object { $_.ChecksumStatus -ne "Valid" })
$invalidAttestations = @($rows | Where-Object { $_.AttestationStatus -notin @("Valid", "NotRequested") })

if ($invalidSignatures.Count -eq 0) {
    $lines += "All Windows installers have valid Authenticode signatures."
} else {
    $lines += "Not ready for public Windows distribution: one or more installers do not have valid Authenticode signatures."
}

if ($checksumAsset) {
    if ($invalidChecksums.Count -eq 0) {
        $lines += "All Windows installers match the release SHA256SUMS.txt file."
    } else {
        $lines += "One or more Windows installers do not match the release SHA256SUMS.txt file."
    }
} else {
    $lines += "The release does not include SHA256SUMS.txt, so published checksums could not be verified."
}

if ($VerifyAttestations) {
    if ($invalidAttestations.Count -eq 0) {
        $lines += "All Windows installers have valid GitHub artifact attestations for this repository."
    } else {
        $lines += "One or more Windows installers failed GitHub artifact attestation verification."
    }
} else {
    $lines += "GitHub artifact attestations were not verified in this run."
}

if (-not [string]::IsNullOrWhiteSpace($ExpectedPublisherPattern)) {
    $lines += "Expected publisher pattern: $ExpectedPublisherPattern"
}

$lines += ""
$lines += "## WDSI Submission Text"
$lines += ""
$lines += 'Submit as `Software developer` at https://www.microsoft.com/en-us/wdsi/filesubmission.'
$lines += ""

foreach ($row in $rows) {
    if ($row.SignatureStatus -ne "Valid") {
        $lines += '`{0}` is not ready for WDSI false positive submission because its Authenticode status is `{1}`.' -f $row.File, $row.SignatureStatus
        $lines += ""
        continue
    }

    $lines += '```text'
    $lines += "Product: Cap CN"
    $lines += "Publisher: $($row.Publisher)"
    $lines += "Repository: https://github.com/$Repository"
    $lines += "Release: $($release.html_url)"
    $lines += "File: $($row.File)"
    $lines += "SHA256: $($row.Sha256)"
    $lines += "Signature status: $($row.SignatureStatus)"
    $lines += "Certificate thumbprint: $($row.CertificateThumbprint)"
    $lines += ""
    $lines += "This is an open-source screen recording application distributed from the official GitHub repository. The submitted installer was built by GitHub Actions from the tagged release, is signed by the publisher, and should be classified as safe. Please review it as a false positive / SmartScreen reputation issue."
    $lines += '```'
    $lines += ""
}

$lines | Set-Content -Encoding UTF8 -Path $reportPath

$rows | Format-Table File, Sha256, ChecksumStatus, AttestationStatus, SignatureStatus, Publisher -AutoSize
if ($releaseChecksumPath) {
    Write-Output "Release checksums: $releaseChecksumPath"
}
Write-Output "Checksums: $checksumPath"
Write-Output "Report: $reportPath"
