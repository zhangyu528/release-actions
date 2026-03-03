param(
    [Parameter(Mandatory = $true)]
    [string]$PkgPath,
    [Parameter(Mandatory = $true)]
    [string]$InstallerSigningIdentity,
    [Parameter(Mandatory = $true)]
    [string]$AppleTeamId,
    [Parameter(Mandatory = $true)]
    [string]$AppleId,
    [Parameter(Mandatory = $true)]
    [string]$AppleAppPassword
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not (Test-Path $PkgPath)) {
    throw "PKG not found: $PkgPath"
}

$dir = Split-Path -Parent $PkgPath
$name = [IO.Path]::GetFileNameWithoutExtension($PkgPath)
$signedTempPath = Join-Path $dir "$name-signed.pkg"
if (Test-Path $signedTempPath) {
    Remove-Item -Path $signedTempPath -Force
}

productsign --sign "$InstallerSigningIdentity" "$PkgPath" "$signedTempPath"
if ($LASTEXITCODE -ne 0) {
    throw "productsign failed with exit code $LASTEXITCODE"
}

Move-Item -Path $signedTempPath -Destination $PkgPath -Force

xcrun notarytool submit "$PkgPath" --apple-id "$AppleId" --password "$AppleAppPassword" --team-id "$AppleTeamId" --wait
if ($LASTEXITCODE -ne 0) {
    throw "notarytool submit failed with exit code $LASTEXITCODE"
}

xcrun stapler staple "$PkgPath"
if ($LASTEXITCODE -ne 0) {
    throw "stapler failed with exit code $LASTEXITCODE"
}

spctl --assess --type install --verbose "$PkgPath"
if ($LASTEXITCODE -ne 0) {
    throw "spctl verification failed for pkg: $PkgPath"
}
