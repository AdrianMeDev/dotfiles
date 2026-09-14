$ErrorActionPreference = 'Stop'
$mutex = New-Object Threading.Mutex($false, 'Local\DotfilesGlazeWMStart')
try {
    if ($mutex.WaitOne(10000)) {
        try {
            if (-not (Get-Process glazewm -ErrorAction SilentlyContinue)) {
                Start-Process glazewm.exe -ArgumentList ('start --config "' + (Join-Path $PSScriptRoot 'config.yaml') + '"')
            }
        } finally { $mutex.ReleaseMutex() }
    } else { throw 'GlazeWM-Start ist bereits aktiv.' }
} finally { $mutex.Dispose() }
