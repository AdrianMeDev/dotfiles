# Functions are kept separate so tests can replace Windows boundaries without installing anything.
function Invoke-NativeResult {
    param([string]$Program, [string[]]$Arguments)

    # Mehrere Fundstellen sind möglich, z. B. System32 und WindowsApps.
    # Es wird nur der erste Treffer gemäß PATH-Reihenfolge verwendet.
    $resolved = Get-Command $Program `
        -CommandType Application `
        -ErrorAction Stop |
        Select-Object -First 1

    $previousPreference = $ErrorActionPreference

    try {
        $ErrorActionPreference = 'Continue'
        $PSNativeCommandUseErrorActionPreference = $false
        $output = & $resolved.Source @Arguments 2>&1
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    return [pscustomobject]@{
        Code   = $code
        Output = @($output)
    }
}
function Invoke-Native {
    param([string]$Program, [string[]]$Arguments, [int[]]$SuccessCodes = @(0))
    $result = Invoke-NativeResult $Program $Arguments
    $code = $result.Code
    $output = $result.Output
    if ($code -notin $SuccessCodes) { throw "$Program (Exit $code): $($output -join "`n")" }
    return $output
}

# HRESULTs from microsoft/winget-cli AppInstallerErrors.h (signed Int32).
function Test-WingetPackage {
    param([string]$Package)
    $result = Invoke-NativeResult 'winget.exe' @('list', '--id', $Package, '--exact', '--source', 'winget', '--accept-source-agreements', '--disable-interactivity')
    if ($result.Code -eq 0) { return $true }
    if ($result.Code -eq -1978335212) { return $false } # NO_APPLICATIONS_FOUND
    throw "Winget $Package Bestand (Exit $($result.Code)): $($result.Output -join "`n")"
}
function Install-WingetPackage {
    param([string]$Package)
    if (Test-WingetPackage $Package) { Write-Host "Skip: $Package"; return }
    $result = Invoke-NativeResult 'winget.exe' @('install', '--exact', '--id', $Package, '--source', 'winget', '--no-upgrade', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
    if ($result.Code -eq 0) { $result.Output | Out-Host; return }
    # UPDATE_NOT_APPLICABLE, PACKAGE_ALREADY_INSTALLED: only accept confirmed inventory.
    if ($result.Code -in @(-1978335189, -1978335135)) {
        try {
            if (Test-WingetPackage $Package) { Write-Host "Skip: $Package (Bestand bestaetigt)"; return }
        } catch {
            throw "Winget $Package Installation (Exit $($result.Code)): $($result.Output -join "`n"); Nachpruefung: $_"
        }
    }
    throw "Winget $Package Installation (Exit $($result.Code)): $($result.Output -join "`n")"
}

function Read-FontRegistryValue {
    param([string]$SubKey, [string]$Name)
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($SubKey, $false)
    try {
        if ($null -eq $key -or $Name -notin $key.GetValueNames()) { return $null }
        return [pscustomobject]@{
            Value = $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            Kind = $key.GetValueKind($Name)
        }
    } finally { if ($null -ne $key) { $key.Dispose() } }
}
function Get-FontRegistryPlan {
    param([object[]]$Entries, [string]$SubKey, [switch]$Backup)
    foreach ($entry in $Entries) {
        if (-not $entry.PSObject.Properties['RegistryName']) { throw "Registry-Name fehlt für Font: $($entry.Path)" }
        $name = $entry.RegistryName
        $old = Read-FontRegistryValue $SubKey $name
        $action = 'Create'
        if ($null -ne $old) {
            if ($old.Kind -eq [Microsoft.Win32.RegistryValueKind]::String -and $old.Value -ceq $entry.Path) { $action = 'Skip' }
            elseif ($Backup) { $action = 'Replace' }
            else { throw "Font-Registry-Konflikt: $name. -Backup verwenden." }
        }
        [pscustomobject]@{ Name = $name; Value = $entry.Path; Action = $action }
    }
}
function Write-FontRegistryPlan {
    param([object[]]$Plan, [string]$SubKey, [string]$BackupDirectory)
    if (@($Plan | Where-Object Action -eq 'Replace').Count) {
        [IO.Directory]::CreateDirectory($BackupDirectory) | Out-Null
        $saved = Join-Path $BackupDirectory "Fonts.backup-$([guid]::NewGuid().ToString('N')).reg"
        Invoke-Native 'reg.exe' @('export', "HKCU\$SubKey", $saved) | Out-Host
        if (-not (Test-Path -LiteralPath $saved -PathType Leaf)) { throw "Registry-Backup fehlt: $saved" }
        Write-Host "Registry-Backup: $saved"
    }
    if (-not @($Plan | Where-Object Action -ne 'Skip').Count) { return }
    # CreateSubKey opens an existing key without replacing it or its other values.
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($SubKey)
    try {
        foreach ($entry in $Plan) {
            if ($entry.Action -ne 'Skip') { $key.SetValue($entry.Name, $entry.Value, [Microsoft.Win32.RegistryValueKind]::String) }
        }
    } finally { if ($null -ne $key) { $key.Dispose() } }
}

# Windows dark mode for apps and system UI (HKCU, no admin). Reuses the generic HKCU reader above.
function Get-DarkModeSubKey { return 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' }
function Get-DarkModePlan {
    param([string]$SubKey = (Get-DarkModeSubKey))
    foreach ($name in 'AppsUseLightTheme', 'SystemUsesLightTheme') {
        $old = Read-FontRegistryValue $SubKey $name
        $same = $null -ne $old -and $old.Kind -eq [Microsoft.Win32.RegistryValueKind]::DWord -and $old.Value -eq 0
        $action = if ($same) { 'Skip' } elseif ($null -eq $old) { 'Create' } else { 'Replace' }
        [pscustomobject]@{ Name = $name; Value = 0; Action = $action }
    }
}
function Write-DarkModePlan {
    param([object[]]$Plan, [string]$SubKey, [string]$BackupDirectory)
    foreach ($entry in $Plan) { Write-Host "$($entry.Action): HKCU\$SubKey\$($entry.Name) = $($entry.Value)" }
    if (-not @($Plan | Where-Object Action -ne 'Skip').Count) { return }
    if (@($Plan | Where-Object Action -eq 'Replace').Count) {
        [IO.Directory]::CreateDirectory($BackupDirectory) | Out-Null
        $saved = Join-Path $BackupDirectory "Personalize.backup-$([guid]::NewGuid().ToString('N')).reg"
        Invoke-Native 'reg.exe' @('export', "HKCU\$SubKey", $saved) | Out-Host
        if (-not (Test-Path -LiteralPath $saved -PathType Leaf)) { throw "Registry-Backup fehlt: $saved" }
        Write-Host "Registry-Backup: $saved"
    }
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($SubKey)
    try {
        foreach ($entry in $Plan) {
            if ($entry.Action -ne 'Skip') { $key.SetValue($entry.Name, [int]$entry.Value, [Microsoft.Win32.RegistryValueKind]::DWord) }
        }
    } finally { if ($null -ne $key) { $key.Dispose() } }
}

function Test-Windows11 {
    return ([Environment]::OSVersion.Platform -eq 'Win32NT' -and [Environment]::OSVersion.Version.Build -ge 22000)
}
function Assert-WindowsPrerequisites {
    if (-not (Test-Windows11)) {
        throw 'Windows 11 ist erforderlich. Aus WSL bitte windows/install.sh verwenden.'
    }
    if (-not (Get-Command 'winget.exe' -ErrorAction SilentlyContinue)) { throw 'Voraussetzung fehlt: winget.exe' }
    foreach ($variable in 'USERPROFILE', 'APPDATA', 'LOCALAPPDATA') {
        if (-not [Environment]::GetEnvironmentVariable($variable)) { throw "Umgebungsvariable fehlt: $variable" }
    }
}

function Select-WslDistro {
    param([string]$Requested)
    if (-not (Get-Command 'wsl.exe' -ErrorAction SilentlyContinue)) {
        if ($Requested) { throw "WSL-Distribution nicht gefunden: $Requested (wsl.exe fehlt)" }
        return $null
    }
    $rawList = $null
    try {
        $rawList = Invoke-Native 'wsl.exe' @('--list', '--quiet')
    } catch {
        if ($Requested) { throw "WSL-Distribution nicht gefunden: $Requested ($_)" }
        return $null
    }
    $names = @(($rawList -join "`n") -split "`n" |
        ForEach-Object { ($_ -replace "`0", '').Trim() } | Where-Object { $_ })
    if ($Requested) {
        if ($Requested -notin $names) { throw "WSL-Distribution nicht gefunden: $Requested" }
        $selected = $names | Where-Object { $_ -eq $Requested } | Select-Object -First 1
    } else {
        if ($names.Count -eq 0) { return $null }
        $exact = @($names | Where-Object { $_ -ieq 'archlinux' })
        if ($exact.Count -eq 1) {
            $selected = $exact[0]
        } else {
            $candidates = @($names | Where-Object { $_ -match '(?i)arch' })
            if ($candidates.Count -eq 0) { return $null }
            if ($candidates.Count -gt 1) { throw "Arch nicht eindeutig erkannt ($($candidates -join ', ')). -Distro <Name> angeben." }
            $selected = $candidates[0]
        }
    }
    $verboseList = (Invoke-Native 'wsl.exe' @('--list', '--verbose')) -join "`n" -replace "`0", ''
    if ($verboseList -notmatch ('(?m)^\s*\*?\s*' + [regex]::Escape($selected) + '\s+.+\s+2\s*$')) {
        throw "Die Distribution '$selected' muss WSL2 verwenden."
    }
    return $selected
}

# Streams straight to the console so interactive prompts (git identity) stay visible.
function Invoke-NativeLive {
    param([string]$Program, [string[]]$Arguments)
    $resolved = Get-Command $Program -CommandType Application -ErrorAction Stop | Select-Object -First 1
    & $resolved.Source @Arguments | Out-Host
    return $LASTEXITCODE
}

function Get-WslUserName {
    param([string]$Requested)
    $raw = if ($Requested) { $Requested } else { $env:USERNAME }
    $name = ("$raw".ToLowerInvariant() -replace '[^a-z0-9_-]', '_')
    if ($name -notmatch '^[a-z_]') { $name = "_$name" }
    if ($name.Length -gt 32) { $name = $name.Substring(0, 32) }
    if ($name -eq 'root') { throw 'WSL-Benutzer darf nicht root sein. -WslUser <Name> angeben.' }
    return $name
}

function Install-WslArch {
    param([string]$Name = 'archlinux')
    $selected = Select-WslDistro
    if ($selected) { return $selected }
    $rerun = 'Bitte Windows neu starten und bootstrap.ps1 erneut ausfuehren.'
    if (-not (Get-Command 'wsl.exe' -ErrorAction SilentlyContinue)) {
        throw "wsl.exe fehlt (WSL-Feature nicht aktiv). $rerun"
    }
    Write-Host "WSL: installiere $Name (wsl.exe --install $Name --no-launch)"
    $result = Invoke-NativeResult 'wsl.exe' @('--install', $Name, '--no-launch')
    $text = ($result.Output -join "`n") -replace "`0", ''
    $text | Out-Host
    if ($result.Code -eq 3010 -or $text -match '(?i)restart|reboot|neustart|neu gestartet') {
        throw "WSL verlangt einen Neustart. $rerun"
    }
    if ($result.Code -ne 0) { throw "wsl.exe --install $Name (Exit $($result.Code)): $text" }
    $selected = try { Select-WslDistro $Name } catch { $null }
    if (-not $selected) { throw "Die Distribution '$Name' ist nach der Installation nicht registriert. $rerun" }
    return $selected
}

function ConvertTo-WslPath {
    param([string]$Distro, [string]$Path)
    $out = Invoke-Native 'wsl.exe' @('-d', $Distro, '-u', 'root', '--', 'wslpath', '-u', $Path.Replace('\', '/'))
    return ((($out -join "`n") -replace "`0", '').Trim())
}

function Invoke-WslBootstrap {
    param([string]$SourceRoot, [string]$Distro, [string]$WslUser, [switch]$Backup)
    $user = Get-WslUserName $WslUser
    $repo = ConvertTo-WslPath $Distro (Split-Path -Parent $SourceRoot)
    $script = ConvertTo-WslPath $Distro (Join-Path $SourceRoot 'wsl-bootstrap.sh')
    $arguments = @('-d', $Distro, '-u', 'root', '--', 'bash', $script, '--user', $user, '--repo', $repo)
    if ($Backup) { $arguments += '--backup' }
    Write-Host "WSL: richte Benutzer '$user' in $Distro ein (wsl-bootstrap.sh)"
    $output = (Invoke-Native 'wsl.exe' $arguments) -join "`n" -replace "`0", ''
    $output | Out-Host
    # The script reports a rewritten /etc/wsl.conf; it only takes effect after the distro restarts.
    if ($output -match '(?m)^geschrieben: \S*/etc/wsl\.conf$') {
        Write-Host "WSL: /etc/wsl.conf geaendert, starte $Distro neu."
        Invoke-Native 'wsl.exe' @('--terminate', $Distro) | Out-Null
    }
    $install = @('-d', $Distro, '-u', $user, '--cd', '~', '--', 'bash', './dotfiles/install.sh')
    if ($Backup) { $install += '--backup' }
    $code = Invoke-NativeLive 'wsl.exe' $install
    if ($code -ne 0) { throw "WSL install.sh (Exit $code)" }
}

function New-TextEntry {
    param([string]$Path, [string]$Text, [switch]$Generated)
    return [pscustomobject]@{ Path = $Path; Bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text); Generated = [bool]$Generated }
}
function New-CopyEntry {
    param([string]$Path, [string]$Source)
    return [pscustomobject]@{ Path = $Path; Bytes = [IO.File]::ReadAllBytes($Source) }
}
function Get-FilePlan {
    param([object[]]$Entries, [switch]$Backup)
    foreach ($entry in $Entries) {
        # Reject directory collisions and links (including linked ancestor directories).
        $ancestor = $entry.Path
        while ($ancestor) {
            $item = Get-Item -LiteralPath $ancestor -Force -ErrorAction SilentlyContinue
            if ($null -ne $item) {
                if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Verknuepfung im Zielpfad: $ancestor" }
                if ($ancestor -ne $entry.Path -and -not $item.PSIsContainer) { throw "Zielverzeichnis ist eine Datei: $ancestor" }
            }
            $ancestor = Split-Path -Parent $ancestor
        }
        $action = 'Create'
        if (Test-Path -LiteralPath $entry.Path) {
            if (-not (Test-Path -LiteralPath $entry.Path -PathType Leaf)) { throw "Zieldatei ist ein Verzeichnis: $($entry.Path)" }
            $existing = [IO.File]::ReadAllBytes($entry.Path)
            if ([Convert]::ToBase64String($existing) -ceq [Convert]::ToBase64String($entry.Bytes)) { $action = 'Skip' }
            # Only New-TextEntry sets Generated; StrictMode throws on a missing property.
            elseif ($Backup -or ($entry.PSObject.Properties['Generated'] -and $entry.Generated)) { $action = 'Replace' }
            else { throw "Dateikonflikt: $($entry.Path). Mit -Backup sichern und ersetzen." }
        }
        [pscustomobject]@{ Path = $entry.Path; Bytes = $entry.Bytes; Action = $action }
    }
}
function Write-FilePlan {
    param([object[]]$Plan, [switch]$DryRun)
    foreach ($entry in $Plan) {
        Write-Host "$($entry.Action): $($entry.Path)"
        if ($DryRun -or $entry.Action -eq 'Skip') { continue }
        [IO.Directory]::CreateDirectory((Split-Path -Parent $entry.Path)) | Out-Null
        if ($entry.Action -eq 'Replace') {
            $saved = "$($entry.Path).backup-$([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfff'))-$([guid]::NewGuid().ToString('N'))"
            [IO.File]::Copy($entry.Path, $saved, $false)
            Write-Host "Backup: $saved"
        }
        [IO.File]::WriteAllBytes($entry.Path, $entry.Bytes)
    }
}
# Flow settings: Flow-Launcher/Flow.Launcher, Flow.Launcher.Infrastructure/UserSettings/Settings.cs
function Get-FlowConfigEntry {
    param([switch]$NoAutostart)
    $path = Join-Path $env:APPDATA 'FlowLauncher/Settings/Settings.json'
    $settings = [pscustomobject]@{}
    $exists = Test-Path -LiteralPath $path -PathType Leaf
    if ($exists) {
        $settings = Get-Content -LiteralPath $path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($null -eq $settings -or $settings -isnot [pscustomobject]) { throw "Ungueltige Flow-Einstellungen: $path" }
    }
    $desired = @{ Hotkey = 'Alt + Space'; HideOnStartup = $true; Theme = 'TokyoNight' }
    if (-not $NoAutostart) { $desired.StartFlowLauncherOnSystemStartup = $true }
    $changed = -not $exists
    foreach ($name in $desired.Keys) {
        $property = $settings.PSObject.Properties[$name]
        if ($null -eq $property -or $property.Value -cne $desired[$name]) {
            $settings | Add-Member -NotePropertyName $name -NotePropertyValue $desired[$name] -Force
            $changed = $true
        }
    }
    if ($changed) { New-TextEntry $path (ConvertTo-Json -InputObject $settings -Depth 100) }
    else { New-CopyEntry $path $path }
}

# Mirrors scripts/agents.py render(): Claude-only frontmatter goes after line 1 of each top-level SKILL.md.
function Get-AgentConfigEntries {
    param([string]$Repo, [ValidateSet('all', 'pi', 'claude')] [string]$Only = 'all')
    $src = Join-Path $Repo 'agent-config'
    $roots = @{
        claude = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
        pi     = if ($env:PI_CODING_AGENT_DIR) { $env:PI_CODING_AGENT_DIR } else { Join-Path $env:USERPROFILE '.pi/agent' }
    }
    $tools = if ($Only -eq 'all') { @('claude', 'pi') } else { @($Only) }
    $files = {
        param([string]$Base)
        foreach ($file in Get-ChildItem -LiteralPath $Base -Recurse -File | Sort-Object FullName) {
            [pscustomobject]@{ Rel = $file.FullName.Substring($Base.TrimEnd('\', '/').Length + 1).Replace('\', '/'); Full = $file.FullName }
        }
    }
    foreach ($tool in $tools) {
        foreach ($f in & $files (Join-Path $src $tool)) {
            New-CopyEntry (Join-Path $roots[$tool] $f.Rel) $f.Full
        }
        foreach ($f in & $files (Join-Path $src 'skills')) {
            if ($f.Rel.EndsWith('/claude-frontmatter.txt') -or $f.Rel -eq 'claude-frontmatter.txt') { continue }
            $target = Join-Path $roots[$tool] "skills/$($f.Rel)"
            $extra = Join-Path (Split-Path -Parent $f.Full) 'claude-frontmatter.txt'
            if ($tool -ne 'claude' -or $f.Rel -notmatch '^[^/]+/SKILL\.md$' -or -not (Test-Path -LiteralPath $extra -PathType Leaf)) {
                New-CopyEntry $target $f.Full
                continue
            }
            $bytes = [IO.File]::ReadAllBytes($f.Full)
            $newline = [Array]::IndexOf($bytes, [byte]10)
            $first = if ($newline -ge 0) { [Text.Encoding]::ASCII.GetString($bytes, 0, $newline).TrimEnd("`r") } else { '' }
            if ($first -ne '---') { throw "skills/$($f.Rel): erste Zeile muss --- sein, um Claude-Frontmatter einzufuegen." }
            $front = [IO.File]::ReadAllBytes($extra)
            if ($front.Length -eq 0 -or $front[-1] -ne 10) { $front += [byte]10 }
            $merged = [byte[]]($bytes[0..$newline] + $front + $(if ($newline + 1 -lt $bytes.Length) { $bytes[($newline + 1)..($bytes.Length - 1)] } else { @() }))
            [pscustomobject]@{ Path = $target; Bytes = $merged }
        }
    }
}

# Mirrored networking lets WSL2 reach Windows services (Ollama) on localhost. Other sections/keys stay untouched.
function Get-WslConfigEntry {
    $path = Join-Path $env:USERPROFILE '.wslconfig'
    $text = if (Test-Path -LiteralPath $path -PathType Leaf) { [IO.File]::ReadAllText($path) } else { '' }
    $eol = if ($text.Contains("`r`n") -or -not $text) { "`r`n" } else { "`n" }
    $lines = [Collections.Generic.List[string]]::new()
    if ($text) { $lines.AddRange([string[]]($text -split '\r?\n')) }
    if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq '') { $lines.RemoveAt($lines.Count - 1) }
    $header = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -ieq '[wsl2]') { $header = $i; break }
    }
    if ($header -lt 0) {
        if ($lines.Count -gt 0 -and $lines[$lines.Count - 1].Trim()) { $lines.Add('') }
        $lines.Add('[wsl2]')
        $lines.Add('networkingMode=mirrored')
    } else {
        $key = -1
        for ($i = $header + 1; $i -lt $lines.Count -and $lines[$i].TrimStart() -notmatch '^\['; $i++) {
            if ($lines[$i] -match '^\s*networkingMode\s*=') { $key = $i; break }
        }
        if ($key -lt 0) { $lines.Insert($header + 1, 'networkingMode=mirrored') }
        elseif ($lines[$key] -notmatch '^\s*networkingMode\s*=\s*mirrored\s*$') { $lines[$key] = 'networkingMode=mirrored' }
    }
    New-TextEntry $path (($lines -join $eol) + $eol)
}

function Get-ConfigEntries {
    param([string]$SourceRoot, [string]$SelectedDistro, [switch]$NoAutostart, [switch]$NoWsl)
    $repo = Split-Path -Parent $SourceRoot
    $wezterm = Join-Path $env:USERPROFILE '.config/wezterm'
    $zed = Join-Path $env:APPDATA 'Zed'
    $glaze = Join-Path $env:USERPROFILE '.glzr/glazewm'
    $zebar = Join-Path $env:USERPROFILE '.glzr/zebar'
    # JSON quoted strings are also Lua strings for WSL distro names, except Unicode escapes.
    if ($SelectedDistro) {
        $luaName = $SelectedDistro.Replace('\', '\\').Replace('"', '\"').Replace("`r", '\r').Replace("`n", '\n')
        New-TextEntry (Join-Path $wezterm 'distro.lua') "return `"$luaName`"`n" -Generated
    } else {
        New-TextEntry (Join-Path $wezterm 'distro.lua') "return nil`n" -Generated
    }
    New-CopyEntry (Join-Path $wezterm 'base.lua') (Join-Path $repo 'wezterm/.config/wezterm/wezterm.lua')
    New-CopyEntry (Join-Path $wezterm 'wezterm.lua') (Join-Path $SourceRoot 'wezterm/wezterm.lua')
    # WezTerm prefers this file to .config/wezterm; treat it as part of the conflict plan.
    New-TextEntry (Join-Path $env:USERPROFILE '.wezterm.lua') "return dofile(require('wezterm').home_dir .. '/.config/wezterm/wezterm.lua')`n"
    $zedSource = Join-Path $repo 'zed-config/.config/zed'
    $settings = [IO.File]::ReadAllText((Join-Path $zedSource 'settings.json'))
    $needle = '"shell": { "program": "zsh" }'
    if (-not $settings.Contains($needle)) { throw 'Zed-Basiskonfiguration geaendert: Terminal-Anpassung pruefen.' }
    $settings = $settings.Replace($needle, '"shell": { "program": "pwsh.exe", "args": ["-NoLogo"] }')
    # Pre-register the WSL distro for Zed Remote-WSL; the shared source file stays untouched.
    if ($SelectedDistro -and -not $NoWsl) {
        $name = (ConvertTo-Json -InputObject $SelectedDistro -Compress).Replace('$', '$$')
        $opening = [regex]::new('(?m)^\{[ \t]*\r?$')
        if (-not $opening.IsMatch($settings)) { throw 'Zed-Basiskonfiguration geaendert: wsl_connections nicht einfuegbar.' }
        $settings = $opening.Replace($settings, "{`n  // Remote-WSL (generated by the Windows installer)`n  `"wsl_connections`": [{ `"distro_name`": $name }],", 1)
    }
    New-TextEntry (Join-Path $zed 'settings.json') $settings
    foreach ($name in 'keymap.json', 'tasks.json', 'debug.json') {
        New-CopyEntry (Join-Path $zed $name) (Join-Path $zedSource $name)
    }
    foreach ($name in 'config.yaml', 'start-zebar.ps1', 'start-glazewm.ps1') {
        New-CopyEntry (Join-Path $glaze $name) (Join-Path $SourceRoot "glazewm/$name")
    }
    New-CopyEntry (Join-Path $zebar 'settings.json') (Join-Path $SourceRoot 'zebar/settings.json')
    foreach ($name in 'zpack.json', 'index.html', 'style.css', 'bar.mjs') {
        New-CopyEntry (Join-Path $zebar "dotfiles/$name") (Join-Path $SourceRoot "zebar/$name")
    }
    New-CopyEntry (Join-Path $env:APPDATA 'FlowLauncher/Themes/TokyoNight.xaml') (Join-Path $SourceRoot 'flow/TokyoNight.xaml')
    if (-not $NoAutostart) {
        $startup = Join-Path $env:APPDATA 'Microsoft/Windows/Start Menu/Programs/Startup/Dotfiles-GlazeWM.vbs'
        $launcher = Join-Path $glaze 'start-glazewm.ps1'
        $command = 'powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "' + $launcher + '"'
        New-TextEntry $startup ('CreateObject("WScript.Shell").Run "' + $command.Replace('"', '""') + '", 0, False' + "`r`n")
    }
    Get-AgentConfigEntries $repo
    Get-FlowConfigEntry -NoAutostart:$NoAutostart
    if (-not $NoWsl) { Get-WslConfigEntry }
}

function Get-WingetPackages {
    param([string]$Root, [string[]]$Extra = @(), [switch]$All)
    $rows = @(Get-Content -LiteralPath (Join-Path $Root 'manifests/winget.tsv') |
        Where-Object { $_.Trim() -and -not $_.StartsWith('#') } |
        ForEach-Object {
            $cells = $_ -split "`t"
            if ($cells.Count -ne 3) { throw "winget.tsv: 3 Spalten erwartet: $_" }
            [pscustomobject]@{ Group = $cells[1]; Id = $cells[2] }
        })
    $known = @($rows.Group | Where-Object { $_ -ne 'base' } | Select-Object -Unique)
    foreach ($name in $Extra) {
        if ($name -notin $known) { throw "Unbekanntes Extra: $name (verfuegbar: $($known -join ', '))" }
    }
    return @($rows | Where-Object { $All -or $_.Group -eq 'base' -or $_.Group -in $Extra } | ForEach-Object Id)
}

function Assert-FlowConfigWritable {
    param([object[]]$Plan)
    if (@($Plan | Where-Object Action -ne 'Skip').Count -and
        (Get-Process -Name 'Flow.Launcher' -ErrorAction SilentlyContinue)) {
        throw 'Flow Launcher vor der Aktualisierung ueber das Tray-Menue beenden und erneut ausfuehren.'
    }
}

function Get-VialDirectory { return Join-Path $env:LOCALAPPDATA 'Vial' }

# Local state of the user-scoped Vial install: installed tag (from .version) and whether a foreign directory must be backed up.
function Get-VialState {
    param([switch]$Backup)
    $dir = Get-VialDirectory
    $state = [pscustomobject]@{ Directory = $dir; Version = $null; Replace = $false }
    $item = Get-Item -LiteralPath $dir -Force -ErrorAction SilentlyContinue
    if ($null -eq $item) { return $state }
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Verknuepfung im Zielpfad: $dir" }
    if (-not $item.PSIsContainer) { throw "Zieldatei ist kein Verzeichnis: $dir" }
    $marker = Join-Path $dir '.version'
    if (Test-Path -LiteralPath $marker -PathType Leaf) {
        $state.Version = ([IO.File]::ReadAllText($marker)).Trim()
    } elseif (@(Get-ChildItem -LiteralPath $dir -Force).Count) {
        if (-not $Backup) { throw "Dateikonflikt: $dir. Mit -Backup sichern und ersetzen." }
        $state.Replace = $true
    }
    return $state
}

# Latest stable portable release of vial-kb/vial-gui; Sha256 is $null when GitHub supplies no digest.
function Get-VialReleaseAsset {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/vial-kb/vial-gui/releases/latest'
    if ($release.prerelease -or $release.draft) { throw 'Vial: kein stabiles Release.' }
    $assets = @($release.assets | Where-Object { $_.name -match '^Vial-v.*-portable\.zip$' })
    if ($assets.Count -ne 1) { throw 'Vial: kein eindeutiges Portable-Release gefunden.' }
    $sha = $null
    if ($assets[0].digest -match '^sha256:([0-9a-fA-F]{64})$') { $sha = $Matches[1] }
    return [pscustomobject]@{ Tag = [string]$release.tag_name; Name = $assets[0].name; Url = $assets[0].browser_download_url; Sha256 = $sha }
}

function Test-VialNewer {
    param([string]$Installed, [string]$Latest)
    $old = $null; $new = $null
    if ([version]::TryParse($Installed.TrimStart('v'), [ref]$old) -and [version]::TryParse($Latest.TrimStart('v'), [ref]$new)) { return $new -gt $old }
    return $Latest -ne $Installed
}

function New-VialShortcut {
    param([string]$Target)
    $path = Join-Path $env:APPDATA 'Microsoft/Windows/Start Menu/Programs/Vial.lnk'
    [IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null
    $link = (New-Object -ComObject WScript.Shell).CreateShortcut($path)
    $link.TargetPath = $Target
    $link.WorkingDirectory = Split-Path -Parent $Target
    $link.Save()
}

function Install-VialRelease {
    param([string]$TempDirectory, [switch]$Backup, [switch]$Upgrade)
    $state = Get-VialState -Backup:$Backup
    if ($state.Version -and -not $Upgrade) { Write-Host "Skip: Vial $($state.Version)"; return }
    $release = Get-VialReleaseAsset
    if ($state.Version -and -not (Test-VialNewer $state.Version $release.Tag)) { Write-Host "Skip: Vial $($state.Version)"; return }
    $archive = Join-Path $TempDirectory 'vial.zip'
    Invoke-WebRequest $release.Url -OutFile $archive -UseBasicParsing
    if ($release.Sha256) {
        $actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
        if ($actual -ne $release.Sha256) { throw "Vial SHA-256 stimmt nicht ueberein: erwartet $($release.Sha256), erhalten $actual" }
    }
    $extracted = Join-Path $TempDirectory 'vial'
    Expand-Archive -LiteralPath $archive -DestinationPath $extracted
    # Portable zips may wrap everything in one top-level folder.
    $content = @(Get-ChildItem -LiteralPath $extracted -Force)
    $source = if ($content.Count -eq 1 -and $content[0].PSIsContainer) { $content[0].FullName } else { $extracted }
    if (-not (Get-ChildItem -LiteralPath $source -Filter 'Vial.exe' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1)) {
        throw 'Vial: Vial.exe fehlt im Archiv.'
    }
    $dir = $state.Directory
    if ($state.Replace) {
        $saved = "$dir.backup-$([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfff'))-$([guid]::NewGuid().ToString('N'))"
        Move-Item -LiteralPath $dir -Destination $saved
        Write-Host "Backup: $saved"
    } elseif (Test-Path -LiteralPath $dir) {
        Remove-Item -LiteralPath $dir -Recurse -Force
    }
    [IO.Directory]::CreateDirectory($dir) | Out-Null
    Copy-Item -Path (Join-Path $source '*') -Destination $dir -Recurse -Force
    [IO.File]::WriteAllText((Join-Path $dir '.version'), $release.Tag)
    $exe = Get-ChildItem -LiteralPath $dir -Filter 'Vial.exe' -File -Recurse | Select-Object -First 1
    New-VialShortcut $exe.FullName
    Write-Host "Vial: $($release.Tag) in $dir"
}

function Install-WindowsDesktop {
    param([string]$SourceRoot, [switch]$DryRun, [switch]$Backup, [string]$Distro, [switch]$NoAutostart, [string[]]$Extra = @(), [switch]$NoWsl, [string]$WslUser)
    $packages = Get-WingetPackages (Split-Path -Parent $SourceRoot) $Extra
    Assert-WindowsPrerequisites
    $selected = Select-WslDistro $Distro
    # Without a distro the Arch instance is installed below; plan its name now so distro.lua is final.
    $installWsl = -not $NoWsl -and -not $selected
    $wslName = if ($installWsl) { 'archlinux' } else { $selected }
    if ($NoWsl) { Write-Host 'WSL2: uebersprungen (-NoWsl).' }
    elseif ($installWsl) { Write-Host "WSL2: keine Distribution, $wslName wird installiert." }
    elseif ($selected) { Write-Host "WSL2: $selected" }
    $entries = @(Get-ConfigEntries $SourceRoot $wslName -NoAutostart:$NoAutostart -NoWsl:$NoWsl)
    $plan = @(Get-FilePlan $entries -Backup:$Backup)
    $darkPlan = @(Get-DarkModePlan)
    # Conflict preflight (local only, no network).
    $vial = Get-VialState -Backup:$Backup
    if ($DryRun) {
        Write-FilePlan $plan -DryRun
        Write-Host "Vial: $(if ($vial.Version) { "Skip ($($vial.Version))" } else { 'wird installiert' }) in $($vial.Directory) (neuestes stabiles Release von vial-kb/vial-gui; Download erst ohne -DryRun)"
        if (-not $NoWsl) {
            $user = Get-WslUserName $WslUser
            if ($installWsl) { Write-Host "WSL: wsl.exe --install $wslName --no-launch (falls fehlend)" }
            Write-Host "WSL: wsl-bootstrap.sh als root (Benutzer $user, sudo, /etc/wsl.conf, ~/dotfiles), dann install.sh$(if ($Backup) { ' --backup' })"
        }
        foreach ($entry in $darkPlan) { Write-Host "$($entry.Action): HKCU\$(Get-DarkModeSubKey)\$($entry.Name) = $($entry.Value) (Dark Mode)" }
        foreach ($package in $packages) { Write-Host "Winget (falls fehlend): $package" }
        Write-Host 'Fonts: Ioskeley Mono und Ioskeley Mono Term Nerd Font v2.1.0 (Download und Inhalts-/Registry-Konfliktpruefung erst ohne -DryRun).'
        return
    }
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-' + [guid]::NewGuid().ToString('N'))
    try {
        [IO.Directory]::CreateDirectory($temp) | Out-Null
        $editorArchive = Join-Path $temp 'ioskeley.zip'
        $terminalArchive = Join-Path $temp 'ioskeley-term-nerd.zip'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest 'https://github.com/ahatem/IoskeleyMono/releases/download/v2.1.0/IoskeleyMono.zip' -OutFile $editorArchive -UseBasicParsing
        Invoke-WebRequest 'https://github.com/ahatem/IoskeleyMono/releases/download/v2.1.0/IoskeleyMono-Term-NerdFont.zip' -OutFile $terminalArchive -UseBasicParsing
        $editorSource = Join-Path $temp 'ioskeley/Normal/Hinted'
        $terminalSource = Join-Path $temp 'ioskeley-term/Normal'
        Expand-Archive -LiteralPath $editorArchive -DestinationPath (Join-Path $temp 'ioskeley')
        Expand-Archive -LiteralPath $terminalArchive -DestinationPath (Join-Path $temp 'ioskeley-term')
        $editorFonts = @(Get-ChildItem -LiteralPath $editorSource -Filter '*.ttf' -File)
        $terminalFonts = @(Get-ChildItem -LiteralPath $terminalSource -Filter '*.ttf' -File)
        if ($editorFonts.Count -ne 20 -or $terminalFonts.Count -ne 20) {
            throw 'Font-Archive enthalten nicht jeweils die erwarteten 20 TTF-Dateien.'
        }
        $fontEntries = @()
        $fontRegistry = 'Software\Microsoft\Windows NT\CurrentVersion\Fonts'
        foreach ($source in ($editorFonts + $terminalFonts)) {
            $target = Join-Path $env:LOCALAPPDATA "Microsoft/Windows/Fonts/$($source.Name)"
            $entry = New-CopyEntry $target $source.FullName
            $entry | Add-Member -NotePropertyName RegistryName -NotePropertyValue "$([IO.Path]::GetFileNameWithoutExtension($source.Name)) (TrueType)"
            $fontEntries += $entry
        }
        $registryPlan = @(Get-FontRegistryPlan $fontEntries $fontRegistry -Backup:$Backup)
        $fontPlan = @(Get-FilePlan $fontEntries -Backup:$Backup)
        # Write Flow settings before winget: its installer may launch Flow immediately.
        $flowPath = Join-Path $env:APPDATA 'FlowLauncher/Settings/Settings.json'
        $flowPlan = @($plan | Where-Object Path -eq $flowPath)
        Assert-FlowConfigWritable $flowPlan
        Write-FilePlan $flowPlan
        $plan = @($plan | Where-Object Path -ne $flowPath)
        # Every destination has now been checked before packages/configs/registry are changed.
        foreach ($package in $packages) {
            Install-WingetPackage $package
        }
        Write-FontRegistryPlan $registryPlan $fontRegistry (Join-Path $env:LOCALAPPDATA 'Microsoft/Windows/Fonts')
        Write-DarkModePlan $darkPlan (Get-DarkModeSubKey) (Join-Path $env:LOCALAPPDATA 'dotfiles/backup')
        Write-FilePlan $plan
        Write-FilePlan $fontPlan
        Install-VialRelease $temp -Backup:$Backup
        if (-not $NoWsl) {
            $distroName = if ($installWsl) { Install-WslArch $wslName } else { $selected }
            Invoke-WslBootstrap $SourceRoot $distroName $WslUser -Backup:$Backup
        }
        Write-Host 'Flow Launcher einmal im Startmenue starten; danach Alt+Leertaste. Autostart wird beim Flow-Start uebernommen.'
        Write-Host 'Fertig. Ab-/Anmelden aktiviert Fonts, neuen PATH und (falls eingerichtet) GlazeWM.'
    } finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
    }
}

function Update-WingetPackage {
    param([string]$Package)
    if (-not (Test-WingetPackage $Package)) { Write-Host "Skip: $Package (nicht installiert)"; return }
    # UPDATE_NOT_APPLICABLE also means the installed version is current.
    Invoke-Native 'winget.exe' @('upgrade', '--exact', '--id', $Package, '--source', 'winget', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity') @(0, -1978335189) | Out-Host
}

# Runs the Linux `dot` as the distro's default user (created by wsl-bootstrap.sh).
function Get-WslDotArguments {
    param([string]$Distro, [string]$Verb)
    return @('-d', $Distro, '--cd', '~', '--', 'bash', '-c', "exec `"`$HOME/.local/bin/dot`" $Verb")
}

function Update-WindowsDesktop {
    param([string]$SourceRoot, [switch]$DryRun, [switch]$Backup, [string]$Distro, [switch]$NoAutostart, [switch]$NoWsl)
    $packages = Get-WingetPackages (Split-Path -Parent $SourceRoot) -All
    if ($DryRun) {
        if (-not $NoWsl) {
            $planned = Select-WslDistro $Distro
            if ($planned) { Write-Host "WSL: dot update wuerde in $planned laufen" }
        }
        return $packages
    }
    Assert-WindowsPrerequisites
    $selected = if ($NoWsl) { $null } else { Select-WslDistro $Distro }
    foreach ($package in $packages) { Update-WingetPackage $package }
    if ((Get-VialState -Backup:$Backup).Version) {
        $temp = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-' + [guid]::NewGuid().ToString('N'))
        try {
            [IO.Directory]::CreateDirectory($temp) | Out-Null
            Install-VialRelease $temp -Backup:$Backup -Upgrade
        } finally {
            if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
        }
    } else { Write-Host 'Skip: Vial (nicht installiert)' }
    $plan = @(Get-FilePlan @(Get-ConfigEntries $SourceRoot $selected -NoAutostart:$NoAutostart -NoWsl:$NoWsl) -Backup:$Backup)
    $flowPath = Join-Path $env:APPDATA 'FlowLauncher/Settings/Settings.json'
    Assert-FlowConfigWritable @($plan | Where-Object Path -eq $flowPath)
    Write-FilePlan $plan
    if ($NoWsl) { Write-Host 'WSL2: uebersprungen (-NoWsl).' }
    elseif (-not $selected) { Write-Host 'WSL2: keine Arch-Distribution, uebersprungen.' }
    else {
        Write-Host "WSL: dot update in $selected"
        $code = Invoke-NativeLive 'wsl.exe' (Get-WslDotArguments $selected 'update')
        if ($code -ne 0) { throw "WSL dot update (Exit $code)" }
    }
}

function Get-DoctorReport {
    param([string]$SourceRoot, [string[]]$Extra = @(), [string]$Distro, [switch]$NoAutostart, [switch]$NoWsl)
    $repo = Split-Path -Parent $SourceRoot
    $required = Get-WingetPackages $repo $Extra
    foreach ($package in Get-WingetPackages $repo -All) {
        try {
            $installed = Test-WingetPackage $package
            $status = if ($installed) { 'installiert' } elseif ($package -in $required) { 'fehlt' } else { 'optional, fehlt' }
            [pscustomobject]@{ Problem = -not $installed -and $package -in $required; Message = "Winget $package - $status" }
        } catch { [pscustomobject]@{ Problem = $true; Message = "Winget $package - $_" } }
    }
    try {
        $version = Invoke-Native 'claude' @('--version')
        [pscustomobject]@{ Problem = $false; Message = "Claude: $version" }
    } catch { [pscustomobject]@{ Problem = $true; Message = "Claude: $_" } }

    try {
        $vial = Get-VialState
        if (-not $vial.Version) {
            [pscustomobject]@{ Problem = $true; Message = "Vial: nicht installiert ($($vial.Directory))" }
        } elseif (-not (Get-ChildItem -LiteralPath $vial.Directory -Filter 'Vial.exe' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1)) {
            [pscustomobject]@{ Problem = $true; Message = "Vial: Vial.exe fehlt in $($vial.Directory)" }
        } else {
            [pscustomobject]@{ Problem = $false; Message = "Vial: $($vial.Version)" }
        }
    } catch { [pscustomobject]@{ Problem = $true; Message = "Vial: $_" } }

    try {
        $selected = if ($NoWsl) { $null } else { Select-WslDistro $Distro }
        Get-ConfigEntries $SourceRoot $selected -NoAutostart:$NoAutostart -NoWsl:$NoWsl | ForEach-Object {
            $path = $_.Path
            try {
                $item = Get-FilePlan @($_) -Backup
                if ($item.Action -ne 'Skip') {
                    [pscustomobject]@{ Problem = $true; Message = "$($item.Action): $path" }
                }
            } catch { [pscustomobject]@{ Problem = $true; Message = "${path}: $_" } }
        }
    } catch { [pscustomobject]@{ Problem = $true; Message = "Konfiguration: $_" } }

    if ($NoWsl) {
        [pscustomobject]@{ Problem = $false; Message = 'WSL2: uebersprungen (-NoWsl)' }
    } else {
        try {
            $wsl = Select-WslDistro $Distro
            if (-not $wsl) {
                [pscustomobject]@{ Problem = $true; Message = 'WSL2 Arch: nicht installiert' }
            } else {
                [pscustomobject]@{ Problem = $false; Message = "WSL2 Arch: $wsl (WSL2)" }
                $result = Invoke-NativeResult 'wsl.exe' (Get-WslDotArguments $wsl 'doctor')
                $text = ($result.Output -join "`n") -replace "`0", ''
                [pscustomobject]@{ Problem = $result.Code -ne 0; Message = "WSL dot doctor (Exit $($result.Code)):`n$text".TrimEnd() }
            }
        } catch { [pscustomobject]@{ Problem = $true; Message = "WSL2: $_" } }
    }

    try {
        foreach ($item in Get-DarkModePlan) {
            if ($item.Action -ne 'Skip') {
                [pscustomobject]@{ Problem = $true; Message = "$($item.Action): HKCU\$(Get-DarkModeSubKey)\$($item.Name)" }
            }
        }
        $dir = Join-Path $env:LOCALAPPDATA 'Microsoft/Windows/Fonts'
        $subKey = 'Software\Microsoft\Windows NT\CurrentVersion\Fonts'
        foreach ($family in 'IoskeleyMono', 'IoskeleyMonoTermNerdFontMono') {
            $fonts = @(if (Test-Path -LiteralPath $dir -PathType Container) {
                Get-ChildItem -LiteralPath $dir -Filter "$family-*.ttf" -File
            })
            if ($fonts.Count -ne 20) {
                [pscustomobject]@{ Problem = $true; Message = "Fonts ${family}: $($fonts.Count) von 20 Dateien" }
            }
            foreach ($font in $fonts) {
                $entry = [pscustomobject]@{ Path = $font.FullName; RegistryName = "$($font.BaseName) (TrueType)" }
                $item = Get-FontRegistryPlan @($entry) $subKey -Backup
                if ($item.Action -ne 'Skip') {
                    [pscustomobject]@{ Problem = $true; Message = "$($item.Action): HKCU\$subKey\$($item.Name)" }
                }
            }
        }
    } catch { [pscustomobject]@{ Problem = $true; Message = "Registry: $_" } }
}
