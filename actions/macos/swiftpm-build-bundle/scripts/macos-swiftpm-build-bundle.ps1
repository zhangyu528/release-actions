param(
    [Parameter(Mandatory=$true)][string]$Version,
    [Parameter(Mandatory=$false)][string]$WorkspaceDir = '',
    [Parameter(Mandatory=$false)][string]$AppOutputPath = 'artifacts/macos/Aiden.app',
    [Parameter(Mandatory=$false)][string]$PayloadDir = 'artifacts/macos/payload',
    [Parameter(Mandatory=$false)][string]$TrayBundleIdentifier = 'com.aiden.traymac',
    [Parameter(Mandatory=$false)][string]$AgentBundleIdentifier = 'com.aiden.runtimeagent',
    [Parameter(Mandatory=$false)][string]$AppSigningIdentity = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = if (-not [string]::IsNullOrWhiteSpace($WorkspaceDir)) {
    Resolve-Path $WorkspaceDir
}
elseif (-not [string]::IsNullOrWhiteSpace($env:GITHUB_WORKSPACE)) {
    Resolve-Path $env:GITHUB_WORKSPACE
}
else {
    Resolve-Path (Join-Path $PSScriptRoot '..\\..\\..')
}
$buildDir = Join-Path $repoRoot '.build/release'
if (-not (Test-Path $buildDir)) {
    New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
}

function EnsureProduct {
    param([string]$ProductName)
    Write-Host "Building SwiftPM product: $ProductName"
    & swift build -c release --product $ProductName
    if ($LASTEXITCODE -ne 0) {
        throw "swift build failed for $ProductName"
    }
}

EnsureProduct -ProductName 'AidenTrayMac'
EnsureProduct -ProductName 'AidenRuntimeAgent'

$appRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $AppOutputPath))
New-Item -ItemType Directory -Path (Split-Path -Parent $appRoot) -Force | Out-Null
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $appRoot '*')
New-Item -ItemType Directory -Path $appRoot -Force | Out-Null

$appContents = Join-Path $appRoot 'Contents'
$macosDir = Join-Path $appContents 'MacOS'
$resourcesDir = Join-Path $appContents 'Resources'
New-Item -ItemType Directory -Path $macosDir -Force | Out-Null
New-Item -ItemType Directory -Path $resourcesDir -Force | Out-Null

$trayBinary = Join-Path $macosDir 'AidenTrayMac'
$agentBootstrap = Join-Path $appContents 'Library/Application Support/Aiden/bootstrap'
New-Item -ItemType Directory -Path $agentBootstrap -Force | Out-Null
$agentBinary = Join-Path $agentBootstrap 'AidenRuntimeAgent'

Copy-Item -Path (Join-Path $buildDir 'AidenTrayMac') -Destination $trayBinary -Force
Copy-Item -Path (Join-Path $buildDir 'AidenRuntimeAgent') -Destination $agentBinary -Force
chmod 755 $trayBinary
chmod 755 $agentBinary

$infoPlistPath = Join-Path $appContents 'Info.plist'
$infoPlist = @"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>AidenTrayMac</string>
  <key>CFBundleDisplayName</key>
  <string>Aiden Tray</string>
  <key>CFBundleIdentifier</key>
  <string>$TrayBundleIdentifier</string>
  <key>CFBundleVersion</key>
  <string>$Version</string>
  <key>CFBundleShortVersionString</key>
  <string>$Version</string>
  <key>CFBundleExecutable</key>
  <string>AidenTrayMac</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
"@
Set-Content -Value $infoPlist -Path $infoPlistPath -Encoding UTF8

if (-not [string]::IsNullOrWhiteSpace($AppSigningIdentity)) {
    codesign --force --options runtime --timestamp --deep --sign "$AppSigningIdentity" "$appRoot"
    if ($LASTEXITCODE -ne 0) { throw "codesign failed for $appRoot" }
}

New-Item -ItemType Directory -Path $PayloadDir -Force | Out-Null
Copy-Item -Path $appRoot -Destination (Join-Path $PayloadDir 'Applications') -Recurse -Force
New-Item -ItemType Directory -Path (Join-Path $PayloadDir 'Library/Application Support/Aiden/bootstrap') -Force | Out-Null
Copy-Item -Path $agentBinary -Destination (Join-Path $PayloadDir 'Library/Application Support/Aiden/bootstrap/AidenRuntimeAgent') -Force

if ($env:GITHUB_OUTPUT) {
    "app_bundle_path=$appRoot" >> $env:GITHUB_OUTPUT
    "payload_dir=$PayloadDir" >> $env:GITHUB_OUTPUT
}
