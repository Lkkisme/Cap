param(
    [Parameter(Mandatory = $true)]
    [string]$Tag,
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [string]$OutputDirectory = "windows-release-asset-mirror",
    [string]$Bucket = $env:WINDOWS_RELEASE_ASSET_BUCKET,
    [string]$Prefix = $env:WINDOWS_RELEASE_ASSET_PREFIX,
    [string]$BaseUrl = $env:WINDOWS_RELEASE_ASSET_BASE_URL,
    [string]$EndpointUrl = $env:WINDOWS_RELEASE_ASSET_S3_ENDPOINT_URL,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Bucket)) {
    throw "WINDOWS_RELEASE_ASSET_BUCKET is required."
}

if ([string]::IsNullOrWhiteSpace($Prefix)) {
    $Prefix = "cap/windows"
}

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    throw "WINDOWS_RELEASE_ASSET_BASE_URL is required."
}

if ($Tag.Contains("/") -or $Tag.Contains("\") -or $Tag -match "\p{C}") {
    throw "Tag contains characters that are not supported for mirrored asset keys."
}

function Get-SafeTag {
    param([string]$Value)

    ($Value -replace '[^A-Za-z0-9._-]', '-').ToLowerInvariant()
}

function Test-TrustedBaseUrl {
    param([string]$Value)

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

function Get-PublicUrl {
    param(
        [string]$FileName
    )

    $encodedTag = [System.Uri]::EscapeDataString($Tag)
    $encodedFileName = [System.Uri]::EscapeDataString($FileName)
    if ($BaseUrl.Contains("{tag}") -or $BaseUrl.Contains("{filename}")) {
        return $BaseUrl.Replace("{tag}", $encodedTag).Replace("{filename}", $encodedFileName)
    }

    $BaseUrl.TrimEnd("/") + "/" + $encodedTag + "/" + $encodedFileName
}

function Get-ContentType {
    param([System.IO.FileInfo]$File)

    switch ($File.Extension.ToLowerInvariant()) {
        ".exe" { "application/vnd.microsoft.portable-executable" }
        ".msi" { "application/octet-stream" }
        ".zip" { "application/zip" }
        ".txt" { "text/plain; charset=utf-8" }
        ".md" { "text/markdown; charset=utf-8" }
        ".json" { "application/json; charset=utf-8" }
        default { "application/octet-stream" }
    }
}

function New-AssetRecord {
    param([System.IO.FileInfo]$File)

    $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $File.FullName
    $keyPrefix = $Prefix.Trim("/")
    [pscustomobject]@{
        File = $File.Name
        LocalPath = $File.FullName
        Key = "$keyPrefix/$Tag/$($File.Name)"
        Url = Get-PublicUrl -FileName $File.Name
        SizeBytes = $File.Length
        Sha256 = $hash.Hash.ToUpperInvariant()
        ContentType = Get-ContentType -File $File
    }
}

function Invoke-AwsUpload {
    param([object]$Asset)

    $destination = "s3://$Bucket/$($Asset.Key)"
    $arguments = @(
        "s3",
        "cp",
        $Asset.LocalPath,
        $destination,
        "--content-type",
        $Asset.ContentType,
        "--only-show-errors"
    )

    if (-not [string]::IsNullOrWhiteSpace($EndpointUrl)) {
        $arguments += @("--endpoint-url", $EndpointUrl)
    }

    if ($DryRun) {
        Write-Host "DRY RUN aws $($arguments -join ' ')"
        return
    }

    & aws @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "aws upload failed for $($Asset.File)."
    }
}

if (-not (Test-TrustedBaseUrl -Value $BaseUrl)) {
    throw "WINDOWS_RELEASE_ASSET_BASE_URL must be a trusted public HTTPS URL and cannot point to GitHub Releases, localhost, or upstream cap.so."
}

if (-not $DryRun -and -not (Get-Command aws -ErrorAction SilentlyContinue)) {
    throw "aws CLI is required to upload Windows release assets."
}

$assetDirectory = (Resolve-Path -LiteralPath $Path).Path
$outputFullPath = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
    [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputDirectory))
}
New-Item -ItemType Directory -Path $outputFullPath -Force | Out-Null

$files = @(Get-ChildItem -LiteralPath $assetDirectory -File)
$safeTag = Get-SafeTag -Value $Tag
$packageAssets = @(
    $files | Where-Object {
        $name = $_.Name.ToLowerInvariant()
        $name.Contains("windows") -and ($name.EndsWith(".exe") -or $name.EndsWith(".msi") -or ($name.Contains("portable") -and $name.EndsWith(".zip")))
    }
)

$hasExe = @($packageAssets | Where-Object { $_.Name.ToLowerInvariant().EndsWith(".exe") }).Count -gt 0
$hasMsi = @($packageAssets | Where-Object { $_.Name.ToLowerInvariant().EndsWith(".msi") }).Count -gt 0
$hasPortableZip = @($packageAssets | Where-Object { $name = $_.Name.ToLowerInvariant(); $name.Contains("portable") -and $name.EndsWith(".zip") }).Count -gt 0
if (-not $hasExe -or -not $hasMsi -or -not $hasPortableZip) {
    throw "Windows EXE, MSI, and portable ZIP are all required before mirroring."
}

$requiredEvidenceNames = @(
    "SHA256SUMS.txt",
    "windows-smartscreen-report-$safeTag.md",
    "windows-release-assets-$safeTag.json",
    "windows-installer-smoke-test-report-$safeTag.md",
    "windows-installer-smoke-test-results-$safeTag.json",
    "windows-winget-manifest-$safeTag.zip",
    "windows-winget-submission-$safeTag.md",
    "windows-wdsi-submission-checklist-$safeTag.md",
    "windows-wdsi-submission-text-$safeTag.zip"
)

$fileByName = @{}
foreach ($file in $files) {
    $fileByName[$file.Name.ToLowerInvariant()] = $file
}

$evidenceAssets = @()
foreach ($name in $requiredEvidenceNames) {
    $key = $name.ToLowerInvariant()
    if (-not $fileByName.ContainsKey($key)) {
        throw "Required release evidence asset is missing: $name"
    }
    $evidenceAssets += $fileByName[$key]
}

$plannedAssets = @($packageAssets + $evidenceAssets | Sort-Object FullName -Unique | ForEach-Object { New-AssetRecord -File $_ })
$manifestName = "windows-release-asset-mirror-$safeTag.json"
$manifestPath = Join-Path $outputFullPath $manifestName
$manifest = [pscustomobject]@{
    Tag = $Tag
    Bucket = $Bucket
    Prefix = $Prefix
    BaseUrl = $BaseUrl
    EndpointUrl = $EndpointUrl
    DryRun = [bool]$DryRun
    GeneratedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    Assets = @($plannedAssets | ForEach-Object {
        [pscustomobject]@{
            File = $_.File
            Key = $_.Key
            Url = $_.Url
            SizeBytes = $_.SizeBytes
            Sha256 = $_.Sha256
            ContentType = $_.ContentType
        }
    })
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath $manifestPath

$manifestAsset = New-AssetRecord -File (Get-Item -LiteralPath $manifestPath)
$uploadAssets = @($plannedAssets + $manifestAsset)
foreach ($asset in $uploadAssets) {
    Invoke-AwsUpload -Asset $asset
}

$reportPath = Join-Path $outputFullPath "windows-release-asset-mirror-$safeTag.md"
$lines = @(
    "# Windows Release Asset Mirror",
    "",
    "Tag: $Tag",
    "Bucket: $Bucket",
    "Prefix: $Prefix",
    "Base URL: $BaseUrl",
    "Dry run: $([bool]$DryRun)",
    "",
    "| File | URL | SHA256 |",
    "| --- | --- | --- |"
)
foreach ($asset in $uploadAssets) {
    $lines += "| $($asset.File) | $($asset.Url) | $($asset.Sha256) |"
}
$lines | Set-Content -Encoding UTF8 -LiteralPath $reportPath
Get-Content -LiteralPath $reportPath
