# Functions are kept separate so tests can replace Windows boundaries without installing anything.
function Invoke-NativeResult {
    param([string]$Program, [string[]]$Arguments)
    # Windows PowerShell 5.1 wraps native stderr in ErrorRecords. Judge success by exit code.
    $resolved = Get-Command $Program -CommandType Application -ErrorAction Stop
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $PSNativeCommandUseErrorActionPreference = $false
        $output = & $resolved.Source @Arguments 2>&1
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    return [pscustomobject]@{ Code = $code; Output = @($output) }
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

function Test-Windows11 {
    return ([Environment]::OSVersion.Platform -eq 'Win32NT' -and [Environment]::OSVersion.Version.Build -ge 22000)
}
function Assert-WindowsPrerequisites {
    if (-not (Test-Windows11)) {
        throw 'Windows 11 ist erforderlich. Aus WSL bitte windows/install.sh verwenden.'
    }
    foreach ($command in 'winget.exe', 'wsl.exe') {
        if (-not (Get-Command $command -ErrorAction SilentlyContinue)) { throw "Voraussetzung fehlt: $command" }
    }
    foreach ($variable in 'USERPROFILE', 'APPDATA', 'LOCALAPPDATA') {
        if (-not [Environment]::GetEnvironmentVariable($variable)) { throw "Umgebungsvariable fehlt: $variable" }
    }
}

function Select-WslDistro {
    param([string]$Requested)
    $names = @((Invoke-Native 'wsl.exe' @('--list', '--quiet')) -join "`n" -split "`n" |
        ForEach-Object { ($_ -replace "`0", '').Trim() } | Where-Object { $_ })
    if ($Requested) {
        if ($Requested -notin $names) { throw "WSL-Distribution nicht gefunden: $Requested" }
        $selected = $names | Where-Object { $_ -eq $Requested } | Select-Object -First 1
    } else {
        $candidates = @($names | Where-Object { $_ -match '(?i)fedora' })
        if ($candidates.Count -ne 1) { throw "Fedora nicht eindeutig erkannt ($($candidates -join ', ')). -Distro <Name> angeben." }
        $selected = $candidates[0]
    }
    $verboseList = (Invoke-Native 'wsl.exe' @('--list', '--verbose')) -join "`n" -replace "`0", ''
    if ($verboseList -notmatch ('(?m)^\s*\*?\s*' + [regex]::Escape($selected) + '\s+.+\s+2\s*$')) {
        throw "Die Distribution '$selected' muss WSL2 verwenden."
    }
    return $selected
}

function New-TextEntry {
    param([string]$Path, [string]$Text)
    return [pscustomobject]@{ Path = $Path; Bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text) }
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
            if ([Convert]::ToBase64String($existing) -eq [Convert]::ToBase64String($entry.Bytes)) { $action = 'Skip' }
            elseif ($Backup) { $action = 'Replace' }
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
    $desired = @{ Hotkey = 'Alt + Space'; HideOnStartup = $true }
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

function Get-ConfigEntries {
    param([string]$SourceRoot, [string]$SelectedDistro, [switch]$NoAutostart)
    $repo = Split-Path -Parent $SourceRoot
    $wezterm = Join-Path $env:USERPROFILE '.config/wezterm'
    $zed = Join-Path $env:APPDATA 'Zed'
    $glaze = Join-Path $env:USERPROFILE '.glzr/glazewm'
    $zebar = Join-Path $env:USERPROFILE '.glzr/zebar'
    # JSON quoted strings are also Lua strings for WSL distro names, except Unicode escapes.
    $luaName = $SelectedDistro.Replace('\', '\\').Replace('"', '\"').Replace("`r", '\r').Replace("`n", '\n')
    New-TextEntry (Join-Path $wezterm 'distro.lua') "return `"$luaName`"`n"
    New-CopyEntry (Join-Path $wezterm 'base.lua') (Join-Path $repo 'wezterm/.config/wezterm/wezterm.lua')
    New-CopyEntry (Join-Path $wezterm 'wezterm.lua') (Join-Path $SourceRoot 'wezterm/wezterm.lua')
    # WezTerm prefers this file to .config/wezterm; treat it as part of the conflict plan.
    New-TextEntry (Join-Path $env:USERPROFILE '.wezterm.lua') "return dofile(require('wezterm').home_dir .. '/.config/wezterm/wezterm.lua')`n"
    $settings = [IO.File]::ReadAllText((Join-Path $repo 'zed/.config/zed/settings.json'))
    $needle = '"shell": { "program": "zsh" }'
    if (-not $settings.Contains($needle)) { throw 'Zed-Basiskonfiguration geaendert: Terminal-Anpassung pruefen.' }
    $settings = $settings.Replace($needle, '"shell": { "program": "pwsh.exe", "args": ["-NoLogo"] }')
    New-TextEntry (Join-Path $zed 'settings.json') $settings
    New-CopyEntry (Join-Path $zed 'keymap.json') (Join-Path $repo 'zed/.config/zed/keymap.json')
    $tasks = @(Get-Content -LiteralPath (Join-Path $repo 'zed/.config/zed/tasks.json') -Raw | ConvertFrom-Json)
    foreach ($task in $tasks) { $task.PSObject.Properties.Remove('shell') }
    New-TextEntry (Join-Path $zed 'tasks.json') (ConvertTo-Json -InputObject $tasks -Depth 30)
    foreach ($name in 'config.yaml', 'start-zebar.ps1', 'start-glazewm.ps1') {
        New-CopyEntry (Join-Path $glaze $name) (Join-Path $SourceRoot "glazewm/$name")
    }
    New-CopyEntry (Join-Path $zebar 'settings.json') (Join-Path $SourceRoot 'zebar/settings.json')
    foreach ($name in 'zpack.json', 'index.html', 'style.css', 'bar.mjs') {
        New-CopyEntry (Join-Path $zebar "dotfiles/$name") (Join-Path $SourceRoot "zebar/$name")
    }
    Get-FlowConfigEntry -NoAutostart:$NoAutostart
    if (-not $NoAutostart) {
        $startup = Join-Path $env:APPDATA 'Microsoft/Windows/Start Menu/Programs/Startup/Dotfiles-GlazeWM.vbs'
        $launcher = Join-Path $glaze 'start-glazewm.ps1'
        $command = 'powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "' + $launcher + '"'
        New-TextEntry $startup ('CreateObject("WScript.Shell").Run "' + $command.Replace('"', '""') + '", 0, False' + "`r`n")
    }
}

function Install-WindowsDesktop {
    param([string]$SourceRoot, [switch]$DryRun, [switch]$Backup, [string]$Distro, [switch]$NoAutostart)
    Assert-WindowsPrerequisites
    $selected = Select-WslDistro $Distro
    Write-Host "WSL2: $selected"
    $entries = @(Get-ConfigEntries $SourceRoot $selected -NoAutostart:$NoAutostart)
    $plan = @(Get-FilePlan $entries -Backup:$Backup)
    $packages = @('wez.wezterm', 'ZedIndustries.Zed', 'glzr-io.glazewm', 'glzr-io.zebar', 'Microsoft.PowerShell', 'Flow-Launcher.Flow-Launcher')
    if ($DryRun) {
        Write-FilePlan $plan -DryRun
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
        if (@($flowPlan | Where-Object Action -ne 'Skip').Count -and
            (Get-Process -Name 'Flow.Launcher' -ErrorAction SilentlyContinue)) {
            throw 'Flow Launcher vor der Aktualisierung ueber das Tray-Menue beenden und erneut ausfuehren.'
        }
        Write-FilePlan $flowPlan
        $plan = @($plan | Where-Object Path -ne $flowPath)
        # Every destination has now been checked before packages/configs/registry are changed.
        foreach ($package in $packages) {
            Install-WingetPackage $package
        }
        Write-FontRegistryPlan $registryPlan $fontRegistry (Join-Path $env:LOCALAPPDATA 'Microsoft/Windows/Fonts')
        Write-FilePlan $plan
        Write-FilePlan $fontPlan
        Write-Host 'Flow Launcher einmal im Startmenue starten; danach Alt+Leertaste. Autostart wird beim Flow-Start uebernommen.'
        Write-Host 'Fertig. Ab-/Anmelden aktiviert Fonts, neuen PATH und (falls eingerichtet) GlazeWM.'
    } finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
    }
}
