#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$AdbPath,
    [string]$Serial,
    [string]$OutputDirectory,
    [switch]$Screenshot
)
$ErrorActionPreference = 'Stop'
if (-not $AdbPath) {
    $command = Get-Command adb -ErrorAction SilentlyContinue
    if (-not $command) { throw 'Pass -AdbPath pointing to Google platform-tools/adb.exe.' }
    $AdbPath = $command.Source
}
if (-not (Test-Path -LiteralPath $AdbPath -PathType Leaf)) { throw 'ADB executable was not found.' }
$AdbPath = (Resolve-Path -LiteralPath $AdbPath).Path
function Invoke-Adb {
    param([string[]]$Arguments)
    $result = & $AdbPath @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw ('ADB failed: ' + ($result -join "`n")) }
    return @($result | ForEach-Object { [string]$_ })
}
$deviceLines = Invoke-Adb -Arguments @('devices')
$deviceSerials = @($deviceLines | ForEach-Object {
    if ($_ -match '^(\S+)\s+device\s*$') { $Matches[1] }
})
if ($Serial) {
    if ($Serial -notin $deviceSerials) { throw 'Selected serial is not an authorized, connected ADB device.' }
} else {
    if ($deviceSerials.Count -ne 1) { throw 'Connect one authorized device, or select it with -Serial.' }
    $Serial = $deviceSerials[0]
}
function Read-Device {
    param([string[]]$Command)
    return Invoke-Adb -Arguments (@('-s', $Serial, 'shell') + $Command)
}
$model = ((Read-Device -Command @('getprop', 'ro.product.model')) -join '').Trim()
if ($model -ne 'AYN Thor') { throw ('Expected AYN Thor, found: ' + $model) }
$package = Read-Device -Command @('dumpsys', 'package', 'app.gamenative')
$versionLine = $package | Where-Object { $_ -match '^\s*versionName=' } | Select-Object -First 1
if (-not $versionLine) { throw 'GameNative version was not found. Is app.gamenative installed?' }
$capturedAt = [DateTimeOffset]::Now
if (-not $OutputDirectory) {
    $root = Split-Path -Parent $PSScriptRoot
    $OutputDirectory = Join-Path $root ('outputs/capture-' + $capturedAt.ToString('yyyyMMdd-HHmmss-fff'))
}
if (Test-Path -LiteralPath $OutputDirectory) { throw 'Choose a new output directory; existing captures are preserved.' }
New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
$OutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path
$metadata = [ordered]@{
    capturedAt = $capturedAt.ToString('o')
    hostTimezone = [TimeZoneInfo]::Local.Id
    model = $model
    soc = ((Read-Device -Command @('getprop', 'ro.soc.model')) -join '').Trim()
    androidVersion = ((Read-Device -Command @('getprop', 'ro.build.version.release')) -join '').Trim()
    gamenativeVersion = ($versionLine -replace '^\s*versionName=', '').Trim()
    performanceMode = ((Read-Device -Command @('settings', 'get', 'system', 'performance_mode')) -join '').Trim()
    fanMode = ((Read-Device -Command @('settings', 'get', 'system', 'fan_mode')) -join '').Trim()
    note = 'PowerMetrics can include prior sessions, menus and loading. Identify the live-battle interval before comparing.'
}
$metadata | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutputDirectory 'device.json') -Encoding utf8
# Read only the metrics tag. Do not export launch environments, Steam tokens or full logcat.
$metrics = Invoke-Adb -Arguments @('-s', $Serial, 'logcat', '-d', '-v', 'threadtime', '-s', 'PowerMetrics:I', '*:S')
$metrics | Set-Content -LiteralPath (Join-Path $OutputDirectory 'power-metrics.txt') -Encoding utf8
if ($Screenshot) {
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $AdbPath
    foreach ($argument in @('-s', $Serial, 'exec-out', 'screencap', '-p')) { $info.ArgumentList.Add($argument) }
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $process = [Diagnostics.Process]::Start($info)
    try {
        $stream = [IO.File]::Create((Join-Path $OutputDirectory 'screen.png'))
        try { $process.StandardOutput.BaseStream.CopyTo($stream) } finally { $stream.Dispose() }
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) { throw 'ADB screenshot capture failed.' }
    } finally { $process.Dispose() }
}
Write-Output ('Saved diagnostics to ' + $OutputDirectory)
