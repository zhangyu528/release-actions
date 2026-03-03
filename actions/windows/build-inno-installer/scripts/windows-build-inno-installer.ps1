param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [Parameter(Mandatory = $false)]
    [string]$SourceDir = 'artifacts/stage/package',
    [Parameter(Mandatory = $false)]
    [string]$OutputDir = 'artifacts/installer',
    [Parameter(Mandatory = $false)]
    [string]$AppName = 'Aiden',
    [Parameter(Mandatory = $false)]
    [string]$InstallerBitness = 'win-x64',
    [Parameter(Mandatory = $false)]
    [string]$PostInstallLaunchExe = 'Aiden.TrayMonitor.exe',
    [Parameter(Mandatory = $false)]
    [string]$AutoRunExe = 'Aiden.RuntimeAgent.exe',
    [Parameter(Mandatory = $false)]
    [string]$SetupIconName = 'aiden.ico',
    [Parameter(Mandatory = $false)]
    [string]$OutputNamePrefix = 'Aiden-Setup',
    [Parameter(Mandatory = $true)]
    [string]$ActionPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not (Test-Path $SourceDir)) {
    throw "Installer source directory not found: $SourceDir"
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$iscc = 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
if (-not (Test-Path $iscc)) {
    throw "Inno Setup compiler not found: $iscc"
}

$issTemplate = Join-Path $ActionPath 'assets/windows/default-installer.iss'
if (-not (Test-Path $issTemplate)) {
    throw "ISS template not found: $issTemplate"
}

$outputFileBase = "$OutputNamePrefix-$Version-$InstallerBitness"

& $iscc `
  "/DAppName=$AppName" `
  "/DAppVersion=$Version" `
  "/DSourceDir=$SourceDir" `
  "/DOutputDir=$OutputDir" `
  "/DInstallerFilename=$outputFileBase" `
  "/DPostInstallLaunchExeName=$PostInstallLaunchExe" `
  "/DAutoRunExeName=$AutoRunExe" `
  "/DSetupIconName=$SetupIconName" `
  $issTemplate

if ($LASTEXITCODE -ne 0) {
    throw "ISCC failed with exit code $LASTEXITCODE"
}

$installerPath = Join-Path $OutputDir "$outputFileBase.exe"
if (-not (Test-Path $installerPath)) {
    throw "Installer not found after build: $installerPath"
}

Write-Host "Installer generated: $installerPath"
if ($env:GITHUB_OUTPUT) {
    "installer_path=$installerPath" >> $env:GITHUB_OUTPUT
}
