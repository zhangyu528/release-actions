param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [Parameter(Mandatory = $false)]
    [string]$SignedInstallerDir = 'artifacts/signed/installer',
    [Parameter(Mandatory = $false)]
    [string]$InstallerTargetTemplate = 'artifacts/installer/Aiden-Setup-{version}-win-x64.exe'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$signedInstaller = Get-ChildItem -Path $SignedInstallerDir -Filter '*.exe' -Recurse -ErrorAction Stop | Select-Object -First 1
if ($null -eq $signedInstaller) {
    throw "Signed installer not found in: $SignedInstallerDir"
}

$installerTarget = $InstallerTargetTemplate.Replace('{version}', $Version)
New-Item -ItemType Directory -Path (Split-Path -Parent $installerTarget) -Force | Out-Null
Copy-Item -Path $signedInstaller.FullName -Destination $installerTarget -Force

$sig = Get-AuthenticodeSignature -FilePath $installerTarget
if ($sig.Status -ne 'Valid') {
    throw "Invalid signature on $installerTarget. Status=$($sig.Status)"
}
