param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [Parameter(Mandatory = $false)]
    [string]$WorkspacePath,
    [Parameter(Mandatory = $false)]
    [string]$ProjectPath,
    [Parameter(Mandatory = $true)]
    [string]$Scheme,
    [Parameter(Mandatory = $false)]
    [string]$Configuration = 'Release',
    [Parameter(Mandatory = $false)]
    [string]$Sdk = 'macosx',
    [Parameter(Mandatory = $false)]
    [string]$ArchivePath = 'artifacts/macos/Aiden.xcarchive',
    [Parameter(Mandatory = $false)]
    [string]$ExportPath = 'artifacts/macos/export',
    [Parameter(Mandatory = $false)]
    [string]$ExportOptionsPlist = '',
    [Parameter(Mandatory = $true)]
    [string]$AppOutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-MacVersionParts {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SemanticVersion
    )

    $match = [regex]::Match($SemanticVersion, '^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)(?:-(?<channel>[A-Za-z]+)\.(?<seq>\d+))?$')
    if (-not $match.Success) {
        throw "Unsupported version format: $SemanticVersion"
    }

    $marketingVersion = "$($match.Groups['major'].Value).$($match.Groups['minor'].Value).$($match.Groups['patch'].Value)"
    $buildVersion = if ($match.Groups['seq'].Success) { $match.Groups['seq'].Value } else { '0' }

    return @{
        MarketingVersion = $marketingVersion
        BuildVersion = $buildVersion
    }
}

$hasWorkspace = -not [string]::IsNullOrWhiteSpace($WorkspacePath)
$hasProject = -not [string]::IsNullOrWhiteSpace($ProjectPath)
if ($hasWorkspace -eq $hasProject) {
    throw 'Provide exactly one of workspace_path or project_path.'
}

if ($hasWorkspace -and -not (Test-Path $WorkspacePath)) {
    throw "workspace_path not found: $WorkspacePath"
}
if ($hasProject -and -not (Test-Path $ProjectPath)) {
    throw "project_path not found: $ProjectPath"
}

$archiveDir = Split-Path -Parent $ArchivePath
if (-not [string]::IsNullOrWhiteSpace($archiveDir)) {
    New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
}
New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null

$env:RELEASE_VERSION = $Version
$versionParts = Get-MacVersionParts -SemanticVersion $Version

$archiveArgs = @()
if ($hasWorkspace) {
    $archiveArgs += @('-workspace', $WorkspacePath)
}
else {
    $archiveArgs += @('-project', $ProjectPath)
}
$archiveArgs += @(
    '-scheme', $Scheme,
    '-configuration', $Configuration,
    '-sdk', $Sdk,
    '-archivePath', $ArchivePath,
    "MARKETING_VERSION=$($versionParts.MarketingVersion)",
    "CURRENT_PROJECT_VERSION=$($versionParts.BuildVersion)",
    'archive'
)

& xcodebuild @archiveArgs
if ($LASTEXITCODE -ne 0) {
    throw "xcodebuild archive failed with exit code $LASTEXITCODE"
}

$resolvedExportOptionsPlist = $ExportOptionsPlist
if ([string]::IsNullOrWhiteSpace($resolvedExportOptionsPlist)) {
    $tmpRoot = if (-not [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) { $env:RUNNER_TEMP } else { Join-Path (Get-Location) 'artifacts/macos/tmp' }
    New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null
    $resolvedExportOptionsPlist = Join-Path $tmpRoot 'default-exportOptions.plist'
    @'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>method</key>
    <string>developer-id</string>
  </dict>
</plist>
'@ | Set-Content -Path $resolvedExportOptionsPlist -Encoding utf8
}
elseif (-not (Test-Path $resolvedExportOptionsPlist)) {
    throw "export_options_plist not found: $resolvedExportOptionsPlist"
}

$exportArgs = @(
    '-exportArchive',
    '-archivePath', $ArchivePath,
    '-exportPath', $ExportPath,
    '-exportOptionsPlist', $resolvedExportOptionsPlist
)

& xcodebuild @exportArgs
if ($LASTEXITCODE -ne 0) {
    throw "xcodebuild -exportArchive failed with exit code $LASTEXITCODE"
}

$exportedApp = Get-ChildItem -Path $ExportPath -Filter '*.app' -Recurse | Select-Object -First 1
if ($null -eq $exportedApp) {
    throw "No .app found under export_path: $ExportPath"
}

$appOutputDir = Split-Path -Parent $AppOutputPath
if (-not [string]::IsNullOrWhiteSpace($appOutputDir)) {
    New-Item -ItemType Directory -Path $appOutputDir -Force | Out-Null
}

if (Test-Path $AppOutputPath) {
    Remove-Item -Path $AppOutputPath -Recurse -Force
}
Copy-Item -Path $exportedApp.FullName -Destination $AppOutputPath -Recurse -Force

if ($env:GITHUB_OUTPUT) {
    "app_output_path=$AppOutputPath" >> $env:GITHUB_OUTPUT
    "archive_path=$ArchivePath" >> $env:GITHUB_OUTPUT
}
