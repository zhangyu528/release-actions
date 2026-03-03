param(
    [Parameter(Mandatory = $true)]
    [string]$AppPath,
    [Parameter(Mandatory = $true)]
    [string]$SigningIdentity
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not (Test-Path $AppPath)) {
    throw "App bundle not found: $AppPath"
}

codesign --force --options runtime --timestamp --deep --sign "$SigningIdentity" "$AppPath"
if ($LASTEXITCODE -ne 0) {
    throw "codesign signing failed for app: $AppPath"
}

codesign --verify --deep --strict --verbose=2 "$AppPath"
if ($LASTEXITCODE -ne 0) {
    throw "codesign verification failed for app: $AppPath"
}
