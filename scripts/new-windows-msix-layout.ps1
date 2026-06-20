param(
    [string]$Target = "x86_64-pc-windows-msvc",
    [string]$SourceRoot = "",
    [string]$OutputDirectory = "msix-layout",
    [string]$TauriConfigPath = "apps\desktop\src-tauri\tauri.conf.json",
    [string]$PackageName = "Lkkisme.CapCN",
    [string]$PublisherName = "CN=Lkkisme",
    [string]$PublisherDisplayName = "Lkkisme",
    [string]$Version = "1.0.0.0",
    [string]$ProductName = "",
    [string]$Description = "",
    [ValidateSet("x64", "x86", "arm", "arm64", "neutral")]
    [string]$Architecture = "x64",
    [string]$Language = "zh-CN",
    [string]$ProtocolName = "cap-desktop",
    [string]$MinVersion = "10.0.17763.0",
    [string]$MaxVersionTested = "10.0.26100.0"
)

$ErrorActionPreference = "Stop"

function Copy-FileToDirectory {
    param(
        [System.IO.FileInfo]$File,
        [string]$Directory
    )

    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    Copy-Item -LiteralPath $File.FullName -Destination (Join-Path $Directory $File.Name) -Force
}

function Add-Element {
    param(
        [System.Xml.XmlDocument]$Document,
        [System.Xml.XmlElement]$Parent,
        [string]$Name,
        [string]$Namespace,
        [hashtable]$Attributes = @{},
        [string]$Text = ""
    )

    $element = $Document.CreateElement($Name, $Namespace)
    foreach ($key in $Attributes.Keys) {
        $element.SetAttribute($key, [string]$Attributes[$key])
    }
    if (-not [string]::IsNullOrWhiteSpace($Text)) {
        $element.InnerText = $Text
    }
    $Parent.AppendChild($element) | Out-Null
    $element
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$tauriConfigFullPath = if ([System.IO.Path]::IsPathRooted($TauriConfigPath)) {
    Resolve-Path -LiteralPath $TauriConfigPath
} else {
    Resolve-Path -LiteralPath (Join-Path $repoRoot $TauriConfigPath)
}
$outputFullPath = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
    [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputDirectory))
}

if ($outputFullPath -eq [System.IO.Path]::GetFullPath($repoRoot.Path)) {
    throw "OutputDirectory must not be the repository root."
}

$tauriRoot = Split-Path -Parent $tauriConfigFullPath
$tauriConfig = Get-Content -Raw -Encoding UTF8 -LiteralPath $tauriConfigFullPath | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Join-Path $repoRoot "target\$Target\release"
}

$sourceRootPath = Resolve-Path -LiteralPath $SourceRoot
$mainBinaryName = $tauriConfig.mainBinaryName
if ([string]::IsNullOrWhiteSpace($mainBinaryName)) {
    throw "tauri.conf.json mainBinaryName is required for MSIX layout generation."
}

if ([string]::IsNullOrWhiteSpace($ProductName)) {
    $ProductName = $tauriConfig.productName
}

if ([string]::IsNullOrWhiteSpace($Description)) {
    $Description = $tauriConfig.bundle.longDescription
}

if ([string]::IsNullOrWhiteSpace($Description)) {
    $Description = $tauriConfig.bundle.shortDescription
}

if ([string]::IsNullOrWhiteSpace($Description)) {
    $Description = $ProductName
}

$mainExe = Join-Path $sourceRootPath "$mainBinaryName.exe"
if (-not (Test-Path -LiteralPath $mainExe)) {
    throw "Main Windows executable was not found: $mainExe"
}

if (Test-Path -LiteralPath $outputFullPath) {
    Remove-Item -LiteralPath $outputFullPath -Recurse -Force
}
New-Item -ItemType Directory -Path $outputFullPath -Force | Out-Null

Copy-Item -LiteralPath $mainExe -Destination (Join-Path $outputFullPath "$mainBinaryName.exe") -Force

$rootExtensions = @(".dll", ".json", ".dat", ".pak", ".bin")
Get-ChildItem -LiteralPath $sourceRootPath -File |
    Where-Object { $rootExtensions -contains $_.Extension.ToLowerInvariant() } |
    ForEach-Object { Copy-FileToDirectory -File $_ -Directory $outputFullPath }

foreach ($directoryName in @("assets", "resources", "locales")) {
    $sourceDirectory = Join-Path $sourceRootPath $directoryName
    if (Test-Path -LiteralPath $sourceDirectory) {
        Copy-Item -LiteralPath $sourceDirectory -Destination (Join-Path $outputFullPath $directoryName) -Recurse -Force
    }
}

$copiedResources = @()
if ($tauriConfig.bundle.resources) {
    foreach ($resource in $tauriConfig.bundle.resources.PSObject.Properties) {
        $sourcePattern = Join-Path $tauriRoot $resource.Name
        $destinationDirectory = Join-Path $outputFullPath ([string]$resource.Value)
        $resourceFiles = @(Get-ChildItem -Path $sourcePattern -File -ErrorAction SilentlyContinue)
        foreach ($file in $resourceFiles) {
            Copy-FileToDirectory -File $file -Directory $destinationDirectory
            $copiedResources += [pscustomobject]@{
                Source = $file.FullName
                Destination = Join-Path $destinationDirectory $file.Name
            }
        }
    }
}

$foundationNamespace = "http://schemas.microsoft.com/appx/manifest/foundation/windows10"
$uapNamespace = "http://schemas.microsoft.com/appx/manifest/uap/windows10"
$rescapNamespace = "http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"
$doc = New-Object System.Xml.XmlDocument
$doc.AppendChild($doc.CreateXmlDeclaration("1.0", "utf-8", $null)) | Out-Null
$package = $doc.CreateElement("Package", $foundationNamespace)
$package.SetAttribute("xmlns:uap", $uapNamespace)
$package.SetAttribute("xmlns:rescap", $rescapNamespace)
$package.SetAttribute("IgnorableNamespaces", "uap rescap")
$doc.AppendChild($package) | Out-Null

Add-Element -Document $doc -Parent $package -Name "Identity" -Namespace $foundationNamespace -Attributes @{
    Name = $PackageName
    Publisher = $PublisherName
    Version = $Version
    ProcessorArchitecture = $Architecture
} | Out-Null

$properties = Add-Element -Document $doc -Parent $package -Name "Properties" -Namespace $foundationNamespace
Add-Element -Document $doc -Parent $properties -Name "DisplayName" -Namespace $foundationNamespace -Text $ProductName | Out-Null
Add-Element -Document $doc -Parent $properties -Name "PublisherDisplayName" -Namespace $foundationNamespace -Text $PublisherDisplayName | Out-Null
Add-Element -Document $doc -Parent $properties -Name "Description" -Namespace $foundationNamespace -Text $Description | Out-Null
Add-Element -Document $doc -Parent $properties -Name "Logo" -Namespace $foundationNamespace -Text "Assets\StoreLogo.png" | Out-Null

$dependencies = Add-Element -Document $doc -Parent $package -Name "Dependencies" -Namespace $foundationNamespace
Add-Element -Document $doc -Parent $dependencies -Name "TargetDeviceFamily" -Namespace $foundationNamespace -Attributes @{
    Name = "Windows.Desktop"
    MinVersion = $MinVersion
    MaxVersionTested = $MaxVersionTested
} | Out-Null

$resources = Add-Element -Document $doc -Parent $package -Name "Resources" -Namespace $foundationNamespace
Add-Element -Document $doc -Parent $resources -Name "Resource" -Namespace $foundationNamespace -Attributes @{
    Language = $Language
} | Out-Null

$applications = Add-Element -Document $doc -Parent $package -Name "Applications" -Namespace $foundationNamespace
$application = Add-Element -Document $doc -Parent $applications -Name "Application" -Namespace $foundationNamespace -Attributes @{
    Id = "App"
    Executable = '$targetnametoken$.exe'
    EntryPoint = '$targetentrypoint$'
}

$visualElements = $doc.CreateElement("uap", "VisualElements", $uapNamespace)
$visualElements.SetAttribute("DisplayName", $ProductName)
$visualElements.SetAttribute("Description", $Description)
$visualElements.SetAttribute("BackgroundColor", "transparent")
$visualElements.SetAttribute("Square150x150Logo", "Assets\Square150x150Logo.png")
$visualElements.SetAttribute("Square44x44Logo", "Assets\Square44x44Logo.png")
$application.AppendChild($visualElements) | Out-Null

$defaultTile = $doc.CreateElement("uap", "DefaultTile", $uapNamespace)
$defaultTile.SetAttribute("Wide310x150Logo", "Assets\Wide310x150Logo.png")
$defaultTile.SetAttribute("Square310x310Logo", "Assets\Square310x310Logo.png")
$defaultTile.SetAttribute("Square71x71Logo", "Assets\Square71x71Logo.png")
$visualElements.AppendChild($defaultTile) | Out-Null

$splashScreen = $doc.CreateElement("uap", "SplashScreen", $uapNamespace)
$splashScreen.SetAttribute("Image", "Assets\SplashScreen.png")
$visualElements.AppendChild($splashScreen) | Out-Null

if (-not [string]::IsNullOrWhiteSpace($ProtocolName)) {
    $extensions = Add-Element -Document $doc -Parent $application -Name "Extensions" -Namespace $foundationNamespace
    $protocolExtension = $doc.CreateElement("uap", "Extension", $uapNamespace)
    $protocolExtension.SetAttribute("Category", "windows.protocol")
    $protocol = $doc.CreateElement("uap", "Protocol", $uapNamespace)
    $protocol.SetAttribute("Name", $ProtocolName)
    $protocolExtension.AppendChild($protocol) | Out-Null
    $extensions.AppendChild($protocolExtension) | Out-Null
}

$capabilities = Add-Element -Document $doc -Parent $package -Name "Capabilities" -Namespace $foundationNamespace
$runFullTrust = $doc.CreateElement("rescap", "Capability", $rescapNamespace)
$runFullTrust.SetAttribute("Name", "runFullTrust")
$capabilities.AppendChild($runFullTrust) | Out-Null

$manifestPath = Join-Path $outputFullPath "Package.appxmanifest"
$doc.Save($manifestPath)

$metadata = [pscustomobject]@{
    PackageName = $PackageName
    PublisherName = $PublisherName
    PublisherDisplayName = $PublisherDisplayName
    ProductName = $ProductName
    Version = $Version
    Architecture = $Architecture
    Language = $Language
    MainExecutable = "$mainBinaryName.exe"
    ManifestPath = (Resolve-Path -LiteralPath $manifestPath).Path
    CopiedResources = $copiedResources
}

$metadata | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 -Path (Join-Path $outputFullPath "windows-msix-layout.json")

Get-ChildItem -LiteralPath $outputFullPath -Force | Select-Object Name, Length | Format-Table -AutoSize
Write-Output "Windows MSIX layout: $outputFullPath"
