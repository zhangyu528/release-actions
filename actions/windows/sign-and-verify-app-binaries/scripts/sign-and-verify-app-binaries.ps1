param(
    [Parameter(Mandatory = $false)]
    [string]$SignedAppsDir = 'artifacts/signed/apps',
    [Parameter(Mandatory = $true)]
    [string]$UnsignedExePathsJson,
    [Parameter(Mandatory = $false)]
    [string]$StagingRoot = 'artifacts/stage'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not (Test-Path $StagingRoot)) {
    throw "Staging root not found: $StagingRoot"
}

$unsignedExePaths = @($UnsignedExePathsJson | ConvertFrom-Json)
if ($unsignedExePaths.Count -eq 0) {
    throw 'No unsigned exe paths provided.'
}

$byName = @{}
foreach ($unsignedPath in $unsignedExePaths) {
    $leaf = Split-Path -Leaf $unsignedPath
    if ([string]::IsNullOrWhiteSpace($leaf)) {
        throw "Invalid unsigned exe path: $unsignedPath"
    }
    if (-not $byName.ContainsKey($leaf)) {
        $byName[$leaf] = @()
    }
    $byName[$leaf] += $unsignedPath
}

$signedExes = @(Get-ChildItem -Path $SignedAppsDir -Filter '*.exe' -File -Recurse -ErrorAction Stop)
if ($signedExes.Count -eq 0) {
    throw "No signed executables found in: $SignedAppsDir"
}

foreach ($signedExe in $signedExes) {
    $name = $signedExe.Name
    if (-not $byName.ContainsKey($name)) {
        throw "Signed executable '$name' has no matching unsigned target from publish output list."
    }

    $targets = @($byName[$name])
    if ($targets.Count -ne 1) {
        throw "Signed executable '$name' matches multiple unsigned targets: $($targets -join ', '). Rename binaries to avoid collision."
    }

    $targetPath = $targets[0]
    New-Item -ItemType Directory -Path (Split-Path -Parent $targetPath) -Force | Out-Null
    Copy-Item -Path $signedExe.FullName -Destination $targetPath -Force

    $sig = Get-AuthenticodeSignature -FilePath $targetPath
    if ($sig.Status -ne 'Valid') {
        throw "Invalid signature on $targetPath. Status=$($sig.Status)"
    }

    $byName.Remove($name) | Out-Null
}

if ($byName.Count -gt 0) {
    throw "Some unsigned executables were not replaced by signed outputs: $($byName.Keys -join ', ')"
}