param(
    [Parameter(Mandatory = $true)]
    [string]$AppBundlePath,
    [Parameter(Mandatory = $true)]
    [string]$ScriptsDir,
    [Parameter(Mandatory = $true)]
    [string]$PkgPath,
    [Parameter(Mandatory = $true)]
    [string]$Identifier,
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [Parameter(Mandatory = $false)]
    [string]$InstallLocation = '/Applications'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not (Test-Path $AppBundlePath)) {
    throw "App bundle not found: $AppBundlePath"
}
if (-not (Test-Path $ScriptsDir)) {
    throw "Scripts directory not found: $ScriptsDir"
}
if (-not (Test-Path (Join-Path $ScriptsDir 'postinstall'))) {
    throw "postinstall script not found: $(Join-Path $ScriptsDir 'postinstall')"
}

$pkgDir = Split-Path -Parent $PkgPath
if (-not [string]::IsNullOrWhiteSpace($pkgDir)) {
    New-Item -ItemType Directory -Path $pkgDir -Force | Out-Null
}
if (Test-Path $PkgPath) {
    Remove-Item -Path $PkgPath -Force
}

pkgbuild `
  --component "$AppBundlePath" `
  --install-location "$InstallLocation" `
  --identifier "$Identifier" `
  --version "$Version" `
  --scripts "$ScriptsDir" `
  "$PkgPath"

if ($LASTEXITCODE -ne 0) {
    throw "pkgbuild failed with exit code $LASTEXITCODE"
}
