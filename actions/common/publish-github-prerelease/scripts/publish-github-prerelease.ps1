param(
    [Parameter(Mandatory = $true)]
    [string]$Tag,
    [Parameter(Mandatory = $false)]
    [string]$TargetBranch = 'main',
    [Parameter(Mandatory = $true)]
    [string]$GitHubToken,
    [Parameter(Mandatory = $true)]
    [string]$AssetsManifest,
    [Parameter(Mandatory = $false)]
    [string]$PrintSummary = 'true'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Upload-ReleaseAsset {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUploadUrl,
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string]$AssetName,
        [Parameter(Mandatory = $true)]
        [string]$ContentType,
        [Parameter(Mandatory = $true)]
        [string]$Token
    )

    if (-not (Test-Path $FilePath)) {
        throw "Asset file not found: $FilePath"
    }

    $cleanUrl = $BaseUploadUrl -replace '\{\?name,label\}$', ''
    $encodedName = [uri]::EscapeDataString($AssetName)
    $assetUrl = "${cleanUrl}?name=$encodedName"
    $headers = @{
        Authorization = "Bearer $Token"
        Accept = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }

    Invoke-WebRequest `
      -Uri $assetUrl `
      -Method Post `
      -Headers $headers `
      -InFile $FilePath `
      -ContentType $ContentType | Out-Null
}

Write-Host "Creating GitHub pre-release for tag: $Tag (target: $TargetBranch)" -ForegroundColor Cyan
$env:GH_TOKEN = $GitHubToken

$releaseUrl = gh release create $Tag --prerelease --target $TargetBranch --generate-notes
if (-not $releaseUrl) {
    throw "Failed to create GitHub release for tag $Tag"
}
$uploadUrl = gh release view $Tag --json uploadUrl --jq .uploadUrl

$manifest = @($AssetsManifest | ConvertFrom-Json)
if ($manifest.Length -eq 0) {
    throw 'assets_manifest must contain at least one asset entry.'
}

$count = 0
foreach ($asset in $manifest) {
    if ([string]::IsNullOrWhiteSpace($asset.path)) {
        throw 'Each assets_manifest item requires "path".'
    }
    $name = if ([string]::IsNullOrWhiteSpace($asset.name)) { Split-Path -Leaf $asset.path } else { $asset.name }
    $contentType = if ([string]::IsNullOrWhiteSpace($asset.content_type)) { 'application/octet-stream' } else { $asset.content_type }
    Upload-ReleaseAsset -BaseUploadUrl $uploadUrl -FilePath $asset.path -AssetName $name -ContentType $contentType -Token $GitHubToken
    $count++
}

if ($PrintSummary -eq 'true') {
    Write-Host '--- Pre-release Summary ---' -ForegroundColor Cyan
    Write-Host "Computed tag: $Tag"
    Write-Host "Pre-release URL: $releaseUrl"
    Write-Host "Uploaded assets: $count"
    Write-Host '---------------------------'
}

if ($env:GITHUB_OUTPUT) {
    "release_url=$releaseUrl" >> $env:GITHUB_OUTPUT
    "release_upload_url=$uploadUrl" >> $env:GITHUB_OUTPUT
    "uploaded_count=$count" >> $env:GITHUB_OUTPUT
}
