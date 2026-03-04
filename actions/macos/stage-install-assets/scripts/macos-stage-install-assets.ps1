param(
    [Parameter(Mandatory = $true)]
    [string]$AppBundlePath,
    [Parameter(Mandatory = $false)]
    [string]$StageDir = 'artifacts/macos/stage',
    [Parameter(Mandatory = $false)]
    [string]$AppName = 'Aiden',
    [Parameter(Mandatory = $false)]
    [string]$RuntimeHelperDir = 'scripts/runtime-deps'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not (Test-Path $AppBundlePath)) {
    throw "App bundle not found: $AppBundlePath"
}

if (Test-Path $StageDir) {
    Remove-Item -Path $StageDir -Recurse -Force
}
New-Item -ItemType Directory -Path $StageDir -Force | Out-Null

$appName = Split-Path -Leaf $AppBundlePath
$stagedAppBundlePath = Join-Path $StageDir $appName
Copy-Item -Path $AppBundlePath -Destination $stagedAppBundlePath -Recurse -Force

$scriptsDir = Join-Path $StageDir 'scripts'
New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null

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

$helperFiles = Get-ChildItem -Path $helperRoot -File
if ($helperFiles.Count -eq 0) {
    throw "No helper scripts found in $helperRoot"
}

foreach ($file in $helperFiles) {
    Copy-Item -Path $file.FullName -Destination (Join-Path $scriptsDir $file.Name) -Force
}

$installerScript = Join-Path $scriptsDir 'install-runtime-deps.sh'
if (-not (Test-Path $installerScript)) {
    throw "Installer helper script missing from $helperRoot: install-runtime-deps.sh"
}

$postinstallPath = Join-Path $scriptsDir 'postinstall'
$postinstall = @"
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
exec "\$SCRIPT_DIR/install-runtime-deps.sh" "$AppName"
"@
$postinstall | Set-Content -Path $postinstallPath -Encoding Ascii

bash -lc "chmod +x '$installerScript' '$postinstallPath'"
foreach ($file in $helperFiles) {
    $filename = $file.Name
    bash -lc "chmod +x '$scriptsDir/$filename'"
}

if ($env:GITHUB_OUTPUT) {
    "staged_app_bundle_path=$stagedAppBundlePath" >> $env:GITHUB_OUTPUT
    "scripts_dir=$scriptsDir" >> $env:GITHUB_OUTPUT
}
