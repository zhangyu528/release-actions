param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [Parameter(Mandatory = $true)]
    [string]$PublishDirsJson,
    [Parameter(Mandatory = $false)]
    [string]$PackageDir = 'artifacts/stage/package',
    [Parameter(Mandatory = $false)]
    [string]$InstallerDir = 'artifacts/installer',
    [Parameter(Mandatory = $false)]
    [string]$IconSource = '',
    [Parameter(Mandatory = $false)]
    [string]$HelperScriptSources = '',
    [Parameter(Mandatory = $true)]
    [string]$ActionPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

foreach ($dir in @($PackageDir, $InstallerDir)) {
    if (Test-Path $dir) {
        Remove-Item -Recurse -Force -ErrorAction Stop $dir
    }
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$publishDirs = @($PublishDirsJson | ConvertFrom-Json)
if ($publishDirs.Count -eq 0) {
    throw 'No publish directories provided.'
}

foreach ($path in $publishDirs) {
    if (-not (Test-Path $path)) {
        throw "Publish directory not found: $path"
    }
}

Write-Host "Staging install payload for version $Version"
foreach ($publishDir in $publishDirs) {
    Copy-Item -Path (Join-Path $publishDir '*') -Destination $PackageDir -Recurse -Force
}

if (-not [string]::IsNullOrWhiteSpace($IconSource)) {
    if (Test-Path $IconSource) {
        Copy-Item -Path $IconSource -Destination $PackageDir -Force
    }
    else {
        Write-Warning "Icon not found: $IconSource"
    }
}

$helperDestDir = Join-Path $PackageDir 'scripts'
if (Test-Path $helperDestDir) {
    Remove-Item -Recurse -Force -ErrorAction Stop $helperDestDir
}
New-Item -ItemType Directory -Path $helperDestDir -Force | Out-Null

$bundledHelper = Join-Path $ActionPath 'assets/windows/install-runtime-deps.ps1'
if (-not (Test-Path $bundledHelper)) {
    throw "Bundled helper script not found: $bundledHelper"
}
Copy-Item -Path $bundledHelper -Destination (Join-Path $helperDestDir 'install-runtime-deps.ps1') -Force

if (-not [string]::IsNullOrWhiteSpace($HelperScriptSources)) {
    $extraScripts = @($HelperScriptSources -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    foreach ($scriptPath in $extraScripts) {
        if (-not (Test-Path $scriptPath)) {
            throw "Helper script not found: $scriptPath"
        }
        Copy-Item -Path $scriptPath -Destination $helperDestDir -Force
    }
}

$info = Get-ChildItem -Path $PackageDir -Recurse -File | Measure-Object -Property Length -Sum
Write-Host "Payload staged in $PackageDir"
Write-Host "  files: $($info.Count), size: $([math]::Round($info.Sum / 1MB, 2)) MB"