param(
    [Parameter(Mandatory = $true)]
    [string[]]$Path,
    [string[]]$Include = @("*.exe", "*.msi", "*.zip"),
    [switch]$RequireScanner
)

$ErrorActionPreference = "Stop"

$files = @()
foreach ($item in $Path) {
    $resolved = Resolve-Path -LiteralPath $item -ErrorAction SilentlyContinue
    if (-not $resolved) {
        continue
    }

    foreach ($entry in $resolved) {
        $fileItem = Get-Item -LiteralPath $entry.Path
        if ($fileItem.PSIsContainer) {
            $files += Get-ChildItem -LiteralPath $fileItem.FullName -File -Recurse -Include $Include
        } else {
            $matchesInclude = $false
            foreach ($pattern in $Include) {
                if ($fileItem.Name -like $pattern) {
                    $matchesInclude = $true
                    break
                }
            }
            if ($matchesInclude) {
                $files += $fileItem
            }
        }
    }
}

$files = @($files | Sort-Object FullName -Unique)

if ($files.Count -eq 0) {
    throw "No Windows assets found to scan."
}

$scannerCandidates = @()
$platformRoot = Join-Path $env:ProgramData "Microsoft\Windows Defender\Platform"
if (Test-Path -LiteralPath $platformRoot) {
    $scannerCandidates += Get-ChildItem -LiteralPath $platformRoot -Directory |
        Sort-Object Name -Descending |
        ForEach-Object { Join-Path $_.FullName "MpCmdRun.exe" }
}

$scannerCandidates += Join-Path $env:ProgramFiles "Windows Defender\MpCmdRun.exe"
$scannerPath = $scannerCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if (-not $scannerPath) {
    if ($RequireScanner) {
        throw "Microsoft Defender MpCmdRun.exe was not found."
    }

    Write-Warning "Microsoft Defender MpCmdRun.exe was not found; skipping scan."
    exit 0
}

Write-Host "Using Microsoft Defender scanner: $scannerPath"

foreach ($file in $files) {
    Write-Host "Scanning $($file.FullName)"
    $arguments = @("-Scan", "-ScanType", "3", "-File", $file.FullName, "-DisableRemediation")
    $process = Start-Process -FilePath $scannerPath -ArgumentList $arguments -NoNewWindow -PassThru -Wait
    if ($process.ExitCode -ne 0) {
        throw "Microsoft Defender scan failed for $($file.FullName) with exit code $($process.ExitCode)."
    }
}

Write-Host "Microsoft Defender scan passed for $($files.Count) Windows asset(s)."
