param(
    [Parameter(Mandatory = $false)]
    [string]$SignedAppsDir = 'artifacts/signed/apps',
    [Parameter(Mandatory = $false)]
    [string]$TrayTarget = 'artifacts/stage/tray/Aiden.TrayMonitor.exe',
    [Parameter(Mandatory = $false)]
    [string]$AgentTarget = 'artifacts/stage/agent/Aiden.RuntimeAgent.exe'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$signedTray = Join-Path $SignedAppsDir 'Aiden.TrayMonitor.exe'
$signedAgent = Join-Path $SignedAppsDir 'Aiden.RuntimeAgent.exe'

if (-not (Test-Path $signedTray)) {
    throw "Signed tray executable not found: $signedTray"
}
if (-not (Test-Path $signedAgent)) {
    throw "Signed agent executable not found: $signedAgent"
}

New-Item -ItemType Directory -Path (Split-Path -Parent $TrayTarget) -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path -Parent $AgentTarget) -Force | Out-Null
Copy-Item -Path $signedTray -Destination $TrayTarget -Force
Copy-Item -Path $signedAgent -Destination $AgentTarget -Force

foreach ($file in @($TrayTarget, $AgentTarget)) {
    $sig = Get-AuthenticodeSignature -FilePath $file
    if ($sig.Status -ne 'Valid') {
        throw "Invalid signature on $file. Status=$($sig.Status)"
    }
}
