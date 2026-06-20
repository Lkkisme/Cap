param(
    [Parameter(Mandatory = $true)]
    [string]$Tag,
    [string]$Repository = "Lkkisme/Cap",
    [string]$OutputDirectory = "",
    [switch]$RequireValidSignatures
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path (Get-Location) ".release-verification\$Tag"
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$releaseUrl = "https://api.github.com/repos/$Repository/releases/tags/$Tag"
$release = Invoke-RestMethod -Uri $releaseUrl
$assets = @($release.assets | Where-Object { $_.name -match "windows" -and $_.name -match "\.(exe|msi)$" })

if ($assets.Count -eq 0) {
    throw "No Windows EXE/MSI assets found on release tag '$Tag'."
}

$rows = @()

foreach ($asset in $assets) {
    $filePath = Join-Path $OutputDirectory $asset.name
    $existingFile = Get-Item -LiteralPath $filePath -ErrorAction SilentlyContinue
    if (-not $existingFile -or $existingFile.Length -ne $asset.size) {
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $filePath
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

    if ($RequireValidSignatures -and $signature.Status -ne "Valid") {
        throw "$($asset.name) signature is $($signature.Status): $($signature.StatusMessage)"
    }

    $rows += [pscustomobject]@{
        File = $asset.name
        Sha256 = $hash.Hash
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
$lines += "| File | SHA256 | Signature | Publisher |"
$lines += "| --- | --- | --- | --- |"

foreach ($row in $rows) {
    $lines += '| `{0}` | `{1}` | `{2}` | {3} |' -f $row.File, $row.Sha256, $row.SignatureStatus, $row.Publisher
}

$lines += ""
$lines += "## WDSI Submission Text"
$lines += ""
$lines += 'Submit as `Software developer` at https://www.microsoft.com/en-us/wdsi/filesubmission.'
$lines += ""

foreach ($row in $rows) {
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

$rows | Format-Table File, Sha256, SignatureStatus, Publisher -AutoSize
Write-Output "Checksums: $checksumPath"
Write-Output "Report: $reportPath"
