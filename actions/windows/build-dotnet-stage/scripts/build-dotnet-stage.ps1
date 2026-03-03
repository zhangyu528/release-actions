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

function Test-PublishableExeProject {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath
    )

    $projectName = [System.IO.Path]::GetFileNameWithoutExtension($ProjectPath)
    if ($projectName -match '(?i)(^|\.)tests?$') {
        return $false
    }

    $outputType = Get-ProjectOutputType -ProjectPath $ProjectPath
    if ([string]::IsNullOrWhiteSpace($outputType)) {
        Write-Host "Skip project '$projectName' (OutputType is empty)"
        return $false
    }

    $isPublishable = ($outputType -ieq 'Exe' -or $outputType -ieq 'WinExe')
    Write-Host "Project '$projectName' OutputType='$outputType' Publish=$isPublishable"
    return $isPublishable
}

function Get-ProjectOutputType {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath
    )

    try {
        $rawOutput = & dotnet msbuild $ProjectPath -nologo -verbosity:quiet -getProperty:OutputType 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "dotnet msbuild failed with exit code $LASTEXITCODE. Output: $($rawOutput -join [Environment]::NewLine)"
        }

        $lines = @($rawOutput | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($lines.Length -eq 0) {
            return ''
        }

        return $lines[-1].Trim()
    }
    catch {
        $projectName = [System.IO.Path]::GetFileNameWithoutExtension($ProjectPath)
        throw "Failed to evaluate project type for '$projectName' at '$ProjectPath': $($_.Exception.Message)"
    }
}

function Get-SolutionProjectPaths {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SolutionPath,
        [Parameter(Mandatory = $true)]
        [string]$SolutionDir
    )

    $rawListOutput = & dotnet sln $SolutionPath list 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet sln list failed with exit code $LASTEXITCODE. Output: $($rawListOutput -join [Environment]::NewLine)"
    }

    $relativeProjectPaths = @(
        $rawListOutput |
        ForEach-Object { [string]$_ } |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Where-Object { $_ -match '(?i)\.csproj$' }
    )

    if ($relativeProjectPaths.Length -eq 0) {
        throw "No .csproj entries found from 'dotnet sln $SolutionPath list'."
    }

    $resolvedProjects = @()
    foreach ($relativePath in $relativeProjectPaths) {
        $projectPath = Join-Path $SolutionDir ($relativePath -replace '\\', [System.IO.Path]::DirectorySeparatorChar)
        if (-not (Test-Path $projectPath)) {
            throw "Project file not found: $projectPath"
        }

        $resolvedProjects += [pscustomobject]@{
            Name = [System.IO.Path]::GetFileNameWithoutExtension($projectPath)
            Path = $projectPath
        }
    }

    return $resolvedProjects
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
$solutionProjects = @(Get-SolutionProjectPaths -SolutionPath $SolutionPath -SolutionDir $solutionDir)

$publishProjects = @($solutionProjects | Where-Object { Test-PublishableExeProject -ProjectPath $_.Path })
if ($publishProjects.Count -eq 0) {
    throw "No publishable executable projects found in solution '$SolutionPath'."
}

$stagingRoot = 'artifacts/stage'
if (Test-Path $stagingRoot) {
    Remove-Item -Path $stagingRoot -Recurse -Force -ErrorAction Stop
}
New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null

$numericVersion = Get-NumericVersion -SemanticVersion $Version
$publishedProjectDirs = @()
$publishedExePaths = @()

foreach ($project in $publishProjects) {
    $outputDir = Join-Path $stagingRoot $project.Name
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

    dotnet publish $project.Path `
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
        throw "dotnet publish failed for '$($project.Name)' with exit code $LASTEXITCODE"
    }

    $publishedProjectDirs += ($outputDir -replace '\\','/')

    $projectExes = @(Get-ChildItem -Path $outputDir -Filter '*.exe' -File -ErrorAction Stop)
    foreach ($exe in $projectExes) {
        $publishedExePaths += ($exe.FullName -replace [regex]::Escape((Resolve-Path '.').Path + '\\'), '' -replace '\\','/')
    }
}

if ($publishedExePaths.Count -eq 0) {
    throw "No .exe files found in published outputs under '$stagingRoot'."
}

if (-not [string]::IsNullOrWhiteSpace($PreparePackageScript)) {
    if (-not (Test-Path $PreparePackageScript)) {
        throw "prepare_package_script not found: $PreparePackageScript"
    }
    & $PreparePackageScript -Version $Version
}

$projectDirsJson = $publishedProjectDirs | ConvertTo-Json -Compress -AsArray
$exePathsJson = $publishedExePaths | ConvertTo-Json -Compress -AsArray

Write-Host "Staging complete at: $stagingRoot"
Write-Host "Published project dirs: $projectDirsJson"
Write-Host "Published exe paths: $exePathsJson"

if ($env:GITHUB_OUTPUT) {
    "staging_dir=$stagingRoot" >> $env:GITHUB_OUTPUT
    "published_project_dirs_json=$projectDirsJson" >> $env:GITHUB_OUTPUT
    "published_exe_paths_json=$exePathsJson" >> $env:GITHUB_OUTPUT
}
