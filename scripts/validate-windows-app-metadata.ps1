param(
    [string]$ExpectedPublisher = $env:WINDOWS_PACKAGE_PUBLISHER
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ExpectedPublisher)) {
    $ExpectedPublisher = "Lkkisme"
}

function Assert-Value {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$tauriConfigPath = Join-Path $repoRoot "apps\desktop\src-tauri\tauri.conf.json"
$tauriProdConfigPath = Join-Path $repoRoot "apps\desktop\src-tauri\tauri.prod.conf.json"
$tauriGithubReleaseConfigPath = Join-Path $repoRoot "apps\desktop\src-tauri\tauri.github-release.conf.json"
$tauriStoreConfigPath = Join-Path $repoRoot "apps\desktop\src-tauri\tauri.microsoft-store.conf.json"
$cargoTomlPath = Join-Path $repoRoot "apps\desktop\src-tauri\Cargo.toml"
$tauriConfig = Get-Content -Raw -Encoding UTF8 -LiteralPath $tauriConfigPath | ConvertFrom-Json
$tauriProdConfigRaw = Get-Content -Raw -Encoding UTF8 -LiteralPath $tauriProdConfigPath
$tauriProdConfig = $tauriProdConfigRaw | ConvertFrom-Json
$tauriGithubReleaseConfig = Get-Content -Raw -Encoding UTF8 -LiteralPath $tauriGithubReleaseConfigPath | ConvertFrom-Json
$tauriStoreConfig = Get-Content -Raw -Encoding UTF8 -LiteralPath $tauriStoreConfigPath | ConvertFrom-Json
$cargoToml = Get-Content -Raw -Encoding UTF8 -LiteralPath $cargoTomlPath
$expectedProductName = "Cap $([char]0x4E2D)$([char]0x6587)$([char]0x7248)"

Assert-Value ($tauriConfig.productName -eq $expectedProductName) "tauri.conf.json productName must be the stable Chinese Cap product name."
Assert-Value ($tauriConfig.identifier -eq "so.cap.desktop.cn") "tauri.conf.json identifier must be 'so.cap.desktop.cn'."
Assert-Value ($tauriConfig.mainBinaryName -eq "Cap-CN") "tauri.conf.json mainBinaryName must be 'Cap-CN'."
Assert-Value ($tauriConfig.bundle.publisher -eq $ExpectedPublisher) "bundle.publisher must be '$ExpectedPublisher'."
Assert-Value ($tauriConfig.bundle.homepage -eq "https://github.com/Lkkisme/Cap") "bundle.homepage must point to the public GitHub repository."
Assert-Value ($tauriConfig.bundle.license -eq "AGPL-3.0-only") "bundle.license must be AGPL-3.0-only."
Assert-Value ($tauriConfig.bundle.category -eq "Productivity") "bundle.category must be Productivity."
Assert-Value (-not [string]::IsNullOrWhiteSpace($tauriConfig.bundle.shortDescription)) "bundle.shortDescription must be set."
Assert-Value (-not [string]::IsNullOrWhiteSpace($tauriConfig.bundle.longDescription)) "bundle.longDescription must be set."

$licensePath = Resolve-Path (Join-Path (Split-Path -Parent $tauriConfigPath) $tauriConfig.bundle.licenseFile)
Assert-Value (Test-Path -LiteralPath $licensePath) "bundle.licenseFile must resolve to an existing file."

Assert-Value ($tauriConfig.bundle.windows.wix.upgradeCode -match "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$") "bundle.windows.wix.upgradeCode must be a stable GUID."
Assert-Value ($tauriConfig.bundle.windows.wix.language -eq "zh-CN") "bundle.windows.wix.language must be zh-CN."
Assert-Value (@($tauriConfig.bundle.windows.nsis.languages) -contains "SimpChinese") "bundle.windows.nsis.languages must include SimpChinese."
Assert-Value ($tauriGithubReleaseConfig.bundle.windows.webviewInstallMode.type -eq "offlineInstaller") "tauri.github-release.conf.json must use offline WebView2 installation."
Assert-Value ($tauriStoreConfig.bundle.windows.webviewInstallMode.type -eq "offlineInstaller") "tauri.microsoft-store.conf.json must use offline WebView2 installation."
Assert-Value ($tauriProdConfig.plugins.updater.active -eq $false) "tauri.prod.conf.json updater must be disabled for forked Windows builds."
Assert-Value ($tauriProdConfigRaw -notmatch "cdn\.crabnebula\.app/update") "tauri.prod.conf.json must not point to the upstream CrabNebula updater."

Assert-Value ($cargoToml -match '(?m)^authors\s*=\s*\["Lkkisme"\]') "Cargo.toml authors must be ['Lkkisme']."
Assert-Value ($cargoToml -notmatch '(?m)^authors\s*=\s*\["you"\]') "Cargo.toml authors must not use the placeholder 'you'."
Assert-Value ($cargoToml -match '(?m)^homepage\s*=\s*"https://github\.com/Lkkisme/Cap"') "Cargo.toml homepage must point to the public GitHub repository."
Assert-Value ($cargoToml -match '(?m)^license\s*=\s*"AGPL-3\.0-only"') "Cargo.toml license must be AGPL-3.0-only."

Write-Host "Windows package metadata is configured for publisher '$ExpectedPublisher'."
