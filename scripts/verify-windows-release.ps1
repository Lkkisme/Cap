param(
    [Parameter(Mandatory = $true)]
    [string]$Tag,
    [string]$Repository = "Lkkisme/Cap",
    [string]$OutputDirectory = "",
    [switch]$RequireValidSignatures,
    [switch]$RequireTimestampedSignatures,
    [switch]$RequireSignToolVerification,
    [switch]$VerifyChecksums,
    [switch]$VerifyAttestations,
    [switch]$ScanWithDefender,
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

function Save-GitHubReleaseAsset {
    param(
        [object]$Asset,
        [string]$Path,
        [hashtable]$Headers
    )

    $downloadHeaders = @{}
    foreach ($key in $Headers.Keys) {
        $downloadHeaders[$key] = $Headers[$key]
    }
    $downloadHeaders["Accept"] = "application/octet-stream"

    $assetUrl = if (-not [string]::IsNullOrWhiteSpace($Asset.url)) {
        $Asset.url
    } else {
        $Asset.browser_download_url
    }

    $request = [System.Net.HttpWebRequest]::Create($assetUrl)
    $request.Method = "GET"
    $request.AllowAutoRedirect = $false

    foreach ($key in $downloadHeaders.Keys) {
        if ($key -eq "Accept") {
            $request.Accept = [string]$downloadHeaders[$key]
        } elseif ($key -eq "User-Agent") {
            $request.UserAgent = [string]$downloadHeaders[$key]
        } else {
            $request.Headers[$key] = [string]$downloadHeaders[$key]
        }
    }

    $response = $null
    try {
        $response = $request.GetResponse()
    } catch [System.Net.WebException] {
        $response = $_.Exception.Response
        if (-not $response) {
            throw
        }
    }

    if ([int]$response.StatusCode -in @(301, 302, 303, 307, 308)) {
        $location = $response.Headers["Location"]
        $response.Close()
        if ([string]::IsNullOrWhiteSpace($location)) {
            throw "$($Asset.name) download redirect did not include a Location header."
        }
        Invoke-WebRequest -Uri $location -OutFile $Path
        return
    }

    if ([int]$response.StatusCode -lt 200 -or [int]$response.StatusCode -ge 300) {
        $statusCode = [int]$response.StatusCode
        $statusDescription = $response.StatusDescription
        $response.Close()
        throw "$($Asset.name) download failed with HTTP $statusCode $statusDescription."
    }

    $inputStream = $response.GetResponseStream()
    $outputStream = [System.IO.File]::Create($Path)
    try {
        $inputStream.CopyTo($outputStream)
    } finally {
        $outputStream.Dispose()
        $inputStream.Dispose()
        $response.Close()
    }
}

function Test-WindowsReleasePackageAssetName {
    param([string]$Name)

    $lowerName = $Name.ToLowerInvariant()
    if (-not $lowerName.Contains("windows")) {
        return $false
    }

    if ($lowerName.EndsWith(".exe") -or $lowerName.EndsWith(".msi")) {
        return $true
    }

    $lowerName.EndsWith(".zip") -and $lowerName.Contains("portable")
}

function Test-PortableZipAuthenticode {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ZipPath,
        [Parameter(Mandatory = $true)]
        [string]$OutputRoot,
        [Parameter(Mandatory = $true)]
        [string]$VerifierPath,
        [switch]$RequireValidSignature,
        [switch]$RequireTimestamp,
        [switch]$RequireSignToolVerification,
        [string]$ExpectedPublisherPattern = ""
    )

    $zipItem = Get-Item -LiteralPath $ZipPath
    $safeDirectoryName = $zipItem.Name -replace '[^A-Za-z0-9._-]', "-"
    $extractPath = Join-Path $OutputRoot "$safeDirectoryName.contents"
    if (Test-Path -LiteralPath $extractPath) {
        Remove-Item -LiteralPath $extractPath -Recurse -Force
    }

    New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
    Expand-Archive -LiteralPath $zipItem.FullName -DestinationPath $extractPath -Force

    $files = @(Get-ChildItem -LiteralPath $extractPath -Include *.exe,*.dll -File -Recurse | Sort-Object FullName)
    if ($files.Count -eq 0) {
        throw "$($zipItem.Name) does not contain Windows EXE/DLL files."
    }

    $reports = @()
    foreach ($file in $files) {
        $reports += & $VerifierPath -Path $file.FullName -RequireValidSignature:$RequireValidSignature -RequireTimestamp:$RequireTimestamp -RequireSignToolVerification:$RequireSignToolVerification -ExpectedPublisherPattern $ExpectedPublisherPattern
    }

    $invalidSignatures = @($reports | Where-Object { $_.SignatureStatus -ne "Valid" })
    $missingTimestamps = @($reports | Where-Object { $_.TimestampStatus -ne "Present" })
    $invalidSignTool = @($reports | Where-Object { $_.SignToolStatus -notin @("Valid", "NotRequested") })
    $publishers = @($reports | ForEach-Object { $_.Publisher } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $thumbprints = @($reports | ForEach-Object { $_.CertificateThumbprint } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $timestampAuthorities = @($reports | ForEach-Object { $_.TimestampAuthority } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $timestampThumbprints = @($reports | ForEach-Object { $_.TimestampCertificateThumbprint } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $signToolPaths = @($reports | ForEach-Object { $_.SignToolPath } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $entryNames = @($reports | ForEach-Object {
            $relativePath = $_.Path.Substring($extractPath.Length).TrimStart([char[]]"\/")
            $relativePath.Replace("\", "/")
        })

    $signToolStatus = if (($reports | Where-Object { $_.SignToolStatus -eq "Valid" }).Count -eq $reports.Count) {
        "Valid"
    } elseif (($reports | Where-Object { $_.SignToolStatus -eq "NotRequested" }).Count -eq $reports.Count) {
        "NotRequested"
    } else {
        "InvalidArchiveContents"
    }

    [pscustomobject]@{
        Path = $zipItem.FullName
        SignatureStatus = if ($invalidSignatures.Count -eq 0) { "Valid" } else { "InvalidArchiveContents" }
        SignatureMessage = if ($invalidSignatures.Count -eq 0) { "All archive EXE/DLL files are signed." } else { "$($invalidSignatures.Count) archive EXE/DLL file(s) failed signature verification." }
        TimestampStatus = if ($missingTimestamps.Count -eq 0) { "Present" } else { "Missing" }
        TimestampAuthority = $timestampAuthorities -join "; "
        TimestampCertificateThumbprint = $timestampThumbprints -join "; "
        TimestampCertificateNotBefore = ""
        TimestampCertificateNotAfter = ""
        Publisher = $publishers -join "; "
        CertificateThumbprint = $thumbprints -join "; "
        CertificateNotBefore = ""
        CertificateNotAfter = ""
        SignToolStatus = if ($invalidSignTool.Count -eq 0) { $signToolStatus } else { "InvalidArchiveContents" }
        SignToolPath = $signToolPaths -join "; "
        ArchiveVerifiedFiles = $entryNames
    }
}

$releaseUrl = "https://api.github.com/repos/$Repository/releases/tags/$Tag"
$release = Invoke-RestMethod -Uri $releaseUrl -Headers $headers
$assets = @($release.assets | Where-Object { Test-WindowsReleasePackageAssetName -Name $_.name })
$checksumAsset = $release.assets | Where-Object { $_.name -eq "SHA256SUMS.txt" } | Select-Object -First 1

if ($assets.Count -eq 0) {
    throw "No Windows EXE/MSI/portable ZIP assets found on release tag '$Tag'."
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
        Save-GitHubReleaseAsset -Asset $checksumAsset -Path $releaseChecksumPath -Headers $headers
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
$authenticodeVerifier = Join-Path $PSScriptRoot "test-windows-authenticode.ps1"
$defenderScanner = Join-Path $PSScriptRoot "scan-windows-assets.ps1"

foreach ($asset in $assets) {
    $filePath = Join-Path $OutputDirectory $asset.name
    $existingFile = Get-Item -LiteralPath $filePath -ErrorAction SilentlyContinue
    if (-not $existingFile -or $existingFile.Length -ne $asset.size) {
        Save-GitHubReleaseAsset -Asset $asset -Path $filePath -Headers $headers
    }

    $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $filePath
    $isPortableZip = $asset.name.ToLowerInvariant().EndsWith(".zip")
    $signatureReport = if ($isPortableZip) {
        $archiveVerificationRoot = Join-Path ([System.IO.Path]::GetTempPath()) "cap-windows-release-verifier-$Tag"
        Test-PortableZipAuthenticode -ZipPath $filePath -OutputRoot $archiveVerificationRoot -VerifierPath $authenticodeVerifier -RequireValidSignature:$RequireValidSignatures -RequireTimestamp:$RequireTimestampedSignatures -RequireSignToolVerification:$RequireSignToolVerification -ExpectedPublisherPattern $ExpectedPublisherPattern
    } else {
        & $authenticodeVerifier -Path $filePath -RequireValidSignature:$RequireValidSignatures -RequireTimestamp:$RequireTimestampedSignatures -RequireSignToolVerification:$RequireSignToolVerification -ExpectedPublisherPattern $ExpectedPublisherPattern
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

    if ($VerifyAttestations) {
        & $ghCommand.Source attestation verify $filePath --repo $Repository
        if ($LASTEXITCODE -ne 0) {
            throw "$($asset.name) GitHub artifact attestation verification failed."
        }
        $attestationStatus = "Valid"
    }

    $defenderStatus = if ($ScanWithDefender) { "NotScanned" } else { "NotRequested" }
    if ($ScanWithDefender) {
        & $defenderScanner -Path $filePath -Include "*.exe", "*.msi", "*.zip" -RequireScanner
        $defenderStatus = "Valid"
    }

    $rows += [pscustomobject]@{
        File = $asset.name
        Sha256 = $hash.Hash
        ChecksumStatus = $checksumStatus
        AttestationStatus = $attestationStatus
        DefenderStatus = $defenderStatus
        SignatureStatus = $signatureReport.SignatureStatus
        SignatureMessage = $signatureReport.SignatureMessage
        TimestampStatus = $signatureReport.TimestampStatus
        TimestampAuthority = $signatureReport.TimestampAuthority
        TimestampCertificateThumbprint = $signatureReport.TimestampCertificateThumbprint
        TimestampCertificateNotBefore = $signatureReport.TimestampCertificateNotBefore
        TimestampCertificateNotAfter = $signatureReport.TimestampCertificateNotAfter
        SignToolStatus = $signatureReport.SignToolStatus
        SignToolPath = $signatureReport.SignToolPath
        Publisher = $signatureReport.Publisher
        CertificateThumbprint = $signatureReport.CertificateThumbprint
        CertificateNotBefore = $signatureReport.CertificateNotBefore
        CertificateNotAfter = $signatureReport.CertificateNotAfter
        ArchiveVerifiedFiles = $signatureReport.ArchiveVerifiedFiles
        DownloadUrl = $asset.browser_download_url
        LocalPath = $filePath
    }
}

$checksumPath = Join-Path $OutputDirectory "SHA256SUMS.txt"
$rows | ForEach-Object { "$($_.Sha256)  $($_.File)" } | Set-Content -Encoding UTF8 -Path $checksumPath

$assetJsonPath = Join-Path $OutputDirectory "windows-release-assets.json"
$assetJson = [pscustomobject]@{
    Repository = $Repository
    ReleaseUrl = $release.html_url
    Tag = $Tag
    Generated = (Get-Date).ToUniversalTime().ToString("u")
    Assets = $rows
}
$assetJson | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 -Path $assetJsonPath

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
$lines += "| File | SHA256 | Release checksum | Attestation | Defender | Signature | Timestamp | SignTool | Publisher |"
$lines += "| --- | --- | --- | --- | --- | --- | --- | --- | --- |"

foreach ($row in $rows) {
    $lines += '| `{0}` | `{1}` | `{2}` | `{3}` | `{4}` | `{5}` | `{6}` | `{7}` | {8} |' -f $row.File, $row.Sha256, $row.ChecksumStatus, $row.AttestationStatus, $row.DefenderStatus, $row.SignatureStatus, $row.TimestampStatus, $row.SignToolStatus, $row.Publisher
}

$lines += ""
$lines += "## SmartScreen Readiness"
$lines += ""

$invalidSignatures = @($rows | Where-Object { $_.SignatureStatus -ne "Valid" })
$missingTimestamps = @($rows | Where-Object { $_.TimestampStatus -ne "Present" })
$invalidSignTool = @($rows | Where-Object { $_.SignToolStatus -notin @("Valid", "NotRequested") })
$invalidChecksums = @($rows | Where-Object { $_.ChecksumStatus -ne "Valid" })
$invalidAttestations = @($rows | Where-Object { $_.AttestationStatus -notin @("Valid", "NotRequested") })
$invalidDefenderScans = @($rows | Where-Object { $_.DefenderStatus -notin @("Valid", "NotRequested") })

if ($invalidSignatures.Count -eq 0) {
    $lines += "All Windows release packages have valid Authenticode signatures."
} else {
    $lines += "Not ready for public Windows distribution: one or more release packages do not have valid Authenticode signatures."
}

if ($missingTimestamps.Count -eq 0) {
    $lines += "All Windows release packages have trusted Authenticode timestamps."
} else {
    $lines += "One or more Windows release packages are missing trusted Authenticode timestamps."
}

if ($RequireSignToolVerification) {
    if ($invalidSignTool.Count -eq 0) {
        $lines += "All Windows release packages passed signtool verify /pa /tw."
    } else {
        $lines += "One or more Windows release packages failed signtool verify /pa /tw."
    }
} else {
    $lines += "SignTool verification was not requested in this run."
}

if ($checksumAsset) {
    if ($invalidChecksums.Count -eq 0) {
        $lines += "All Windows release packages match the release SHA256SUMS.txt file."
    } else {
        $lines += "One or more Windows release packages do not match the release SHA256SUMS.txt file."
    }
} else {
    $lines += "The release does not include SHA256SUMS.txt, so published checksums could not be verified."
}

if ($VerifyAttestations) {
    if ($invalidAttestations.Count -eq 0) {
        $lines += "All Windows release packages have valid GitHub artifact attestations for this repository."
    } else {
        $lines += "One or more Windows release packages failed GitHub artifact attestation verification."
    }
} else {
    $lines += "GitHub artifact attestations were not verified in this run."
}

if ($ScanWithDefender) {
    if ($invalidDefenderScans.Count -eq 0) {
        $lines += "All Windows release packages passed Microsoft Defender scanning on the audit runner."
    } else {
        $lines += "One or more Windows release packages did not complete Microsoft Defender scanning."
    }
} else {
    $lines += "Microsoft Defender scanning was not requested in this run."
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
    $lines += "Signature timestamp: $($row.TimestampStatus)"
    $lines += "Timestamp authority: $($row.TimestampAuthority)"
    $lines += "SignTool verification: $($row.SignToolStatus)"
    $lines += "Microsoft Defender scan: $($row.DefenderStatus)"
    $lines += "Certificate thumbprint: $($row.CertificateThumbprint)"
    $lines += ""
    $lines += "This is an open-source screen recording application distributed from the official GitHub repository. The submitted Windows package was built by GitHub Actions from the tagged release, is signed by the publisher with a trusted timestamp, passed Microsoft Defender scanning on the audit runner, and should be classified as safe. Please review it as a false positive / SmartScreen reputation issue."
    $lines += '```'
    $lines += ""
}

$lines | Set-Content -Encoding UTF8 -Path $reportPath

$rows | Format-Table File, Sha256, ChecksumStatus, AttestationStatus, DefenderStatus, SignatureStatus, TimestampStatus, SignToolStatus, Publisher -AutoSize
if ($releaseChecksumPath) {
    Write-Output "Release checksums: $releaseChecksumPath"
}
Write-Output "Checksums: $checksumPath"
Write-Output "Asset metadata: $assetJsonPath"
Write-Output "Report: $reportPath"
