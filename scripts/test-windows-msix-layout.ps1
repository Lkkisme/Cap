param(
    [string]$Path = "msix-layout",
    [string]$ExpectedPackageName = "",
    [string]$ExpectedPublisherName = "",
    [string]$ExpectedPublisherDisplayName = "",
    [string]$ExpectedVersion = "",
    [string]$ExpectedExecutable = ""
)

$ErrorActionPreference = "Stop"

$layoutPath = (Resolve-Path -LiteralPath $Path).Path
$manifestPath = Join-Path $layoutPath "Package.appxmanifest"

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Package.appxmanifest was not found in $layoutPath."
}

[xml]$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath
$namespaceManager = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
$namespaceManager.AddNamespace("f", "http://schemas.microsoft.com/appx/manifest/foundation/windows10")
$namespaceManager.AddNamespace("uap", "http://schemas.microsoft.com/appx/manifest/uap/windows10")
$namespaceManager.AddNamespace("rescap", "http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities")

function Select-RequiredNode {
    param(
        [string]$XPath
    )

    $node = $manifest.SelectSingleNode($XPath, $namespaceManager)
    if (-not $node) {
        throw "Missing manifest node: $XPath"
    }
    $node
}

function Get-RequiredAttribute {
    param(
        [System.Xml.XmlNode]$Node,
        [string]$Name
    )

    $attribute = $Node.Attributes[$Name]
    if (-not $attribute -or [string]::IsNullOrWhiteSpace($attribute.Value)) {
        throw "Missing manifest attribute '$Name' on $($Node.Name)."
    }
    $attribute.Value
}

function Assert-ExpectedValue {
    param(
        [string]$Actual,
        [string]$Expected,
        [string]$Name
    )

    if (-not [string]::IsNullOrWhiteSpace($Expected) -and $Actual -ne $Expected) {
        throw "$Name must be '$Expected', got '$Actual'."
    }
}

function Assert-PackageAsset {
    param(
        [string]$RelativePath,
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        throw "$Name must not be empty."
    }

    $normalizedPath = $RelativePath.Replace("/", "\")
    $exactPath = Join-Path $layoutPath $normalizedPath
    if (Test-Path -LiteralPath $exactPath) {
        return
    }

    $assetDirectory = Split-Path -Parent $exactPath
    $assetFileName = [System.IO.Path]::GetFileNameWithoutExtension($exactPath)
    $assetExtension = [System.IO.Path]::GetExtension($exactPath)

    if (-not (Test-Path -LiteralPath $assetDirectory)) {
        throw "$Name directory is missing: $assetDirectory"
    }

    $matchingAssets = @(
        Get-ChildItem -LiteralPath $assetDirectory -Filter "$assetFileName*$assetExtension" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.BaseName -eq $assetFileName -or $_.BaseName.StartsWith("$assetFileName.") }
    )

    if ($matchingAssets.Count -eq 0) {
        throw "$Name asset is missing: $RelativePath"
    }
}

$identity = Select-RequiredNode "/f:Package/f:Identity"
$properties = Select-RequiredNode "/f:Package/f:Properties"
$application = Select-RequiredNode "/f:Package/f:Applications/f:Application"
$visualElements = Select-RequiredNode "/f:Package/f:Applications/f:Application/uap:VisualElements"
$runFullTrust = Select-RequiredNode "/f:Package/f:Capabilities/rescap:Capability[@Name='runFullTrust']"

$packageName = Get-RequiredAttribute -Node $identity -Name "Name"
$publisherName = Get-RequiredAttribute -Node $identity -Name "Publisher"
$version = Get-RequiredAttribute -Node $identity -Name "Version"
$architecture = Get-RequiredAttribute -Node $identity -Name "ProcessorArchitecture"
$executable = Get-RequiredAttribute -Node $application -Name "Executable"
$entryPoint = Get-RequiredAttribute -Node $application -Name "EntryPoint"
$displayName = Get-RequiredAttribute -Node $visualElements -Name "DisplayName"
$description = Get-RequiredAttribute -Node $visualElements -Name "Description"
$backgroundColor = Get-RequiredAttribute -Node $visualElements -Name "BackgroundColor"

Assert-ExpectedValue -Actual $packageName -Expected $ExpectedPackageName -Name "Package identity name"
Assert-ExpectedValue -Actual $publisherName -Expected $ExpectedPublisherName -Name "Publisher name"
Assert-ExpectedValue -Actual $version -Expected $ExpectedVersion -Name "Package version"

$publisherDisplayName = (Select-RequiredNode "/f:Package/f:Properties/f:PublisherDisplayName").InnerText
Assert-ExpectedValue -Actual $publisherDisplayName -Expected $ExpectedPublisherDisplayName -Name "Publisher display name"

if ([string]::IsNullOrWhiteSpace($architecture)) {
    throw "ProcessorArchitecture must not be empty."
}

if ([string]::IsNullOrWhiteSpace($entryPoint)) {
    throw "Application EntryPoint must not be empty."
}

if ([string]::IsNullOrWhiteSpace($displayName)) {
    throw "VisualElements DisplayName must not be empty."
}

if ([string]::IsNullOrWhiteSpace($description)) {
    throw "VisualElements Description must not be empty."
}

if ([string]::IsNullOrWhiteSpace($backgroundColor)) {
    throw "VisualElements BackgroundColor must not be empty."
}

if (-not [string]::IsNullOrWhiteSpace($ExpectedExecutable)) {
    $expectedExecutablePath = Join-Path $layoutPath $ExpectedExecutable
    if (-not (Test-Path -LiteralPath $expectedExecutablePath)) {
        throw "Expected executable was not found: $ExpectedExecutable"
    }
}

if (-not $executable.StartsWith('$')) {
    Assert-PackageAsset -RelativePath $executable -Name "Application executable"
}

Assert-PackageAsset -RelativePath (Select-RequiredNode "/f:Package/f:Properties/f:Logo").InnerText -Name "Store logo"
Assert-PackageAsset -RelativePath (Get-RequiredAttribute -Node $visualElements -Name "Square150x150Logo") -Name "Square150x150Logo"
Assert-PackageAsset -RelativePath (Get-RequiredAttribute -Node $visualElements -Name "Square44x44Logo") -Name "Square44x44Logo"

$defaultTile = $manifest.SelectSingleNode("/f:Package/f:Applications/f:Application/uap:VisualElements/uap:DefaultTile", $namespaceManager)
if ($defaultTile) {
    foreach ($attributeName in @("Wide310x150Logo", "Square310x310Logo", "Square71x71Logo")) {
        $attribute = $defaultTile.Attributes[$attributeName]
        if ($attribute -and -not [string]::IsNullOrWhiteSpace($attribute.Value)) {
            Assert-PackageAsset -RelativePath $attribute.Value -Name $attributeName
        }
    }
}

$splashScreen = $manifest.SelectSingleNode("/f:Package/f:Applications/f:Application/uap:VisualElements/uap:SplashScreen", $namespaceManager)
if ($splashScreen) {
    Assert-PackageAsset -RelativePath (Get-RequiredAttribute -Node $splashScreen -Name "Image") -Name "SplashScreen"
}

$protocol = $manifest.SelectSingleNode("/f:Package/f:Applications/f:Application/f:Extensions/uap:Extension[@Category='windows.protocol']/uap:Protocol", $namespaceManager)
if ($protocol) {
    Get-RequiredAttribute -Node $protocol -Name "Name" | Out-Null
}

if (-not $runFullTrust) {
    throw "runFullTrust capability is required for the desktop bridge MSIX package."
}

Write-Host "Windows MSIX layout is valid: $layoutPath"
