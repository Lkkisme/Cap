param(
    [Parameter(Mandatory = $true)]
    [string]$AppVersion,
    [string]$OutputPath = ".env"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-FirstEnvironmentValue {
    param([string[]]$Names)

    foreach ($name in $Names) {
        $value = [Environment]::GetEnvironmentVariable($name)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }
    }

    $null
}

function Get-ValidHttpsUrl {
    param(
        [string]$Value,
        [string]$Name,
        [switch]$AllowMicrosoftStore
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$Name is required."
    }

    try {
        $uri = [System.Uri]::new($Value.Trim())
        if ($uri.Scheme -ne "https") {
            throw "$Name must use https."
        }

        $hostName = $uri.Host.ToLowerInvariant()
        if ($uri.IsLoopback -or $hostName -eq "cap.so" -or $hostName -eq "www.cap.so") {
            throw "$Name must point to the official Lkkisme/Cap download surface, not localhost or upstream cap.so."
        }

        if ($AllowMicrosoftStore -and ($hostName -eq "apps.microsoft.com" -or $hostName -eq "www.microsoft.com" -or $hostName -eq "microsoft.com")) {
            return $uri.AbsoluteUri.TrimEnd("/")
        }

        return $uri.AbsoluteUri.TrimEnd("/")
    } catch {
        throw "$Name is not a valid HTTPS URL: $($_.Exception.Message)"
    }
}

$serverUrlCandidate = Get-FirstEnvironmentValue -Names @("WINDOWS_PUBLIC_WEB_URL", "NEXT_PUBLIC_WEB_URL", "WEB_URL")
$serverUrl = if ([string]::IsNullOrWhiteSpace($serverUrlCandidate)) {
    "https://cap.so"
} else {
    Get-ValidHttpsUrl -Value $serverUrlCandidate -Name "WINDOWS_PUBLIC_WEB_URL"
}

$downloadUrl = Get-ValidHttpsUrl -Value (Get-FirstEnvironmentValue -Names @("WINDOWS_DOWNLOAD_URL")) -Name "WINDOWS_DOWNLOAD_URL" -AllowMicrosoftStore
$previousVersionsCandidate = Get-FirstEnvironmentValue -Names @("WINDOWS_PREVIOUS_VERSIONS_URL")
$previousVersionsUrl = if ([string]::IsNullOrWhiteSpace($previousVersionsCandidate)) {
    if ($serverUrl -eq "https://cap.so") {
        $downloadUrl
    } else {
        "$serverUrl/download/versions"
    }
} else {
    Get-ValidHttpsUrl -Value $previousVersionsCandidate -Name "WINDOWS_PREVIOUS_VERSIONS_URL"
}

Set-Content -Path $OutputPath -Encoding utf8 -Value @(
    "appVersion=$AppVersion",
    "VITE_ENVIRONMENT=production",
    "VITE_SERVER_URL=$serverUrl",
    "VITE_DOWNLOAD_URL=$downloadUrl",
    "VITE_PREVIOUS_VERSIONS_URL=$previousVersionsUrl",
    "VITE_DISABLE_UPDATER=true",
    "NEXT_PUBLIC_WEB_URL=$serverUrl"
)
