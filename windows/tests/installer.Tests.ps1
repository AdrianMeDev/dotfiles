# Pester 5. Run: pwsh -NoProfile -File windows/check.ps1
# Cases inside a Describe share state and run in order (plan -> write -> repeat).

BeforeDiscovery {
    $script:notWindows = [Environment]::OSVersion.Platform -ne 'Win32NT'
}

Describe 'Windows installer' {
    BeforeAll {
        . "$PSScriptRoot/../installer-core.ps1"
        $script:source = [IO.Path]::GetFullPath("$PSScriptRoot/..")
        $script:temporary = Join-Path ([IO.Path]::GetTempPath()) ('windows-tests-' + [guid]::NewGuid())
        $script:previous = @{}
        foreach ($name in 'USERPROFILE', 'APPDATA', 'LOCALAPPDATA') { $script:previous[$name] = [Environment]::GetEnvironmentVariable($name) }
        $env:USERPROFILE = Join-Path $script:temporary 'User with spaces'
        $env:APPDATA = Join-Path $env:USERPROFILE 'AppData/Roaming'
        $env:LOCALAPPDATA = Join-Path $env:USERPROFILE 'AppData/Local'
        $script:names = @('Fedora Linux')
        $script:version = 2
        $script:packageCalls = 0
        function Throws([scriptblock]$Action, [string]$Pattern) {
            $caught = $null
            try { & $Action } catch { $caught = $_ }
            $caught | Should -Not -BeNullOrEmpty -Because "expected error matching $Pattern"
            $caught.Exception.Message | Should -Match $Pattern
        }
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
    }
    AfterAll {
        foreach ($name in $script:previous.Keys) { [Environment]::SetEnvironmentVariable($name, $script:previous[$name]) }
        if (Test-Path $script:temporary) { Remove-Item -LiteralPath $script:temporary -Recurse -Force }
    }

    Context 'dry run and distro selection' {
        It 'dry run creates no files and installs no packages' {
            Install-WindowsDesktop $script:source -DryRun
            Test-Path $script:temporary | Should -BeFalse
            $script:packageCalls | Should -Be 0
        }
        It 'rejects ambiguous, missing and WSL1 distros' {
            $script:names = @('Fedora', 'Fedora Test')
            Throws { Select-WslDistro } 'nicht eindeutig'
            Select-WslDistro 'Fedora Test' | Should -Be 'Fedora Test'
            Throws { Select-WslDistro 'Missing' } 'nicht gefunden'
            $script:names = @('Ubuntu')
            Throws { Select-WslDistro } 'nicht eindeutig'
            $script:names = @('Fedora')
            $script:version = 1
            Throws { Select-WslDistro } 'WSL2'
            $script:version = 2
        }
        It 'removes UTF16 NUL characters from distro names' {
            $script:names = @("F`0e`0d`0o`0r`0a`0")
            Select-WslDistro | Should -Be 'Fedora'
            $script:names = @('Fedora')
        }
    }

    Context 'config entries and file plan' {
        BeforeAll {
            $script:entries = @(Get-ConfigEntries $script:source 'Fedora')
        }
        It 'NoAutostart removes exactly one entry' {
            $noAuto = @(Get-ConfigEntries $script:source 'Fedora' -NoAutostart)
            $noAuto.Count | Should -Be ($script:entries.Count - 1)
        }
        It 'stages the Zed settings' {
            $zedPath = Join-Path $env:APPDATA 'Zed/settings.json'
            $zedEntry = @($script:entries | Where-Object Path -eq $zedPath)[0]
            $zedText = [Text.Encoding]::UTF8.GetString($zedEntry.Bytes)
            $zedText.Contains('"font_family": "IoskeleyMonoTerm Nerd Font Mono"') | Should -BeTrue -Because 'Zed terminal font missing'
            $zedText.Contains('"program": "pwsh.exe"') | Should -BeTrue -Because 'Zed Windows shell missing'
            $zedText.Contains('"show_edit_predictions": true') | Should -BeTrue -Because 'Zed edit predictions disabled'
            ($zedText.Contains('"provider": "ollama"') -and $zedText.Contains('"model": "qwen2.5-coder:7b-base"')) | Should -BeTrue -Because 'Zed Ollama edit prediction missing'
            ($zedText.Contains('"panel.background": "#00000000"') -and $zedText.Contains('"surface.background": "#00000000"')) | Should -BeTrue -Because 'Zed panels are not transparent'
        }
        It 'stages <_> identical to its source' -ForEach 'keymap.json', 'tasks.json', 'debug.json' {
            $path = Join-Path $env:APPDATA "Zed/$_"
            $staged = @($script:entries | Where-Object Path -eq $path)
            $staged.Count | Should -Be 1
            $expected = [IO.File]::ReadAllBytes((Join-Path $script:source "../zed-config/.config/zed/$_"))
            [Convert]::ToBase64String($staged[0].Bytes) | Should -BeExactly ([Convert]::ToBase64String($expected))
        }
        It 'is idempotent when written twice' {
            Write-FilePlan @(Get-FilePlan $script:entries)
            $second = @(Get-FilePlan $script:entries)
            @($second | Where-Object Action -ne 'Skip').Count | Should -Be 0
        }
        It 'preserves custom Flow settings and honours NoAutostart' {
            $flowPath = Join-Path $env:APPDATA 'FlowLauncher/Settings/Settings.json'
            $flowSettings = Get-Content $flowPath -Raw | ConvertFrom-Json
            ($flowSettings.Hotkey -eq 'Alt + Space' -and $flowSettings.StartFlowLauncherOnSystemStartup) | Should -BeTrue -Because 'Flow defaults'
            $flowSettings | Add-Member -NotePropertyName CustomSetting -NotePropertyValue 'preserve'
            $flowSettings.Hotkey = 'Ctrl + Space'
            $flowSettings.StartFlowLauncherOnSystemStartup = $false
            [IO.File]::WriteAllText($flowPath, (ConvertTo-Json $flowSettings))
            $flowEntry = Get-FlowConfigEntry -NoAutostart
            $merged = [Text.Encoding]::UTF8.GetString($flowEntry.Bytes) | ConvertFrom-Json
            ($merged.CustomSetting -eq 'preserve' -and -not $merged.StartFlowLauncherOnSystemStartup) | Should -BeTrue
            Throws { Get-FilePlan @($flowEntry) } 'Dateikonflikt'
            Write-FilePlan @(Get-FilePlan @((Get-FlowConfigEntry)) -Backup)
            (Get-FilePlan @((Get-FlowConfigEntry))).Action | Should -Be 'Skip' -Because 'Flow repeat must preserve serialized settings'
        }
        It 'detects conflicts and backs up on request' {
            $target = $script:entries[0].Path
            [IO.File]::WriteAllText($target, 'custom')
            Throws { Get-FilePlan $script:entries } 'Dateikonflikt'
            $backupPlan = @(Get-FilePlan $script:entries -Backup)
            Write-FilePlan $backupPlan -DryRun
            [IO.File]::ReadAllText($target) | Should -Be 'custom' -Because 'dry run changed conflict'
            Write-FilePlan $backupPlan
            $saved = @(Get-ChildItem -LiteralPath (Split-Path $target) -Filter '*.backup-*')
            $saved.Count | Should -Be 1
            [IO.File]::ReadAllText($saved[0].FullName) | Should -Be 'custom'
        }
        It 'rejects directory and parent collisions' {
            $target = $script:entries[0].Path
            $collision = Join-Path $script:temporary 'directory'
            [IO.Directory]::CreateDirectory($collision) | Out-Null
            Throws { Get-FilePlan @((New-TextEntry $collision 'test')) -Backup } 'Verzeichnis'
            Throws { Get-FilePlan @((New-TextEntry (Join-Path $target 'child') 'test')) } 'Zielverzeichnis'
        }
        It 'rejects broken symbolic links' -Skip:(-not $script:notWindows) {
            $link = Join-Path $script:temporary 'broken-link'
            New-Item -ItemType SymbolicLink -Path $link -Target (Join-Path $script:temporary 'missing') | Out-Null
            Throws { Get-FilePlan @((New-TextEntry $link 'test')) -Backup } 'Verknuepfung'
        }
    }

    Context 'full installation' {
        BeforeAll {
            $script:entries = @(Get-ConfigEntries $script:source 'Fedora')
            $script:target = $script:entries[0].Path
            function Invoke-WebRequest { param($Uri, $OutFile, [switch]$UseBasicParsing) [IO.File]::WriteAllText($OutFile, 'mock archive') }
            function Expand-Archive {
                param($LiteralPath, $DestinationPath)
                $terminal = $LiteralPath -like '*term-nerd.zip'
                $fontDirectory = if ($terminal) { Join-Path $DestinationPath 'Normal' } else { Join-Path $DestinationPath 'Normal/Hinted' }
                [IO.Directory]::CreateDirectory($fontDirectory) | Out-Null
                foreach ($number in 1..20) {
                    $family = if ($terminal) { 'IoskeleyMonoTermNerdFontMono' } else { 'IoskeleyMono' }
                    [IO.File]::WriteAllText((Join-Path $fontDirectory "$family-Style$number.ttf"), "font $family $number")
                }
            }
            function Read-FontRegistryValue { param($SubKey, $Name) return $null }
            function Write-FontRegistryPlan { param($Plan, $SubKey, $BackupDirectory) $script:registryWrites++ }
            function Invoke-NativeResult {
                param($Program, $Arguments)
                $Program | Should -Be 'winget.exe'
                $script:packageCalls++
                $script:listedPackages += $Arguments[2]
                return [pscustomobject]@{ Code = 0; Output = @('installed') }
            }
            $script:registryWrites = 0
            $script:listedPackages = @()
            $script:packageCalls = 0
        }
        It 'installs repeatedly with mocked registry, network, archive and packages' {
            Install-WindowsDesktop $script:source
            Install-WindowsDesktop $script:source
            $script:registryWrites | Should -Be 2 -Because 'steps after skipped packages did not run'
            $installedFonts = @(Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Microsoft/Windows/Fonts') -Filter '*.ttf')
            $installedFonts.Count | Should -Be 40 -Because 'both Ioskeley families must install all 20 styles'
            @($script:listedPackages | Where-Object { $_ -eq 'Flow-Launcher.Flow-Launcher' }).Count | Should -Be 2
            $script:packageCalls | Should -Be 12 -Because 'full installation did not process packages'
        }
        It 'runs the conflict preflight before any package' {
            [IO.File]::WriteAllText($script:target, 'conflict again')
            $before = $script:packageCalls
            Throws { Install-WindowsDesktop $script:source } 'Dateikonflikt'
            $script:packageCalls | Should -Be $before
        }
    }

    Context 'winget result sequences' {
        BeforeAll {
            function Invoke-NativeResult {
                param($Program, $Arguments)
                $script:commands += ,$Arguments
                ($Arguments -contains '--exact' -and $Arguments -contains '--source') | Should -BeTrue -Because 'exact source missing'
                if ($Arguments[0] -eq 'install') { $Arguments | Should -Contain '--no-upgrade' }
                return [pscustomobject]@{ Code = $script:codes.Dequeue(); Output = @('diagnostic') }
            }
        }
        It 'accepts install sequence <_>' -ForEach @('0', '-1978335212,0', '-1978335212,-1978335189,0', '-1978335212,-1978335135,0') {
            $script:codes = [Collections.Queue]::new()
            foreach ($code in ($_ -split ',')) { $script:codes.Enqueue([int]$code) }
            $script:commands = @()
            Install-WingetPackage 'test.package'
            $script:codes.Count | Should -Be 0
            $script:commands[0][0] | Should -Be 'list' -Because 'inventory must run first'
        }
        It 'fails on install sequence <_>' -ForEach @('7', '-1978335212,7', '-1978335212,-1978335189,-1978335212', '-1978335212,-1978335135,7') {
            $script:codes = [Collections.Queue]::new()
            foreach ($code in ($_ -split ',')) { $script:codes.Enqueue([int]$code) }
            Throws { Install-WingetPackage 'test.package' } 'test.package.*Exit.*diagnostic'
            $script:codes.Count | Should -Be 0
        }
    }

    Context 'font registry plan' {
        BeforeAll {
            $script:fontEntry = @([pscustomobject]@{
                Path = 'IoskeleyMonoTermNerdFontMono-Regular.ttf'
                RegistryName = 'IoskeleyMonoTermNerdFontMono-Regular (TrueType)'
            })
            function Read-FontRegistryValue { param($SubKey, $Name) return $script:oldFont }
        }
        It 'plans Create, Skip, conflict and Replace' {
            $script:oldFont = $null
            (Get-FontRegistryPlan $script:fontEntry 'test').Action | Should -Be 'Create'
            $script:oldFont = [pscustomobject]@{ Value = $script:fontEntry[0].Path; Kind = [Microsoft.Win32.RegistryValueKind]::String }
            (Get-FontRegistryPlan $script:fontEntry 'test').Action | Should -Be 'Skip'
            $script:oldFont.Value = ''
            Throws { Get-FontRegistryPlan $script:fontEntry 'test' } 'Font-Registry-Konflikt'
            (Get-FontRegistryPlan $script:fontEntry 'test' -Backup).Action | Should -Be 'Replace'
        }
        It 'propagates registry read errors' {
            function Read-FontRegistryValue { param($SubKey, $Name) throw 'access denied' }
            Throws { Get-FontRegistryPlan $script:fontEntry 'test' -Backup } 'access denied'
        }
    }
}

Describe 'Prerequisites and native execution' {
    BeforeAll {
        . "$PSScriptRoot/../installer-core.ps1"
        function Throws([scriptblock]$Action, [string]$Pattern) {
            $caught = $null
            try { & $Action } catch { $caught = $_ }
            $caught | Should -Not -BeNullOrEmpty -Because "expected error matching $Pattern"
            $caught.Exception.Message | Should -Match $Pattern
        }
    }
    It 'rejects missing <_> before distro or package calls' -ForEach 'winget.exe', 'wsl.exe' {
        function Test-Windows11 { return $true }
        $script:missing = $_
        function Get-Command { param($Name, $ErrorAction) if ($Name -ne $script:missing) { return $Name } }
        Throws { Assert-WindowsPrerequisites } $_
    }
    It 'treats external errors as fatal and carries the exit code' {
        $hostExe = (Get-Process -Id $PID).Path
        Throws { Invoke-Native $hostExe @('-NoProfile', '-Command', 'exit 7') } 'Exit 7'
        { Invoke-Native $hostExe @('-NoProfile', '-Command', 'exit 7') @(0, 7) } | Should -Not -Throw
    }
}
