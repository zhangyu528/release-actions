param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [Parameter(Mandatory = $true)]
    [string]$FilesJson,
    [Parameter(Mandatory = $true)]
    [string]$OutputFile
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$files = $FilesJson | ConvertFrom-Json
if ($null -eq $files -or $files.Count -eq 0) {
    throw 'files_json must contain at least one file path.'
}

$lines = @()
foreach ($raw in $files) {
    $file = $raw.Replace('{version}', $Version)
    if (-not (Test-Path $file)) {
        throw "File not found for checksum: $file"
    }
    $hash = (Get-FileHash -Algorithm SHA256 -Path $file).Hash.ToLowerInvariant()
    $name = Split-Path -Leaf $file
    $lines += "$hash  $name"
}

$outputDir = Split-Path -Parent $OutputFile
if (-not [string]::IsNullOrWhiteSpace($outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$lines | Set-Content -Path $OutputFile -Encoding Ascii
