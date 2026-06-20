param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [switch]$RequireValidSignature,
    [switch]$RequireTimestamp,
    [switch]$RequireSignToolVerification,
    [string]$ExpectedPublisherPattern = ""
)

$ErrorActionPreference = "Stop"

function Find-SignTool {
    $command = Get-Command signtool.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $roots = @(
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin",
        "${env:ProgramFiles}\Windows Kits\10\bin"
    )

    foreach ($root in $roots) {
        if ([string]::IsNullOrWhiteSpace($root) -or -not (Test-Path -LiteralPath $root)) {
            continue
        }

        $candidate = Get-ChildItem -Path $root -Filter signtool.exe -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match "\\x64\\signtool\.exe$" } |
            Sort-Object FullName -Descending |
            Select-Object -First 1

        if ($candidate) {
            return $candidate.FullName
        }
    }

    $null
}

$resolvedPath = (Resolve-Path -LiteralPath $Path).Path
$signature = Get-AuthenticodeSignature -LiteralPath $resolvedPath

$publisher = ""
$thumbprint = ""
$notBefore = ""
$notAfter = ""
$timestampStatus = "Unavailable"
$timestampAuthority = ""
$timestampThumbprint = ""
$timestampNotBefore = ""
$timestampNotAfter = ""

if ($signature.SignerCertificate) {
    $publisher = $signature.SignerCertificate.Subject
    $thumbprint = $signature.SignerCertificate.Thumbprint
    $notBefore = $signature.SignerCertificate.NotBefore.ToString("u")
    $notAfter = $signature.SignerCertificate.NotAfter.ToString("u")
}

if ($signature.TimeStamperCertificate) {
    $timestampStatus = "Present"
    $timestampAuthority = $signature.TimeStamperCertificate.Subject
    $timestampThumbprint = $signature.TimeStamperCertificate.Thumbprint
    $timestampNotBefore = $signature.TimeStamperCertificate.NotBefore.ToString("u")
    $timestampNotAfter = $signature.TimeStamperCertificate.NotAfter.ToString("u")
} elseif ($signature.Status -eq "Valid") {
    $timestampStatus = "Missing"
}

if ($RequireValidSignature -and $signature.Status -ne "Valid") {
    throw "$resolvedPath signature is $($signature.Status): $($signature.StatusMessage)"
}

if ($RequireTimestamp -and $timestampStatus -ne "Present") {
    throw "$resolvedPath signature does not include a trusted timestamp."
}

if (-not [string]::IsNullOrWhiteSpace($ExpectedPublisherPattern) -and $signature.Status -eq "Valid" -and $publisher -notmatch $ExpectedPublisherPattern) {
    throw "$resolvedPath publisher '$publisher' does not match expected pattern '$ExpectedPublisherPattern'."
}

$signToolStatus = "NotRequested"
$signToolPath = ""

if ($RequireSignToolVerification) {
    $signToolPath = Find-SignTool
    if (-not $signToolPath) {
        throw "signtool.exe was not found on this Windows machine."
    }

    $signToolOutput = & $signToolPath verify /pa /tw $resolvedPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        $outputText = ($signToolOutput | Out-String).Trim()
        throw "signtool verify failed for $resolvedPath. $outputText"
    }
    $signToolStatus = "Valid"
}

[pscustomobject]@{
    Path = $resolvedPath
    SignatureStatus = $signature.Status.ToString()
    SignatureMessage = $signature.StatusMessage
    TimestampStatus = $timestampStatus
    TimestampAuthority = $timestampAuthority
    TimestampCertificateThumbprint = $timestampThumbprint
    TimestampCertificateNotBefore = $timestampNotBefore
    TimestampCertificateNotAfter = $timestampNotAfter
    Publisher = $publisher
    CertificateThumbprint = $thumbprint
    CertificateNotBefore = $notBefore
    CertificateNotAfter = $notAfter
    SignToolStatus = $signToolStatus
    SignToolPath = $signToolPath
}
