param(
    [Parameter(Mandatory = $true)]
    [string]$BaseVersion,
    [Parameter(Mandatory = $false)]
    [string]$Channel = 'alpha'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($BaseVersion -notmatch '^v\d+\.\d+\.\d+$') {
    throw "Invalid base_version '$BaseVersion'. Expected format: vMAJOR.MINOR.PATCH (example: v0.1.0)."
}

# Fetch tags to ensure we have the latest
git fetch --tags --force origin

$escapedBase = [regex]::Escape($BaseVersion)
$pattern = "^$escapedBase-$Channel\.(\d+)$"
$max = 0

$matchingTags = git tag --list "$BaseVersion-$Channel.*"
foreach ($tag in $matchingTags) {
    if ($tag -match $pattern) {
        $number = [int]$Matches[1]
        if ($number -gt $max) { $max = $number }
    }
}

$next = $max + 1
$nextTag = "$BaseVersion-$Channel.$next"

$existing = git tag --list $nextTag
if (-not [string]::IsNullOrWhiteSpace($existing)) {
    throw "Tag '$nextTag' already exists. Re-run workflow to compute a new sequence."
}

# Resolve clean version (strip leading 'v')
$version = if ($nextTag -match '^v(?<clean>.+)$') { $Matches.clean } else { $nextTag }

Write-Host "Computed Tag: $nextTag"
Write-Host "Resolved Version: $version"

if ($env:GITHUB_OUTPUT) {
    "computed_tag=$nextTag" >> $env:GITHUB_OUTPUT
    "version=$version" >> $env:GITHUB_OUTPUT
}
