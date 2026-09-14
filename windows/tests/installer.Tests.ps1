# No Pester dependency. Run: pwsh -NoProfile -File windows/tests/installer.Tests.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/../installer-core.ps1"
$source = [IO.Path]::GetFullPath("$PSScriptRoot/..")
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('windows-tests-' + [guid]::NewGuid())
$previous = @{}
foreach ($name in 'USERPROFILE', 'APPDATA', 'LOCALAPPDATA') { $previous[$name] = [Environment]::GetEnvironmentVariable($name) }
function Assert($Condition, $Message) { if (-not $Condition) { throw "FAIL: $Message" } }
function Throws([scriptblock]$Action, [string]$Pattern) {
    try { & $Action } catch { Assert ($_.Exception.Message -match $Pattern) "unexpected error: $_"; return }
    throw "FAIL: expected error matching $Pattern"
}
$realNative = ${function:Invoke-Native}
$realPrerequisites = ${function:Assert-WindowsPrerequisites}
try {
    $env:USERPROFILE = Join-Path $temporary 'User with spaces'
    $env:APPDATA = Join-Path $env:USERPROFILE 'AppData/Roaming'
    $env:LOCALAPPDATA = Join-Path $env:USERPROFILE 'AppData/Local'
    $script:names = @('Fedora Linux')
    $script:version = 2
    $script:packageCalls = 0
    function Invoke-Native {
        param($Program, $Arguments, $SuccessCodes)
        if ($Program -eq 'wsl.exe') {
            if ($Arguments -contains '--quiet') { return $script:names }
            return ($script:names | ForEach-Object { "  $_    Stopped    $script:version" })
        }
        if ($Program -eq 'winget.exe') { $script:packageCalls++; return }
        throw "Unexpected command: $Program"
    }
    function Assert-WindowsPrerequisites {}
    Install-WindowsDesktop $source -DryRun
    Assert (-not (Test-Path $temporary)) 'dry run created files'
    Assert ($script:packageCalls -eq 0) 'dry run installed packages'
    $script:names = @('Fedora', 'Fedora Test')
    Throws { Select-WslDistro } 'nicht eindeutig'
    Assert ((Select-WslDistro 'Fedora Test') -eq 'Fedora Test') 'explicit distro with spaces'
    Throws { Select-WslDistro 'Missing' } 'nicht gefunden'
    $script:names = @('Ubuntu')
    Throws { Select-WslDistro } 'nicht eindeutig'
    $script:names = @('Fedora')
    $script:version = 1
    Throws { Select-WslDistro } 'WSL2'
    $script:version = 2
    $script:names = @("F`0e`0d`0o`0r`0a`0")
    Assert ((Select-WslDistro) -eq 'Fedora') 'UTF16 NUL cleanup'
    $script:names = @('Fedora')
    $entries = @(Get-ConfigEntries $source 'Fedora')
    $noAuto = @(Get-ConfigEntries $source 'Fedora' -NoAutostart)
    Assert ($noAuto.Count -eq $entries.Count - 1) 'NoAutostart'
    $plan = @(Get-FilePlan $entries)
    Write-FilePlan $plan
    $second = @(Get-FilePlan $entries)
    Assert (@($second | Where-Object Action -ne 'Skip').Count -eq 0) 'repeat was not idempotent'
    $target = $entries[0].Path
    [IO.File]::WriteAllText($target, 'custom')
    Throws { Get-FilePlan $entries } 'Dateikonflikt'
    $backupPlan = @(Get-FilePlan $entries -Backup)
    Write-FilePlan $backupPlan -DryRun
    Assert ([IO.File]::ReadAllText($target) -eq 'custom') 'dry run changed conflict'
    Write-FilePlan $backupPlan
    $saved = @(Get-ChildItem -LiteralPath (Split-Path $target) -Filter '*.backup-*')
    Assert ($saved.Count -eq 1 -and [IO.File]::ReadAllText($saved[0].FullName) -eq 'custom') 'backup contents'
    $collision = Join-Path $temporary 'directory'
    [IO.Directory]::CreateDirectory($collision) | Out-Null
    Throws { Get-FilePlan @((New-TextEntry $collision 'test')) -Backup } 'Verzeichnis'
    Throws { Get-FilePlan @((New-TextEntry (Join-Path $target 'child') 'test')) } 'Zielverzeichnis'
    if ([Environment]::OSVersion.Platform -ne 'Win32NT') {
        $link = Join-Path $temporary 'broken-link'
        New-Item -ItemType SymbolicLink -Path $link -Target (Join-Path $temporary 'missing') | Out-Null
        Throws { Get-FilePlan @((New-TextEntry $link 'test')) -Backup } 'Verknuepfung'
    }
    # Repeated full installation using mocked Windows registry, network, archive and packages.
    function Invoke-WebRequest { param($Uri, $OutFile, [switch]$UseBasicParsing) [IO.File]::WriteAllText($OutFile, 'mock archive') }
    function Expand-Archive {
        param($LiteralPath, $DestinationPath)
        [IO.Directory]::CreateDirectory($DestinationPath) | Out-Null
        foreach ($style in 'Regular', 'Bold', 'Italic', 'BoldItalic') {
            [IO.File]::WriteAllText((Join-Path $DestinationPath "JetBrainsMonoNerdFont-$style.ttf"), "font $style")
        }
    }
    function Get-ItemPropertyValue { param($LiteralPath, $Name, $ErrorAction) return $null }
    function New-Item { param($Path, [switch]$Force) Assert ($Path -like 'HKCU:*') 'unexpected registry path' }
    function New-ItemProperty { param($LiteralPath, $Name, $Value, $PropertyType, [switch]$Force) }
    Install-WindowsDesktop $source
    Install-WindowsDesktop $source
    Assert ($script:packageCalls -eq 10) 'full installation did not process packages'
    [IO.File]::WriteAllText($target, 'conflict again')
    $before = $script:packageCalls
    Throws { Install-WindowsDesktop $source } 'Dateikonflikt'
    Assert ($script:packageCalls -eq $before) 'packages ran before conflict preflight'
    # Missing dependencies are rejected before distro/package calls.
    ${function:Assert-WindowsPrerequisites} = $realPrerequisites
    function Test-Windows11 { return $true }
    $script:missing = 'winget.exe'
    function Get-Command { param($Name, $ErrorAction) if ($Name -ne $script:missing) { return $Name } }
    Throws { Assert-WindowsPrerequisites } 'winget.exe'
    $script:missing = 'wsl.exe'
    Throws { Assert-WindowsPrerequisites } 'wsl.exe'
    # External errors are fatal and carry the exit code.
    Remove-Item Function:Get-Command
    ${function:Invoke-Native} = $realNative
    $hostExe = (Get-Process -Id $PID).Path
    Throws { Invoke-Native $hostExe @('-NoProfile', '-Command', 'exit 7') } 'Exit 7'
    Invoke-Native $hostExe @('-NoProfile', '-Command', 'exit 7') @(0, 7)
    Write-Host 'PASS: installer behavior tests'
} finally {
    foreach ($name in $previous.Keys) { [Environment]::SetEnvironmentVariable($name, $previous[$name]) }
    if (Test-Path $temporary) { Remove-Item -LiteralPath $temporary -Recurse -Force }
}
