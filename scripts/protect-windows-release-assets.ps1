param(
  [Parameter(Mandatory = $true)]
  [string]$Tag,
  [string]$Repository = $env:GITHUB_REPOSITORY,
  [ValidateSet("report", "mark_prerelease", "delete_windows_assets")]
  [string]$Mode = "report",
  [string]$Confirmation = "",
  [string]$OutputDirectory = "windows-release-quarantine",
  [switch]$FailOnUnsafe
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Repository)) {
  throw "Repository is required."
}

if ([string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN) -and $Mode -ne "report") {
  throw "GITHUB_TOKEN is required."
}

$headers = @{
  Accept = "application/vnd.github+json"
  "X-GitHub-Api-Version" = "2022-11-28"
  "User-Agent" = "cap-windows-release-quarantine"
}

if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
  $headers.Authorization = "Bearer $env:GITHUB_TOKEN"
}

function Invoke-GitHubApi {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Method,
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [object]$Body = $null
  )

  $uri = "https://api.github.com/repos/$Repository/$Path"
  $params = @{
    Method = $Method
    Uri = $uri
    Headers = $headers
  }

  if ($null -ne $Body) {
    $params.Body = $Body | ConvertTo-Json -Depth 10
    $params.ContentType = "application/json"
  }

  Invoke-RestMethod @params
}

function Test-EvidenceAsset {
  param(
    [string[]]$Names,
    [string]$AssetName
  )

  $Names -contains $AssetName.ToLowerInvariant()
}

function Assert-Confirmation {
  param([string]$Expected)

  if ($Confirmation -ne $Expected) {
    throw "Mode '$Mode' requires confirmation '$Expected'."
  }
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$encodedTag = [System.Uri]::EscapeDataString($Tag)
$safeTag = ($Tag -replace '[^A-Za-z0-9._-]', '-').ToLowerInvariant()
$release = Invoke-GitHubApi -Method "GET" -Path "releases/tags/$encodedTag"
$assets = @($release.assets)
$assetNames = @($assets | ForEach-Object { $_.name.ToLowerInvariant() })
$windowsAssets = @(
  $assets | Where-Object {
    $name = $_.name.ToLowerInvariant()
    $name.EndsWith(".exe") -or $name.EndsWith(".msi")
  }
)

$evidence = [ordered]@{
  hasChecksums = $assetNames -contains "sha256sums.txt"
  hasWindowsAuditReport = Test-EvidenceAsset -Names $assetNames -AssetName "windows-smartscreen-report-$safeTag.md"
  hasWindowsAuditAssets = Test-EvidenceAsset -Names $assetNames -AssetName "windows-release-assets-$safeTag.json"
  hasInstallerSmokeReport = Test-EvidenceAsset -Names $assetNames -AssetName "windows-installer-smoke-test-report-$safeTag.md"
  hasInstallerSmokeResults = Test-EvidenceAsset -Names $assetNames -AssetName "windows-installer-smoke-test-results-$safeTag.json"
  hasWingetManifest = Test-EvidenceAsset -Names $assetNames -AssetName "windows-winget-manifest-$safeTag.zip"
  hasWingetSubmission = Test-EvidenceAsset -Names $assetNames -AssetName "windows-winget-submission-$safeTag.md"
  hasWdsiChecklist = Test-EvidenceAsset -Names $assetNames -AssetName "windows-wdsi-submission-checklist-$safeTag.md"
  hasWdsiSubmissionText = Test-EvidenceAsset -Names $assetNames -AssetName "windows-wdsi-submission-text-$safeTag.zip"
}

$verifiedWindowsRelease = -not ($evidence.Values -contains $false)
$unsafeWindowsRelease = $windowsAssets.Count -gt 0 -and -not $verifiedWindowsRelease
$actionTaken = "report_only"
$deletedAssets = @()

if ($unsafeWindowsRelease -and $Mode -eq "mark_prerelease") {
  Assert-Confirmation -Expected "mark-prerelease:$Tag"
  Invoke-GitHubApi -Method "PATCH" -Path "releases/$($release.id)" -Body @{ prerelease = $true } | Out-Null
  $actionTaken = "marked_prerelease"
}

if ($unsafeWindowsRelease -and $Mode -eq "delete_windows_assets") {
  Assert-Confirmation -Expected "delete-windows-assets:$Tag"
  foreach ($asset in $windowsAssets) {
    Invoke-GitHubApi -Method "DELETE" -Path "releases/assets/$($asset.id)" | Out-Null
    $deletedAssets += $asset.name
  }
  $actionTaken = "deleted_windows_assets"
}

$result = [ordered]@{
  repository = $Repository
  tag = $Tag
  releaseUrl = $release.html_url
  draft = [bool]$release.draft
  prerelease = [bool]$release.prerelease
  mode = $Mode
  actionTaken = $actionTaken
  windowsAssets = @($windowsAssets | ForEach-Object { $_.name })
  deletedAssets = $deletedAssets
  evidence = $evidence
  verifiedWindowsRelease = $verifiedWindowsRelease
  unsafeWindowsRelease = $unsafeWindowsRelease
  generatedAt = (Get-Date).ToUniversalTime().ToString("o")
}

$jsonPath = Join-Path $OutputDirectory "windows-release-quarantine-report.json"
$reportPath = Join-Path $OutputDirectory "windows-release-quarantine-report.md"
$result | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 -Path $jsonPath

$lines = @(
  "# Windows Release Quarantine Report",
  "",
  "- Repository: $Repository",
  "- Tag: $Tag",
  "- Release: $($release.html_url)",
  "- Mode: $Mode",
  "- Action taken: $actionTaken",
  "- Verified Windows release: $verifiedWindowsRelease",
  "- Unsafe Windows release: $unsafeWindowsRelease",
  "",
  "## Windows installer assets"
)

if ($windowsAssets.Count -eq 0) {
  $lines += "- None"
} else {
  foreach ($asset in $windowsAssets) {
    $lines += "- $($asset.name)"
  }
}

$lines += @(
  "",
  "## Evidence"
)

foreach ($item in $evidence.GetEnumerator()) {
  $mark = if ($item.Value) { "x" } else { " " }
  $lines += "- [$mark] $($item.Key)"
}

if ($deletedAssets.Count -gt 0) {
  $lines += @(
    "",
    "## Deleted assets"
  )
  foreach ($asset in $deletedAssets) {
    $lines += "- $asset"
  }
}

$lines | Set-Content -Encoding UTF8 -Path $reportPath
Get-Content -LiteralPath $reportPath

if ($FailOnUnsafe -and $unsafeWindowsRelease -and $actionTaken -eq "report_only") {
  throw "Unsafe Windows release assets were found."
}
