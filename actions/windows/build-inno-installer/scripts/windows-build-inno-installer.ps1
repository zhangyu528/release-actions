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
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$resolvedSourceDir = (Resolve-Path $SourceDir).Path
$resolvedOutputDir = (Resolve-Path $OutputDir).Path

$iscc = 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
if (-not (Test-Path $iscc)) {
    throw "Inno Setup compiler not found: $iscc"
}

$issTemplate = Join-Path $ActionPath 'assets/windows/default-installer.iss'
if (-not (Test-Path $issTemplate)) {
    throw "ISS template not found: $issTemplate"
}

$resolvedSetupIconName = $SetupIconName
$setupIconPath = Join-Path $resolvedSourceDir $resolvedSetupIconName
if (-not (Test-Path $setupIconPath)) {
    $availableIcons = @(Get-ChildItem -Path $resolvedSourceDir -Filter '*.ico' -File -ErrorAction SilentlyContinue)
    if ($availableIcons.Count -eq 1) {
        $resolvedSetupIconName = $availableIcons[0].Name
        Write-Warning "Setup icon '$SetupIconName' not found. Falling back to detected icon '$resolvedSetupIconName'."
    }
    elseif ($availableIcons.Count -gt 1) {
        $iconList = $availableIcons | ForEach-Object { $_.Name } | Sort-Object
        throw "Setup icon '$SetupIconName' not found in '$resolvedSourceDir'. Multiple .ico files were found: $($iconList -join ', '). Set input 'setup_icon_name' explicitly."
    }
    else {
        throw "Setup icon '$SetupIconName' not found in '$resolvedSourceDir', and no .ico file is available for fallback."
    }
}

$outputFileBase = "$OutputNamePrefix-$Version-$InstallerBitness"

$isccOutput = & $iscc `
  "/DAppName=$AppName" `
  "/DAppVersion=$Version" `
  "/DSourceDir=$resolvedSourceDir" `
  "/DOutputDir=$resolvedOutputDir" `
  "/DInstallerFilename=$outputFileBase" `
  "/DPostInstallLaunchExeName=$PostInstallLaunchExe" `
  "/DAutoRunExeName=$AutoRunExe" `
  "/DSetupIconName=$resolvedSetupIconName" `
  $issTemplate 2>&1

if ($isccOutput) {
    $isccOutput | ForEach-Object { Write-Host $_ }
}

if ($LASTEXITCODE -ne 0) {
    throw "ISCC failed with exit code $LASTEXITCODE"
}

$installerPath = Join-Path $resolvedOutputDir "$outputFileBase.exe"
if (-not (Test-Path $installerPath)) {
    throw "Installer not found after build: $installerPath"
}

Write-Host "Installer generated: $installerPath"
if ($env:GITHUB_OUTPUT) {
    "installer_path=$installerPath" >> $env:GITHUB_OUTPUT
}
