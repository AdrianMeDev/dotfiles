# Functions are kept separate so tests can replace Windows boundaries without installing anything.
function Invoke-Native {
    param([string]$Program, [string[]]$Arguments, [int[]]$SuccessCodes = @(0))
    # Windows PowerShell 5.1 wraps native stderr in ErrorRecords. Judge success by exit code.
    $resolved = Get-Command $Program -CommandType Application -ErrorAction Stop
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $PSNativeCommandUseErrorActionPreference = $false
        $output = & $resolved.Source @Arguments 2>&1
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    if ($code -notin $SuccessCodes) { throw "$Program (Exit $code): $($output -join "`n")" }
    return $output
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
    $needle = '"terminal": { "shell": { "program": "zsh" } }'
    if (-not $settings.Contains($needle)) { throw 'Zed-Basiskonfiguration geaendert: Terminal-Anpassung pruefen.' }
    $settings = $settings.Replace($needle, '"terminal": { "shell": { "program": "pwsh.exe", "args": ["-NoLogo"] } }')
    New-TextEntry (Join-Path $zed 'settings.json') $settings
    New-CopyEntry (Join-Path $zed 'keymap.json') (Join-Path $repo 'zed/.config/zed/keymap.json')
    New-CopyEntry (Join-Path $zed 'themes/Neovim-custom.json') (Join-Path $repo 'zed/.config/zed/themes/Neovim-custom.json')
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
    $packages = @('wez.wezterm', 'ZedIndustries.Zed', 'glzr-io.glazewm', 'glzr-io.zebar', 'Microsoft.PowerShell')
    if ($DryRun) {
        Write-FilePlan $plan -DryRun
        foreach ($package in $packages) { Write-Host "Winget (falls fehlend): $package" }
        Write-Host 'Font: JetBrains Mono Nerd Font v3.4.0 (Download und Inhalts-/Registry-Konfliktpruefung erst ohne -DryRun).'
        return
    }
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-' + [guid]::NewGuid().ToString('N'))
    try {
        [IO.Directory]::CreateDirectory($temp) | Out-Null
        $archive = Join-Path $temp 'fonts.zip'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip' -OutFile $archive -UseBasicParsing
        Expand-Archive -LiteralPath $archive -DestinationPath (Join-Path $temp 'fonts')
        $fontEntries = @()
        $fontRegistry = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
        $registryConflict = $false
        foreach ($style in 'Regular', 'Bold', 'Italic', 'BoldItalic') {
            $name = "JetBrainsMonoNerdFont-$style.ttf"
            $target = Join-Path $env:LOCALAPPDATA "Microsoft/Windows/Fonts/$name"
            $fontEntries += New-CopyEntry $target (Join-Path $temp "fonts/$name")
            $keyName = "JetBrainsMono Nerd Font $style (TrueType)"
            $old = Get-ItemPropertyValue -LiteralPath $fontRegistry -Name $keyName -ErrorAction SilentlyContinue
            if ($old -and $old -ne $target) {
                if (-not $Backup) { throw "Font-Registry-Konflikt: $keyName. -Backup verwenden." }
                $registryConflict = $true
            }
        }
        $fontPlan = @(Get-FilePlan $fontEntries -Backup:$Backup)
        # Every destination has now been checked before packages/configs/registry are changed.
        foreach ($package in $packages) {
            Invoke-Native 'winget.exe' @('install', '--exact', '--id', $package, '--source', 'winget', '--no-upgrade', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity') @(0, -1978335189) | Out-Host
        }
        if ($registryConflict) {
            $saved = Join-Path $env:LOCALAPPDATA "Microsoft/Windows/Fonts/Fonts.backup-$([guid]::NewGuid().ToString('N')).reg"
            [IO.Directory]::CreateDirectory((Split-Path -Parent $saved)) | Out-Null
            Invoke-Native 'reg.exe' @('export', 'HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts', $saved) | Out-Host
            Write-Host "Registry-Backup: $saved"
        }
        Write-FilePlan $plan
        Write-FilePlan $fontPlan
        New-Item -Path $fontRegistry -Force | Out-Null
        foreach ($entry in $fontEntries) {
            $style = [IO.Path]::GetFileNameWithoutExtension($entry.Path) -replace '^JetBrainsMonoNerdFont-', ''
            New-ItemProperty -LiteralPath $fontRegistry -Name "JetBrainsMono Nerd Font $style (TrueType)" -Value $entry.Path -PropertyType String -Force | Out-Null
        }
        Write-Host 'Fertig. Ab-/Anmelden aktiviert Fonts, neuen PATH und (falls eingerichtet) GlazeWM.'
    } finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
    }
}
