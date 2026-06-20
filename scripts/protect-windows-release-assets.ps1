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

function Read-ReleaseAssetText {
  param([object]$Asset)

  $downloadHeaders = @{}
  foreach ($key in $headers.Keys) {
    $downloadHeaders[$key] = $headers[$key]
  }
  $downloadHeaders.Accept = "application/octet-stream"

  $request = [System.Net.HttpWebRequest]::Create($Asset.url)
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
    return (Invoke-WebRequest -Uri $location).Content
  }

  if ([int]$response.StatusCode -lt 200 -or [int]$response.StatusCode -ge 300) {
    $statusCode = [int]$response.StatusCode
    $statusDescription = $response.StatusDescription
    $response.Close()
    throw "$($Asset.name) download failed with HTTP $statusCode $statusDescription."
  }

  $reader = [System.IO.StreamReader]::new($response.GetResponseStream(), [System.Text.Encoding]::UTF8)
  try {
    $reader.ReadToEnd()
  } finally {
    $reader.Dispose()
    $response.Close()
  }
}

function Get-ObjectPropertyValue {
  param(
    [object]$InputObject,
    [string]$Name
  )

  if ($null -eq $InputObject) {
    return $null
  }

  $property = $InputObject.PSObject.Properties[$Name]
  if ($null -eq $property) {
    return $null
  }

  $property.Value
}

function Test-WindowsEvidenceManifest {
  param(
    [object[]]$WindowsAssets,
    [object]$ManifestAsset,
    [string]$ExpectedTag,
    [string]$ExpectedRepository
  )

  if (-not $ManifestAsset) {
    return [pscustomobject]@{
      valid = $false
      failures = @("Missing Windows release asset manifest.")
      assets = @()
    }
  }

  $failures = @()
  $manifest = $null
  try {
    $manifest = Read-ReleaseAssetText -Asset $ManifestAsset | ConvertFrom-Json
  } catch {
    return [pscustomobject]@{
      valid = $false
      failures = @("Windows release asset manifest could not be read or parsed: $($_.Exception.Message)")
      assets = @()
    }
  }

  $manifestTag = Get-ObjectPropertyValue -InputObject $manifest -Name "Tag"
  $manifestRepository = Get-ObjectPropertyValue -InputObject $manifest -Name "Repository"
  $manifestAssets = @(Get-ObjectPropertyValue -InputObject $manifest -Name "Assets")

  if ($manifestTag -ne $ExpectedTag) {
    $failures += "Windows release asset manifest tag '$manifestTag' does not match '$ExpectedTag'."
  }

  if ($manifestRepository -ne $ExpectedRepository) {
    $failures += "Windows release asset manifest repository '$manifestRepository' does not match '$ExpectedRepository'."
  }

  $manifestAssetNames = @($manifestAssets | ForEach-Object { Get-ObjectPropertyValue -InputObject $_ -Name "File" })
  $windowsAssetNames = @($WindowsAssets | ForEach-Object { $_.name })

  foreach ($assetName in $windowsAssetNames) {
    if ($manifestAssetNames -notcontains $assetName) {
      $failures += "Windows release asset manifest does not include '$assetName'."
    }
  }

  foreach ($asset in $manifestAssets) {
    $assetFile = Get-ObjectPropertyValue -InputObject $asset -Name "File"
    if ($windowsAssetNames -notcontains $assetFile) {
      continue
    }

    $requirements = [ordered]@{
      SignatureStatus = "Valid"
      TimestampStatus = "Present"
      SignToolStatus = "Valid"
      ChecksumStatus = "Valid"
      AttestationStatus = "Valid"
      DefenderStatus = "Valid"
    }

    foreach ($requirement in $requirements.GetEnumerator()) {
      $actualValue = Get-ObjectPropertyValue -InputObject $asset -Name $requirement.Key
      if ($actualValue -ne $requirement.Value) {
        $failures += "$assetFile has $($requirement.Key) '$actualValue' instead of '$($requirement.Value)'."
      }
    }
  }

  [pscustomobject]@{
    valid = $failures.Count -eq 0
    failures = $failures
    assets = $manifestAssets
  }
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
    $name.EndsWith(".exe") -or $name.EndsWith(".msi") -or ($name.EndsWith(".zip") -and $name.Contains("portable"))
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

$manifestAsset = $assets |
  Where-Object { $_.name.ToLowerInvariant() -eq "windows-release-assets-$safeTag.json" } |
  Select-Object -First 1
$manifestVerification = Test-WindowsEvidenceManifest -WindowsAssets $windowsAssets -ManifestAsset $manifestAsset -ExpectedTag $Tag -ExpectedRepository $Repository
$evidence.hasValidWindowsAuditManifest = [bool]$manifestVerification.valid

$verifiedWindowsRelease = -not ($evidence.Values -contains $false) -and [bool]$manifestVerification.valid
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
  manifestFailures = @($manifestVerification.failures)
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
  "## Windows release assets"
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

if ($manifestVerification.failures.Count -gt 0) {
  $lines += @(
    "",
    "## Manifest failures"
  )
  foreach ($failure in $manifestVerification.failures) {
    $lines += "- $failure"
  }
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
