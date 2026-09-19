param([string]$Version)

$ErrorActionPreference = 'Stop'
$addonRoot = Join-Path $PSScriptRoot 'DensGuildMap'
$tocPath = Join-Path $addonRoot 'DensGuildMap.toc'
$toc = [System.IO.File]::ReadAllText($tocPath)
$current = [regex]::Match($toc, '(?m)^## Version: (\d+)\.(\d+)\.(\d+)(-[A-Za-z0-9.-]+)?\r?$')
if (-not $current.Success) { throw 'Cannot read addon version from TOC.' }
if (-not $Version) {
    $Version = '{0}.{1}.{2}{3}' -f $current.Groups[1].Value, $current.Groups[2].Value, ([int]$current.Groups[3].Value + 1), $current.Groups[4].Value
}
if ($Version -notmatch '^\d+\.\d+\.\d+(-[A-Za-z0-9.-]+)?$') {
    throw 'Use a version such as 0.1.1-beta.'
}
$distRoot = Join-Path $PSScriptRoot 'dist'
$archivePath = Join-Path $distRoot "DensGuildMap-$Version.zip"
if (Test-Path -LiteralPath $archivePath) {
    throw "Release already exists: $archivePath. Choose a new version; existing releases are never overwritten."
}
New-Item -ItemType Directory -Path $distRoot -Force | Out-Null
$updated = [regex]::Replace($toc, '(?m)^## Version: [^\r\n]+', "## Version: $Version")
[System.IO.File]::WriteAllText($tocPath, $updated, (New-Object System.Text.UTF8Encoding $false))
try {
    Compress-Archive -LiteralPath $addonRoot -DestinationPath $archivePath -ErrorAction Stop
} catch {
    [System.IO.File]::WriteAllText($tocPath, $toc, (New-Object System.Text.UTF8Encoding $false))
    throw
}
Write-Output "Created $archivePath"
