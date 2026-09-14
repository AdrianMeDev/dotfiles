$ErrorActionPreference = 'Stop'
# Also serialize concurrent WM starts. Reloading the WM config never runs this hook.
$mutex = New-Object Threading.Mutex($false, 'Local\DotfilesZebarStart')
try {
    if ($mutex.WaitOne(10000)) {
        try {
            if (-not (Get-Process zebar -ErrorAction SilentlyContinue)) {
                Start-Process zebar.exe -ArgumentList 'startup'
            }
        } finally { $mutex.ReleaseMutex() }
    } else { throw 'Zebar-Start ist bereits aktiv.' }
} finally { $mutex.Dispose() }
