#requires -Version 7.0
[CmdletBinding()]
param([switch]$Check)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$settings = Get-Content -LiteralPath (Join-Path $root 'config/verified-settings.json') -Raw | ConvertFrom-Json
if ($settings.format -ne 'manual-settings-snapshot' -or $settings.format_version -ne 1) {
    throw 'Unsupported settings snapshot format.'
}
if (-not $settings.in_game_graphics.Count) { throw 'No graphics settings found.' }
$rows = @('| Setting | Value |', '| --- | --- |')
foreach ($setting in $settings.in_game_graphics) {
    if (-not $setting.label -or [string]::IsNullOrWhiteSpace([string]$setting.value)) {
        throw 'Every graphics setting needs a label and value.'
    }
    $rows += '| ' + $setting.label.Replace('|', '\|') + ' | ' + ([string]$setting.value).Replace('|', '\|') + ' |'
}
$readmePath = Join-Path $root 'README.md'
$readme = (Get-Content -LiteralPath $readmePath -Raw).Replace("`r`n", "`n")
$pattern = '(?s)<!-- SETTINGS:START -->.*?<!-- SETTINGS:END -->'
if ([regex]::Matches($readme, $pattern).Count -ne 1) { throw 'Expected exactly one settings-table region.' }
$region = "<!-- SETTINGS:START -->`n" + ($rows -join "`n") + "`n<!-- SETTINGS:END -->"
$updated = [regex]::Replace($readme, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $region })
if ($Check) {
    if ($updated -cne $readme) { throw 'README settings table is stale. Run this script without -Check.' }
    Write-Output 'Settings JSON parsed and README table matches.'
} else {
    [IO.File]::WriteAllText($readmePath, $updated, [Text.UTF8Encoding]::new($false))
    Write-Output 'Updated README graphics table from the verified settings snapshot.'
}
