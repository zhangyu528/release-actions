param(
    [Parameter(Mandatory = $true)]
    [string]$AppBundlePath,
    [Parameter(Mandatory = $false)]
    [string]$StageDir = 'artifacts/macos/stage',
    [Parameter(Mandatory = $false)]
    [string]$AppName = 'Aiden',
    [Parameter(Mandatory = $true)]
    [string]$ActionPath,
    [Parameter(Mandatory = $true)]
    [string]$RuntimeHelperSources
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

$bundledInstaller = Join-Path $ActionPath 'assets/macos/install-runtime-deps.sh'
if (-not (Test-Path $bundledInstaller)) {
    throw "Bundled installer runtime script not found: $bundledInstaller"
}
Copy-Item -Path $bundledInstaller -Destination (Join-Path $scriptsDir 'install-runtime-deps.sh') -Force

$helpers = @($RuntimeHelperSources -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if ($helpers.Count -eq 0) {
    throw 'runtime_helper_sources must contain at least one script path.'
}

foreach ($helper in $helpers) {
    if (-not (Test-Path $helper)) {
        throw "Runtime helper script not found: $helper"
    }
    Copy-Item -Path $helper -Destination $scriptsDir -Force
}

$postinstallPath = Join-Path $scriptsDir 'postinstall'
$postinstall = @"
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
exec "\$SCRIPT_DIR/install-runtime-deps.sh" "$AppName"
"@
$postinstall | Set-Content -Path $postinstallPath -Encoding Ascii

bash -lc "chmod +x '$scriptsDir/install-runtime-deps.sh' '$postinstallPath'"
foreach ($helper in $helpers) {
    $filename = Split-Path -Leaf $helper
    bash -lc "chmod +x '$scriptsDir/$filename'"
}

if ($env:GITHUB_OUTPUT) {
    "staged_app_bundle_path=$stagedAppBundlePath" >> $env:GITHUB_OUTPUT
    "scripts_dir=$scriptsDir" >> $env:GITHUB_OUTPUT
}
