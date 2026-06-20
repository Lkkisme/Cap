param(
  [string]$Repository = $env:GITHUB_REPOSITORY,
  [ValidateSet("report", "mark_prerelease")]
  [string]$Mode = "report",
  [string]$OutputDirectory = "windows-release-quarantine",
  [ValidateRange(1, 100)]
  [int]$PerPage = 100,
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
  "User-Agent" = "cap-public-windows-release-quarantine"
}

if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
  $headers.Authorization = "Bearer $env:GITHUB_TOKEN"
}

function Invoke-GitHubApi {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Method,
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  Invoke-RestMethod -Method $Method -Headers $headers -Uri "https://api.github.com/repos/$Repository/$Path"
}

function Get-PublicCapReleases {
  $allReleases = @()
  $page = 1

  while ($true) {
    $pageReleases = @(Invoke-GitHubApi -Method "GET" -Path "releases?per_page=$PerPage&page=$page")

    if ($pageReleases.Count -eq 0) {
      break
    }

    $allReleases += $pageReleases

    if ($pageReleases.Count -lt $PerPage) {
      break
    }

    $page += 1
  }

  $allReleases | Where-Object { -not $_.draft -and -not $_.prerelease -and $_.tag_name -like "cap-v*" }
}

$outputFullPath = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
  [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
  [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputDirectory))
}

if (Test-Path -LiteralPath $outputFullPath) {
  Remove-Item -LiteralPath $outputFullPath -Recurse -Force
}
New-Item -ItemType Directory -Path $outputFullPath -Force | Out-Null

$releases = @(Get-PublicCapReleases)

$results = @()
foreach ($release in $releases) {
  $tag = [string]$release.tag_name
  $safeTag = ($tag -replace '[^A-Za-z0-9._-]', '-').ToLowerInvariant()
  $releaseOutputDirectory = Join-Path $outputFullPath $safeTag
  $confirmation = if ($Mode -eq "mark_prerelease") { "mark-prerelease:$tag" } else { "" }
  $params = @{
    Repository = $Repository
    Tag = $tag
    Mode = $Mode
    Confirmation = $confirmation
    OutputDirectory = $releaseOutputDirectory
  }

  & (Join-Path $PSScriptRoot "protect-windows-release-assets.ps1") @params | Out-Null

  $releaseReportPath = Join-Path $releaseOutputDirectory "windows-release-quarantine-report.json"
  if (-not (Test-Path -LiteralPath $releaseReportPath)) {
    throw "Windows release quarantine report was not generated for '$tag'."
  }

  $results += Get-Content -Raw -LiteralPath $releaseReportPath | ConvertFrom-Json
}

$unsafeResults = @($results | Where-Object { [bool]$_.unsafeWindowsRelease })
$actionResults = @($results | Where-Object { $_.actionTaken -ne "report_only" })
$summary = [ordered]@{
  repository = $Repository
  mode = $Mode
  inspectedTags = @($results | ForEach-Object { $_.tag })
  unsafeTags = @($unsafeResults | ForEach-Object { $_.tag })
  actionTakenTags = @($actionResults | ForEach-Object { $_.tag })
  results = $results
  generatedAt = (Get-Date).ToUniversalTime().ToString("o")
}

$jsonPath = Join-Path $outputFullPath "public-windows-release-quarantine-report.json"
$reportPath = Join-Path $outputFullPath "public-windows-release-quarantine-report.md"
$summary | ConvertTo-Json -Depth 12 | Set-Content -Encoding UTF8 -LiteralPath $jsonPath

$lines = @(
  "# Public Windows Release Quarantine Report",
  "",
  "- Repository: $Repository",
  "- Mode: $Mode",
  "- Inspected releases: $($results.Count)",
  "- Unsafe Windows releases: $($unsafeResults.Count)",
  "- Actions taken: $($actionResults.Count)",
  "",
  "## Releases"
)

if ($results.Count -eq 0) {
  $lines += "- None"
} else {
  foreach ($result in $results) {
    $lines += "- $($result.tag): unsafe=$($result.unsafeWindowsRelease), verified=$($result.verifiedWindowsRelease), action=$($result.actionTaken)"
  }
}

if ($unsafeResults.Count -gt 0) {
  $lines += @(
    "",
    "## Unsafe release details"
  )

  foreach ($result in $unsafeResults) {
    $failures = @($result.manifestFailures)
    $detail = if ($failures.Count -gt 0) { $failures -join " " } else { "Evidence assets or manifest gates are incomplete." }
    $lines += "- $($result.tag): $detail"
  }
}

$lines | Set-Content -Encoding UTF8 -LiteralPath $reportPath
Get-Content -LiteralPath $reportPath

if ($FailOnUnsafe -and $Mode -eq "report" -and $unsafeResults.Count -gt 0) {
  throw "Unsafe public Windows release assets were found."
}
