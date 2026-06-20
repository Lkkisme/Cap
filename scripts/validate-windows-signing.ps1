param(
    [switch]$AllowUnsigned,
    [switch]$RequireSigning
)

$ErrorActionPreference = "Stop"

$provider = $env:WINDOWS_SIGNING_PROVIDER
if ($provider) {
    $provider = $provider.Trim().ToLowerInvariant()
}

$providerAliases = @{
    "trusted-signing" = "azure-artifact-signing"
    "azure-trusted-signing" = "azure-artifact-signing"
}

if (-not [string]::IsNullOrWhiteSpace($provider) -and $providerAliases.ContainsKey($provider)) {
    $provider = $providerAliases[$provider]
}

$allowedProviders = @("azure-artifact-signing", "signpath", "pfx")
$acceptedProviderText = "azure-artifact-signing, trusted-signing, azure-trusted-signing, signpath, or pfx"

if ([string]::IsNullOrWhiteSpace($provider)) {
    if ($env:GITHUB_OUTPUT) {
        "provider=" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    }
    if ($RequireSigning -or -not $AllowUnsigned) {
        throw "WINDOWS_SIGNING_PROVIDER must be set to $acceptedProviderText."
    }
    Write-Host "WINDOWS_SIGNING_PROVIDER is empty. Windows installers will be unsigned."
    exit 0
}

if (-not $allowedProviders.Contains($provider)) {
    throw "Unsupported WINDOWS_SIGNING_PROVIDER '$provider'. Use $acceptedProviderText."
}

if ($env:GITHUB_OUTPUT) {
    "provider=$provider" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
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

$publisherPattern = $env:WINDOWS_SIGNING_PUBLISHER_PATTERN
if ([string]::IsNullOrWhiteSpace($publisherPattern)) {
    throw "WINDOWS_SIGNING_PUBLISHER_PATTERN must be set to a regex matching the Authenticode publisher subject."
}

try {
    [regex]::new($publisherPattern) | Out-Null
} catch {
    throw "WINDOWS_SIGNING_PUBLISHER_PATTERN is not a valid regex: $($_.Exception.Message)"
}

Write-Host "Windows signing provider '$provider' is configured."
