param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [string]$ProductName = "Cap $([char]0x4E2D)$([char]0x6587)$([char]0x7248)",
    [int]$TimeoutSeconds = 600,
    [switch]$RemoveExisting,
    [string]$ReportPath = "",
    [string]$JsonPath = ""
)

$ErrorActionPreference = "Stop"
$startedAt = (Get-Date).ToUniversalTime()

function Quote-Argument {
    param([string]$Value)

    if ($Value -match "\s") {
        return "`"$Value`""
    }

    $Value
}

function Invoke-ProcessWithTimeout {
    param(
        [string]$FilePath,
        [string]$Arguments,
        [string]$Label,
        [int]$TimeoutSeconds
    )

    Write-Host "$Label`: $FilePath $Arguments"
    $process = Start-Process -FilePath $FilePath -ArgumentList $Arguments -PassThru -WindowStyle Hidden
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        throw "$Label timed out after $TimeoutSeconds seconds."
    }

    if ($process.ExitCode -notin @(0, 3010)) {
        throw "$Label failed with exit code $($process.ExitCode)."
    }

    $process.ExitCode
}

function Get-UninstallEntry {
    param([string]$ProductName)

    $roots = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }

        $entries = Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue |
            ForEach-Object { Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue } |
            Where-Object { $_.DisplayName -eq $ProductName -or $_.DisplayName -like "*$ProductName*" }

        $entry = $entries | Select-Object -First 1
        if ($entry) {
            return $entry
        }
    }

    $null
}

function Split-CommandLine {
    param([string]$CommandLine)

    $trimmed = $CommandLine.Trim()
    if ($trimmed.StartsWith('"')) {
        $end = $trimmed.IndexOf('"', 1)
        if ($end -lt 0) {
            throw "Unable to parse uninstall command: $CommandLine"
        }

        return [pscustomobject]@{
            FilePath = $trimmed.Substring(1, $end - 1)
            Arguments = $trimmed.Substring($end + 1).Trim()
        }
    }

    $exeIndex = $trimmed.ToLowerInvariant().IndexOf(".exe")
    if ($exeIndex -ge 0) {
        return [pscustomobject]@{
            FilePath = $trimmed.Substring(0, $exeIndex + 4)
            Arguments = $trimmed.Substring($exeIndex + 4).Trim()
        }
    }

    $parts = $trimmed -split "\s+", 2
    [pscustomobject]@{
        FilePath = $parts[0]
        Arguments = if ($parts.Count -gt 1) { $parts[1] } else { "" }
    }
}

function Invoke-SilentUninstall {
    param(
        [object]$Entry,
        [int]$TimeoutSeconds
    )

    $command = if (-not [string]::IsNullOrWhiteSpace($Entry.QuietUninstallString)) {
        $Entry.QuietUninstallString
    } else {
        $Entry.UninstallString
    }

    if ([string]::IsNullOrWhiteSpace($command)) {
        throw "Uninstall command was not found for $($Entry.DisplayName)."
    }

    $parsed = Split-CommandLine -CommandLine $command
    $arguments = $parsed.Arguments

    if ($parsed.FilePath -match "msiexec(\.exe)?$") {
        if ($arguments -notmatch "(^|\s)/(quiet|qn)(\s|$)") {
            $arguments = "$arguments /quiet".Trim()
        }
        if ($arguments -notmatch "(^|\s)/norestart(\s|$)") {
            $arguments = "$arguments /norestart".Trim()
        }
    } elseif ($arguments -notmatch "(^|\s)/S(\s|$)") {
        $arguments = "$arguments /S".Trim()
    }

    Invoke-ProcessWithTimeout -FilePath $parsed.FilePath -Arguments $arguments -Label "Silent uninstall" -TimeoutSeconds $TimeoutSeconds
}

$item = Get-Item -LiteralPath $Path
if ($item.PSIsContainer) {
    $installers = Get-ChildItem -LiteralPath $item.FullName -File -Recurse |
        Where-Object { $_.Extension -in @(".exe", ".msi") }
} elseif ($item.Extension -in @(".exe", ".msi")) {
    $installers = @($item)
} else {
    throw "$Path is not an EXE/MSI installer or directory."
}

$installers = @($installers | Sort-Object Extension, Name)
if ($installers.Count -eq 0) {
    throw "No EXE/MSI installers found under $Path."
}

$results = @()

foreach ($installer in $installers) {
    $entryBefore = Get-UninstallEntry -ProductName $ProductName
    if ($entryBefore) {
        if (-not $RemoveExisting) {
            throw "An existing install entry matching '$ProductName' was found. Re-run with -RemoveExisting only on a disposable test machine."
        }
        Invoke-SilentUninstall -Entry $entryBefore -TimeoutSeconds $TimeoutSeconds
        Start-Sleep -Seconds 5
    }

    if ($installer.Extension -eq ".msi") {
        $logPath = Join-Path $installer.DirectoryName "$($installer.BaseName)-install.log"
        $arguments = "/i $(Quote-Argument $installer.FullName) /quiet /norestart /L*v $(Quote-Argument $logPath)"
        $installExitCode = Invoke-ProcessWithTimeout -FilePath "msiexec.exe" -Arguments $arguments -Label "Silent MSI install" -TimeoutSeconds $TimeoutSeconds
    } else {
        $installExitCode = Invoke-ProcessWithTimeout -FilePath $installer.FullName -Arguments "/S" -Label "Silent NSIS install" -TimeoutSeconds $TimeoutSeconds
    }

    Start-Sleep -Seconds 8
    $entryAfter = Get-UninstallEntry -ProductName $ProductName
    if (-not $entryAfter) {
        throw "$($installer.Name) installed silently but no uninstall entry matching '$ProductName' was found."
    }

    if ($installer.Extension -eq ".msi") {
        $logPath = Join-Path $installer.DirectoryName "$($installer.BaseName)-uninstall.log"
        $arguments = "/x $(Quote-Argument $installer.FullName) /quiet /norestart /L*v $(Quote-Argument $logPath)"
        $uninstallExitCode = Invoke-ProcessWithTimeout -FilePath "msiexec.exe" -Arguments $arguments -Label "Silent MSI uninstall" -TimeoutSeconds $TimeoutSeconds
    } else {
        $uninstallExitCode = Invoke-SilentUninstall -Entry $entryAfter -TimeoutSeconds $TimeoutSeconds
    }

    Start-Sleep -Seconds 8
    $remainingEntry = Get-UninstallEntry -ProductName $ProductName
    if ($remainingEntry) {
        throw "$($installer.Name) uninstall completed but an uninstall entry matching '$ProductName' remains."
    }

    $results += [pscustomobject]@{
        File = $installer.Name
        Type = $installer.Extension.TrimStart(".").ToUpperInvariant()
        InstallExitCode = $installExitCode
        UninstallExitCode = $uninstallExitCode
    }
}

$results | Format-Table File, Type, InstallExitCode, UninstallExitCode -AutoSize
Write-Host "Silent installer smoke test passed for $($results.Count) installer(s)."

$completedAt = (Get-Date).ToUniversalTime()

if (-not [string]::IsNullOrWhiteSpace($JsonPath)) {
    $jsonDirectory = Split-Path -Parent $JsonPath
    if (-not [string]::IsNullOrWhiteSpace($jsonDirectory)) {
        New-Item -ItemType Directory -Path $jsonDirectory -Force | Out-Null
    }

    [pscustomobject]@{
        ProductName = $ProductName
        Path = $item.FullName
        TimeoutSeconds = $TimeoutSeconds
        StartedAt = $startedAt.ToString("o")
        CompletedAt = $completedAt.ToString("o")
        InstallerCount = $results.Count
        Results = $results
    } | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 -LiteralPath $JsonPath
}

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $reportDirectory = Split-Path -Parent $ReportPath
    if (-not [string]::IsNullOrWhiteSpace($reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    }

    $lines = @()
    $lines += "# Windows Installer Smoke Test Report"
    $lines += ""
    $lines += "Product: $ProductName"
    $lines += "Started: $($startedAt.ToString("o"))"
    $lines += "Completed: $($completedAt.ToString("o"))"
    $lines += "Installer count: $($results.Count)"
    $lines += ""
    $lines += "## Results"
    $lines += ""
    $lines += "| File | Type | Install exit code | Uninstall exit code |"
    $lines += "| --- | --- | --- | --- |"
    foreach ($result in $results) {
        $lines += "| $($result.File) | $($result.Type) | $($result.InstallExitCode) | $($result.UninstallExitCode) |"
    }
    $lines += ""
    $lines += "All listed installers completed silent install, created an Add/Remove Programs entry, completed silent uninstall, and removed the Add/Remove Programs entry on the Windows runner."
    $lines | Set-Content -Encoding UTF8 -LiteralPath $ReportPath
}
