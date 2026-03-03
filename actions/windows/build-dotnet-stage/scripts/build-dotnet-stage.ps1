param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [Parameter(Mandatory = $true)]
    [string]$Rid,
    [Parameter(Mandatory = $true)]
    [string]$SolutionPath,
    [Parameter(Mandatory = $false)]
    [string]$Configuration = 'Release',
    [Parameter(Mandatory = $false)]
    [string]$SelfContained = 'true',
    [Parameter(Mandatory = $false)]
    [string]$PublishSingleFile = 'true',
    [Parameter(Mandatory = $false)]
    [string]$IncludeNativeLibrariesForSelfExtract = 'true',
    [Parameter(Mandatory = $false)]
    [string]$PreparePackageScript = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-NumericVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SemanticVersion
    )

    $match = [regex]::Match($SemanticVersion, '^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)(?:-(?<channel>[A-Za-z]+)\.(?<seq>\d+))?$')
    if (-not $match.Success) {
        throw "Unsupported version format: $SemanticVersion"
    }

    $major = [int]$match.Groups['major'].Value
    $minor = [int]$match.Groups['minor'].Value
    $patch = [int]$match.Groups['patch'].Value
    $revision = 0
    if ($match.Groups['seq'].Success) {
        $revision = [int]$match.Groups['seq'].Value
    }

    return "$major.$minor.$patch.$revision"
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    throw 'Version is empty.'
}
if ([string]::IsNullOrWhiteSpace($SolutionPath)) {
    throw 'solution_path is empty.'
}
if (-not (Test-Path $SolutionPath)) {
    throw "solution_path not found: $SolutionPath"
}

$solutionDir = Split-Path -Parent (Resolve-Path $SolutionPath).Path

$targetMap = @{
    'Aiden.TrayMonitor' = 'tray'
    'Aiden.RuntimeAgent' = 'agent'
}

$resolvedProjects = @{}
$projectLinePattern = '^Project\(".*"\)\s*=\s*"(?<name>[^"]+)"\s*,\s*"(?<path>[^"]+\.csproj)"\s*,'

Get-Content -Path $SolutionPath | ForEach-Object {
    $line = $_
    $match = [regex]::Match($line, $projectLinePattern)
    if (-not $match.Success) {
        return
    }

    $name = $match.Groups['name'].Value
    if (-not $targetMap.ContainsKey($name)) {
        return
    }

    $relativePath = $match.Groups['path'].Value -replace '\\', [System.IO.Path]::DirectorySeparatorChar
    $projectPath = Join-Path $solutionDir $relativePath
    $resolvedProjects[$name] = $projectPath
}

$missingProjects = @($targetMap.Keys | Where-Object { -not $resolvedProjects.ContainsKey($_) })
if ($missingProjects.Count -gt 0) {
    throw "Required publish projects not found in solution '$SolutionPath': $($missingProjects -join ', ')"
}

$stagingRoot = 'artifacts/stage'
New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null

$numericVersion = Get-NumericVersion -SemanticVersion $Version

foreach ($projectName in $targetMap.Keys) {
    $projectPath = $resolvedProjects[$projectName]
    if (-not (Test-Path $projectPath)) {
        throw "Project file not found for '$projectName': $projectPath"
    }

    $outputSubdir = $targetMap[$projectName]
    $outputDir = Join-Path $stagingRoot $outputSubdir
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

    dotnet publish $projectPath `
      -c $Configuration `
      -r $Rid `
      --self-contained $SelfContained `
      /p:Version=$Version `
      /p:InformationalVersion=$Version `
      /p:AssemblyVersion=$numericVersion `
      /p:FileVersion=$numericVersion `
      /p:PublishSingleFile=$PublishSingleFile `
      /p:IncludeNativeLibrariesForSelfExtract=$IncludeNativeLibrariesForSelfExtract `
      /p:DebugType=None `
      /p:DebugSymbols=false `
      -o $outputDir
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet publish failed for '$projectName' with exit code $LASTEXITCODE"
    }
}

if (-not [string]::IsNullOrWhiteSpace($PreparePackageScript)) {
    if (-not (Test-Path $PreparePackageScript)) {
        throw "prepare_package_script not found: $PreparePackageScript"
    }
    & $PreparePackageScript -Version $Version
}

Write-Host "Staging complete at: $stagingRoot"
if ($env:GITHUB_OUTPUT) {
    "staging_dir=$stagingRoot" >> $env:GITHUB_OUTPUT
}
