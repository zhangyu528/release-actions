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
    [string]$RuntimeHelperDir = 'scripts/runtime-deps'
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

$workspace = if ($env:GITHUB_WORKSPACE) { Resolve-Path $env:GITHUB_WORKSPACE } else { throw "GITHUB_WORKSPACE is unavailable." }
$helperRoot = if ([System.IO.Path]::IsPathRooted($RuntimeHelperDir)) {
    Resolve-Path $RuntimeHelperDir
}
else {
    Resolve-Path (Join-Path $workspace $RuntimeHelperDir)
}
if (-not (Test-Path $helperRoot)) {
    throw "Runtime helper directory not found: $helperRoot"
}

$helperFiles = Get-ChildItem -Path $helperRoot -File -Filter '*.ps1'
if ($helperFiles.Count -eq 0) {
    throw "No runtime helper scripts (*.ps1) were found under $helperRoot"
}

foreach ($file in $helperFiles) {
    $dest = Join-Path $helperDestDir $file.Name
    Copy-Item -Path $file.FullName -Destination $dest -Force
}

$info = Get-ChildItem -Path $PackageDir -Recurse -File | Measure-Object -Property Length -Sum
Write-Host "Payload staged in $PackageDir"
Write-Host "  files: $($info.Count), size: $([math]::Round($info.Sum / 1MB, 2)) MB"
