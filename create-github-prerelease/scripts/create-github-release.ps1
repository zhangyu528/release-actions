param(
    [Parameter(Mandatory = $true)]
    [string]$Tag,
    [Parameter(Mandatory = $false)]
    [string]$TargetBranch = 'main'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Write-Host "Creating GitHub pre-release for tag: $Tag (target: $TargetBranch)" -ForegroundColor Cyan

$releaseUrl = gh release create $Tag --prerelease --target $TargetBranch --generate-notes

if (-not $releaseUrl) {
    throw "Failed to create GitHub release for tag $Tag"
}

Write-Host "Release created: $releaseUrl"

$uploadUrl = gh release view $Tag --json uploadUrl --jq .uploadUrl

if ($env:GITHUB_OUTPUT) {
    "release_url=$releaseUrl" >> $env:GITHUB_OUTPUT
    "release_upload_url=$uploadUrl" >> $env:GITHUB_OUTPUT
}
