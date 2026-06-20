param(
    [Parameter(Mandatory = $true)]
    [string]$Tag,
    [string]$Repository = "Lkkisme/Cap",
    [string]$PackageIdentifier = "Lkkisme.CapCN",
    [string]$PackageVersion = "",
    [string]$PackageLocale = "zh-CN",
    [string]$Publisher = "Lkkisme",
    [string]$PackageName = "Cap 中文版",
    [string]$PackageUrl = "https://github.com/Lkkisme/Cap",
    [string]$License = "AGPL-3.0-only",
    [string]$LicenseUrl = "https://github.com/Lkkisme/Cap/blob/main/LICENSE",
    [string]$ShortDescription = "中文屏幕录制工具",
    [ValidateSet("msi", "exe")]
    [string]$InstallerPreference = "msi",
    [string]$OutputRoot = "",
    [string]$GitHubToken = $env:GITHUB_TOKEN
)

$ErrorActionPreference = "Stop"

function ConvertTo-YamlString {
    param([string]$Value)
    '"' + $Value.Replace("\", "\\").Replace('"', '\"') + '"'
}

function Join-PathPart {
    param([string]$Base, [string]$Child)
    Join-Path -Path $Base -ChildPath $Child
}

function Get-MsiProperty {
    param(
        [string]$Path,
        [string]$Property
    )

    $installer = New-Object -ComObject WindowsInstaller.Installer
    $database = $installer.GetType().InvokeMember("OpenDatabase", "InvokeMethod", $null, $installer, @($Path, 0))
    $view = $database.GetType().InvokeMember("OpenView", "InvokeMethod", $null, $database, @("SELECT Value FROM Property WHERE Property = '$Property'"))
    $view.GetType().InvokeMember("Execute", "InvokeMethod", $null, $view, $null) | Out-Null
    $record = $view.GetType().InvokeMember("Fetch", "InvokeMethod", $null, $view, $null)

    if (-not $record) {
        return ""
    }

    $record.GetType().InvokeMember("StringData", "GetProperty", $null, $record, 1)
}

if ([string]::IsNullOrWhiteSpace($PackageVersion)) {
    $PackageVersion = $Tag
    if ($PackageVersion.StartsWith("cap-v")) {
        $PackageVersion = $PackageVersion.Substring(5)
    } elseif ($PackageVersion.StartsWith("v")) {
        $PackageVersion = $PackageVersion.Substring(1)
    }
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path (Get-Location) "packaging\winget"
}

$identifierParts = @($PackageIdentifier.Split(".") | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if ($identifierParts.Count -lt 2) {
    throw "PackageIdentifier must use Publisher.Package format."
}

$publisherFolder = $identifierParts[0]
$applicationFolder = ($identifierParts | Select-Object -Skip 1) -join "."
$letterFolder = $publisherFolder.Substring(0, 1).ToLowerInvariant()

$headers = @{
    "User-Agent" = "cap-winget-manifest-generator"
    "Accept" = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}

if (-not [string]::IsNullOrWhiteSpace($GitHubToken)) {
    $headers["Authorization"] = "Bearer $GitHubToken"
}

$releaseUrl = "https://api.github.com/repos/$Repository/releases/tags/$Tag"
$release = Invoke-RestMethod -Uri $releaseUrl -Headers $headers
$windowsAssets = @($release.assets | Where-Object { $_.name -match "windows" -and $_.name -match "\.(exe|msi)$" })
$checksumAsset = $release.assets | Where-Object { $_.name -eq "SHA256SUMS.txt" } | Select-Object -First 1

if (-not $checksumAsset) {
    throw "Release tag '$Tag' does not include SHA256SUMS.txt."
}

if ($windowsAssets.Count -eq 0) {
    throw "No Windows EXE/MSI assets found on release tag '$Tag'."
}

$expectedExtension = if ($InstallerPreference -eq "msi") { "\.msi$" } else { "\.exe$" }
$asset = $windowsAssets | Where-Object { $_.name -match $expectedExtension } | Select-Object -First 1

if (-not $asset) {
    throw "No Windows $InstallerPreference asset found on release tag '$Tag'."
}

$tempDir = Join-Path $env:TEMP "cap-winget-$Tag"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$checksumPath = Join-Path $tempDir "SHA256SUMS.txt"
Invoke-WebRequest -Uri $checksumAsset.browser_download_url -Headers $headers -OutFile $checksumPath

$expectedHashes = @{}
foreach ($line in Get-Content -LiteralPath $checksumPath) {
    if ($line -match "^\s*([A-Fa-f0-9]{64})\s+\*?(.+?)\s*$") {
        $expectedHashes[$matches[2]] = $matches[1].ToUpperInvariant()
    }
}

if (-not $expectedHashes.ContainsKey($asset.name)) {
    throw "$($asset.name) is missing from SHA256SUMS.txt."
}

$installerPathForInspection = Join-Path $tempDir $asset.name
Invoke-WebRequest -Uri $asset.browser_download_url -Headers $headers -OutFile $installerPathForInspection
$installerHash = Get-FileHash -Algorithm SHA256 -LiteralPath $installerPathForInspection
if ($installerHash.Hash.ToUpperInvariant() -ne $expectedHashes[$asset.name]) {
    throw "$($asset.name) downloaded SHA256 does not match SHA256SUMS.txt."
}

$installerType = if ($asset.name -match "\.msi$") { "wix" } else { "nullsoft" }
$silentSwitch = if ($installerType -eq "wix") { "/quiet /norestart" } else { "/S" }
$silentWithProgressSwitch = if ($installerType -eq "wix") { "/passive /norestart" } else { "/S" }
$logSwitch = if ($installerType -eq "wix") { "/L*v <LOGPATH>" } else { "" }
$upgradeCode = ""
$productCode = ""

if ($installerType -eq "wix") {
    $productCode = Get-MsiProperty -Path $installerPathForInspection -Property "ProductCode"
    $tauriConfigPath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")) "apps\desktop\src-tauri\tauri.conf.json"
    $tauriConfig = Get-Content -Raw -Encoding UTF8 -LiteralPath $tauriConfigPath | ConvertFrom-Json
    $upgradeCode = $tauriConfig.bundle.windows.wix.upgradeCode
}

$manifestRoot = Join-PathPart -Base $OutputRoot -Child "manifests"
$manifestRoot = Join-PathPart -Base $manifestRoot -Child $letterFolder
$manifestRoot = Join-PathPart -Base $manifestRoot -Child $publisherFolder
$manifestRoot = Join-PathPart -Base $manifestRoot -Child $applicationFolder
$manifestRoot = Join-PathPart -Base $manifestRoot -Child $PackageVersion
New-Item -ItemType Directory -Path $manifestRoot -Force | Out-Null

$versionPath = Join-Path $manifestRoot "$PackageIdentifier.yaml"
$localePath = Join-Path $manifestRoot "$PackageIdentifier.locale.$PackageLocale.yaml"
$installerPath = Join-Path $manifestRoot "$PackageIdentifier.installer.yaml"

@(
    "PackageIdentifier: $(ConvertTo-YamlString $PackageIdentifier)",
    "PackageVersion: $(ConvertTo-YamlString $PackageVersion)",
    "DefaultLocale: $(ConvertTo-YamlString $PackageLocale)",
    "ManifestType: version",
    "ManifestVersion: 1.12.0"
) | Set-Content -Encoding UTF8 -Path $versionPath

@(
    "PackageIdentifier: $(ConvertTo-YamlString $PackageIdentifier)",
    "PackageVersion: $(ConvertTo-YamlString $PackageVersion)",
    "PackageLocale: $(ConvertTo-YamlString $PackageLocale)",
    "Publisher: $(ConvertTo-YamlString $Publisher)",
    "PackageName: $(ConvertTo-YamlString $PackageName)",
    "PackageUrl: $(ConvertTo-YamlString $PackageUrl)",
    "License: $(ConvertTo-YamlString $License)",
    "LicenseUrl: $(ConvertTo-YamlString $LicenseUrl)",
    "ShortDescription: $(ConvertTo-YamlString $ShortDescription)",
    "Tags:",
    "- screen-recorder",
    "- screen-capture",
    "- recording",
    "- productivity",
    "ManifestType: defaultLocale",
    "ManifestVersion: 1.12.0"
) | Set-Content -Encoding UTF8 -Path $localePath

$installerLines = @(
    "PackageIdentifier: $(ConvertTo-YamlString $PackageIdentifier)",
    "PackageVersion: $(ConvertTo-YamlString $PackageVersion)",
    "Platform:",
    "- Windows.Desktop",
    "MinimumOSVersion: 10.0.17763.0",
    "InstallerType: $(ConvertTo-YamlString $installerType)",
    "InstallModes:",
    "- silent",
    "- silentWithProgress",
    "InstallerSwitches:",
    "  Silent: $(ConvertTo-YamlString $silentSwitch)",
    "  SilentWithProgress: $(ConvertTo-YamlString $silentWithProgressSwitch)"
)

if (-not [string]::IsNullOrWhiteSpace($logSwitch)) {
    $installerLines += "  Log: $(ConvertTo-YamlString $logSwitch)"
}

$installerLines += @(
    "Installers:",
    "- Architecture: x64",
    "  InstallerUrl: $(ConvertTo-YamlString $asset.browser_download_url)",
    "  InstallerSha256: $($expectedHashes[$asset.name])"
)

if (-not [string]::IsNullOrWhiteSpace($productCode)) {
    $installerLines += "  ProductCode: $(ConvertTo-YamlString $productCode)"
}

if (-not [string]::IsNullOrWhiteSpace($upgradeCode)) {
    $installerLines += "UpgradeBehavior: install"
    $installerLines += "AppsAndFeaturesEntries:"
    $appsAndFeaturesEntry = @()
    if (-not [string]::IsNullOrWhiteSpace($productCode)) {
        $appsAndFeaturesEntry += "  ProductCode: $(ConvertTo-YamlString $productCode)"
    }
    $appsAndFeaturesEntry += "  UpgradeCode: $(ConvertTo-YamlString $upgradeCode)"
    $installerLines += "- $($appsAndFeaturesEntry[0].TrimStart())"
    if ($appsAndFeaturesEntry.Count -gt 1) {
        $installerLines += $appsAndFeaturesEntry[1..($appsAndFeaturesEntry.Count - 1)]
    }
}

$installerLines += "ManifestType: installer"
$installerLines += "ManifestVersion: 1.12.0"
$installerLines | Set-Content -Encoding UTF8 -Path $installerPath

Get-ChildItem -LiteralPath $manifestRoot -File | Select-Object FullName, Length | Format-Table -AutoSize
Write-Output "WinGet manifest directory: $manifestRoot"
