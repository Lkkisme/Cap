param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [string]$OutputDirectory = "",
    [string]$Version = "",
    [string]$Repository = "Lkkisme/Cap",
    [string]$Publisher = "Lkkisme",
    [string]$ProductName = "",
    [string]$PackageUrlBase = "",
    [string]$WebsiteUrl = "https://github.com/Lkkisme/Cap",
    [string]$PrivacyPolicyUrl = "",
    [string]$SupportContact = "",
    [string]$Category = "Productivity",
    [string]$Language = "zh-CN",
    [ValidateSet("x64", "x86", "arm", "arm64", "neutral")]
    [string]$Architecture = "x64",
    [string]$ExpectedPublisherPattern = "",
    [switch]$RequireValidSignature
)

$ErrorActionPreference = "Stop"

function Get-ProductName {
    if (-not [string]::IsNullOrWhiteSpace($ProductName)) {
        return $ProductName
    }

    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
    $tauriConfigPath = Join-Path $repoRoot "apps\desktop\src-tauri\tauri.conf.json"
    if (Test-Path -LiteralPath $tauriConfigPath) {
        $tauriConfig = Get-Content -Raw -Encoding UTF8 -LiteralPath $tauriConfigPath | ConvertFrom-Json
        if (-not [string]::IsNullOrWhiteSpace($tauriConfig.productName)) {
            return $tauriConfig.productName
        }
    }

    "Cap CN"
}

function Get-PackageUrl {
    param(
        [string]$BaseUrl,
        [string]$FileName
    )

    if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
        return ""
    }

    $escapedFileName = [System.Uri]::EscapeDataString($FileName)
    if ($BaseUrl.Contains("{filename}")) {
        return $BaseUrl.Replace("{filename}", $escapedFileName)
    }

    $BaseUrl.TrimEnd("/") + "/" + $escapedFileName
}

function ConvertTo-StoreArchitecture {
    param([string]$Value)

    switch ($Value.ToLowerInvariant()) {
        "x64" { "X64" }
        "x86" { "X86" }
        "arm" { "Arm" }
        "arm64" { "Arm64" }
        "neutral" { "Neutral" }
        default { throw "Unsupported Microsoft Store architecture '$Value'." }
    }
}

function Test-HttpsUrl {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    try {
        $uri = [System.Uri]::new($Value)
        return $uri.Scheme -eq "https"
    } catch {
        return $false
    }
}

function Get-MsiProperty {
    param(
        [string]$InstallerPath,
        [string]$Property
    )

    $installer = New-Object -ComObject WindowsInstaller.Installer
    $database = $installer.GetType().InvokeMember("OpenDatabase", "InvokeMethod", $null, $installer, @($InstallerPath, 0))
    $view = $database.GetType().InvokeMember("OpenView", "InvokeMethod", $null, $database, @("SELECT Value FROM Property WHERE Property = '$Property'"))
    $view.GetType().InvokeMember("Execute", "InvokeMethod", $null, $view, $null) | Out-Null
    $record = $view.GetType().InvokeMember("Fetch", "InvokeMethod", $null, $view, $null)

    if (-not $record) {
        return ""
    }

    $record.GetType().InvokeMember("StringData", "GetProperty", $null, $record, 1)
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path (Get-Location) "store-submission-package"
}

if ([string]::IsNullOrWhiteSpace($Publisher)) {
    $Publisher = "Lkkisme"
}

$resolvedPath = Resolve-Path -LiteralPath $Path
$installers = @()
foreach ($entry in $resolvedPath) {
    $item = Get-Item -LiteralPath $entry.Path
    if ($item.PSIsContainer) {
        $installers += Get-ChildItem -LiteralPath $item.FullName -Include *.exe,*.msi -File -Recurse
    } elseif ($item.Extension -in @(".exe", ".msi")) {
        $installers += $item
    }
}

$installers = @($installers | Sort-Object Name -Unique)
if ($installers.Count -eq 0) {
    throw "No EXE or MSI installers were found in '$Path'."
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$resolvedProductName = Get-ProductName
$packageRows = @()
$storePackageRows = @()

foreach ($installer in $installers) {
    $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $installer.FullName
    $signatureParams = @{
        Path = $installer.FullName
    }

    if ($RequireValidSignature) {
        $signatureParams.RequireValidSignature = $true
        $signatureParams.RequireTimestamp = $true
        $signatureParams.RequireSignToolVerification = $true
    }

    if (-not [string]::IsNullOrWhiteSpace($ExpectedPublisherPattern)) {
        $signatureParams.ExpectedPublisherPattern = $ExpectedPublisherPattern
    }

    $signature = & (Join-Path $PSScriptRoot "test-windows-authenticode.ps1") @signatureParams
    $appType = if ($installer.Extension -eq ".msi") { "MSI" } else { "EXE" }
    $storeInstallerParameters = if ($appType -eq "MSI") { "/qn" } else { "/S" }
    $localSmokeTestParameters = if ($appType -eq "MSI") { "/quiet /norestart" } else { "/S" }
    $packageUrl = Get-PackageUrl -BaseUrl $PackageUrlBase -FileName $installer.Name
    $productCode = ""
    $upgradeCode = ""

    if ($appType -eq "MSI") {
        $productCode = Get-MsiProperty -InstallerPath $installer.FullName -Property "ProductCode"
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
        $tauriConfigPath = Join-Path $repoRoot "apps\desktop\src-tauri\tauri.conf.json"
        $tauriConfig = Get-Content -Raw -Encoding UTF8 -LiteralPath $tauriConfigPath | ConvertFrom-Json
        $upgradeCode = $tauriConfig.bundle.windows.wix.upgradeCode
    }

    $packageRows += [pscustomobject]@{
        ProductName = $resolvedProductName
        Version = $Version
        Publisher = $Publisher
        Repository = "https://github.com/$Repository"
        FileName = $installer.Name
        PackageUrl = $packageUrl
        AppType = $appType
        Architecture = $Architecture
        Language = $Language
        Category = $Category
        InstallerParametersForStore = $storeInstallerParameters
        LocalSmokeTestParameters = $localSmokeTestParameters
        Sha256 = $hash.Hash.ToUpperInvariant()
        SizeBytes = $installer.Length
        SignatureStatus = $signature.SignatureStatus
        TimestampStatus = $signature.TimestampStatus
        PublisherSubject = $signature.Publisher
        CertificateThumbprint = $signature.CertificateThumbprint
        ProductCode = $productCode
        UpgradeCode = $upgradeCode
        WebsiteUrl = $WebsiteUrl
        PrivacyPolicyUrl = $PrivacyPolicyUrl
        SupportContact = $SupportContact
    }

    $storePackage = [ordered]@{
        packageUrl = $packageUrl
        languages = @($Language.ToLowerInvariant())
        architectures = @((ConvertTo-StoreArchitecture -Value $Architecture))
        isSilentInstall = $false
        installerParameters = $storeInstallerParameters
        packageType = $appType.ToLowerInvariant()
    }

    if ($appType -eq "EXE") {
        if (Test-HttpsUrl -Value $WebsiteUrl) {
            $storePackage.genericDocUrl = $WebsiteUrl
        } else {
            $storePackage.genericDocUrl = "https://github.com/$Repository"
        }
    }

    $storePackageRows += [pscustomobject]$storePackage
}

$metadata = [pscustomobject]@{
    ProductName = $resolvedProductName
    Version = $Version
    Publisher = $Publisher
    Repository = "https://github.com/$Repository"
    GeneratedAtUtc = (Get-Date).ToUniversalTime().ToString("u")
    PackageUrlBase = $PackageUrlBase
    WebsiteUrl = $WebsiteUrl
    PrivacyPolicyUrl = $PrivacyPolicyUrl
    SupportContact = $SupportContact
    Packages = $packageRows
}

$jsonPath = Join-Path $OutputDirectory "microsoft-store-submission.json"
$csvPath = Join-Path $OutputDirectory "microsoft-store-packages.csv"
$checklistPath = Join-Path $OutputDirectory "microsoft-store-submission-checklist.md"
$notesPath = Join-Path $OutputDirectory "microsoft-store-package-notes.md"
$productUpdatePath = Join-Path $OutputDirectory "microsoft-store-product-update.json"

$metadata | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -Path $jsonPath
$packageRows | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $csvPath
@{ packages = $storePackageRows } | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -Path $productUpdatePath

$checklistLines = @(
    "# Microsoft Store MSI/EXE Submission Checklist",
    "",
    "Product: $resolvedProductName",
    "Version: $Version",
    "Publisher: $Publisher",
    "Repository: https://github.com/$Repository",
    "",
    "1. Reserve or open the app in Microsoft Partner Center.",
    "2. Create an EXE or MSI app submission.",
    "3. Use a versioned HTTPS package URL for each installer.",
    "4. Do not replace a submitted installer at the same URL after certification starts.",
    "5. Confirm each package is standalone/offline and does not download additional binaries during install.",
    "6. Select architecture $Architecture and language $Language.",
    "7. For EXE packages, enter /S as the silent installer parameter.",
    "8. For MSI packages, Partner Center can use the default /qn silent switch.",
    "9. Keep the publisher identity, file names, package URLs, and signing certificate stable across releases.",
    "10. Submit after the Windows Store Package workflow has passed signing, timestamp, SignTool, Defender scan, checksum, and attestation steps.",
    "",
    "Package details are available in microsoft-store-submission.json, microsoft-store-packages.csv, and microsoft-store-product-update.json."
)

if ([string]::IsNullOrWhiteSpace($PackageUrlBase)) {
    $checklistLines += ""
    $checklistLines += "PackageUrlBase was not provided. Before submitting, publish the exact signed installer files to versioned HTTPS URLs and enter those URLs in Partner Center."
}

if ([string]::IsNullOrWhiteSpace($PrivacyPolicyUrl)) {
    $checklistLines += ""
    $checklistLines += "PrivacyPolicyUrl was not provided. Add a privacy policy URL in Partner Center if the app accesses, collects, or transmits personal information."
}

$checklistLines | Set-Content -Encoding UTF8 -Path $checklistPath

$noteLines = @(
    "# Microsoft Store Package Notes",
    ""
)

foreach ($row in $packageRows) {
    $noteLines += "## $($row.FileName)"
    $noteLines += ""
    $noteLines += "Package URL: $($row.PackageUrl)"
    $noteLines += "App type: $($row.AppType)"
    $noteLines += "Architecture: $($row.Architecture)"
    $noteLines += "Language: $($row.Language)"
    $noteLines += "Installer parameters: $($row.InstallerParametersForStore)"
    $noteLines += "SHA256: $($row.Sha256)"
    $noteLines += "Signature: $($row.SignatureStatus)"
    $noteLines += "Timestamp: $($row.TimestampStatus)"
    $noteLines += "Publisher subject: $($row.PublisherSubject)"
    if (-not [string]::IsNullOrWhiteSpace($row.ProductCode)) {
        $noteLines += "ProductCode: $($row.ProductCode)"
    }
    if (-not [string]::IsNullOrWhiteSpace($row.UpgradeCode)) {
        $noteLines += "UpgradeCode: $($row.UpgradeCode)"
    }
    $noteLines += ""
}

$noteLines | Set-Content -Encoding UTF8 -Path $notesPath

Get-ChildItem -LiteralPath $OutputDirectory -File | Select-Object FullName, Length | Format-Table -AutoSize
Write-Output "Microsoft Store submission package: $OutputDirectory"
