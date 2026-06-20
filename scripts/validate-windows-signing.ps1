param(
    [switch]$AllowUnsigned,
    [switch]$RequireSigning
)

$ErrorActionPreference = "Stop"

$provider = $env:WINDOWS_SIGNING_PROVIDER
if ($provider) {
    $provider = $provider.Trim()
}

$allowedProviders = @("azure-artifact-signing", "signpath", "pfx")

if ([string]::IsNullOrWhiteSpace($provider)) {
    if ($RequireSigning -or -not $AllowUnsigned) {
        throw "WINDOWS_SIGNING_PROVIDER must be set to azure-artifact-signing, signpath, or pfx."
    }
    Write-Host "WINDOWS_SIGNING_PROVIDER is empty. Windows installers will be unsigned."
    exit 0
}

if (-not $allowedProviders.Contains($provider)) {
    throw "Unsupported WINDOWS_SIGNING_PROVIDER '$provider'. Use azure-artifact-signing, signpath, or pfx."
}

$requiredByProvider = @{
    "azure-artifact-signing" = @(
        "AZURE_ARTIFACT_SIGNING_ENDPOINT",
        "AZURE_ARTIFACT_SIGNING_ACCOUNT_NAME",
        "AZURE_ARTIFACT_SIGNING_CERTIFICATE_PROFILE_NAME",
        "AZURE_CLIENT_ID",
        "AZURE_TENANT_ID",
        "AZURE_SUBSCRIPTION_ID"
    )
    "signpath" = @(
        "SIGNPATH_API_TOKEN",
        "SIGNPATH_ORGANIZATION_ID",
        "SIGNPATH_PROJECT_SLUG",
        "SIGNPATH_SIGNING_POLICY_SLUG",
        "SIGNPATH_ARTIFACT_CONFIGURATION_SLUG"
    )
    "pfx" = @(
        "WINDOWS_CERTIFICATE_PFX_BASE64",
        "WINDOWS_CERTIFICATE_PFX_PASSWORD"
    )
}

$missing = @()
foreach ($name in $requiredByProvider[$provider]) {
    $value = [Environment]::GetEnvironmentVariable($name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        $missing += $name
    }
}

if ($missing.Count -gt 0) {
    throw "Windows signing provider '$provider' is missing: $($missing -join ', ')."
}

Write-Host "Windows signing provider '$provider' is configured."
