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
        # Every Context gets its own profile (created lazily by the code under test), so files written by an
        # earlier Context (distro.lua, .wslconfig, Flow settings) cannot conflict with the plan of the next one.
        function Use-TestProfile {
            $env:USERPROFILE = Join-Path $script:temporary ([guid]::NewGuid().ToString('N') + '/User with spaces')
            $env:APPDATA = Join-Path $env:USERPROFILE 'AppData/Roaming'
            $env:LOCALAPPDATA = Join-Path $env:USERPROFILE 'AppData/Local'
        }
        Use-TestProfile
        $script:names = @('archlinux')
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
        # Never touch the real HKCU: reads come from $script:darkValue, writes are counted.
        $script:darkValue = $null
        $script:darkWrites = 0
        function Read-FontRegistryValue { param($SubKey, $Name) return $script:darkValue }
        function Write-DarkModePlan { param($Plan, $SubKey, $BackupDirectory) $script:darkWrites++ }
        $script:noWsl = $false
        function Get-Command { param($Name, $ErrorAction) if ($Name -ne 'wsl.exe' -or -not $script:noWsl) { return $Name } }
    }
    AfterAll {
        foreach ($name in $script:previous.Keys) { [Environment]::SetEnvironmentVariable($name, $script:previous[$name]) }
        if (Test-Path $script:temporary) { Remove-Item -LiteralPath $script:temporary -Recurse -Force }
    }

    Context 'dry run and distro selection' {
        BeforeAll { Use-TestProfile }
        It 'dry run creates no files and installs no packages' {
            Install-WindowsDesktop $script:source -DryRun
            Test-Path $script:temporary | Should -BeFalse
            $script:packageCalls | Should -Be 0
            $script:darkWrites | Should -Be 0
        }
        It 'dry run shows the dark mode plan and the Flow theme' {
            $output = (Install-WindowsDesktop $script:source -DryRun 6>&1 | Out-String)
            $output | Should -Match 'Create: HKCU\\.*Personalize\\AppsUseLightTheme = 0'
            $output | Should -Match 'Create: HKCU\\.*Personalize\\SystemUsesLightTheme = 0'
            $output | Should -Match 'FlowLauncher.Themes.TokyoNight\.xaml'
        }
        It 'plans dark mode as Create, Replace, then Skip' {
            $script:darkValue = $null
            (Get-DarkModePlan 'test').Action | Should -Be @('Create', 'Create')
            $script:darkValue = [pscustomobject]@{ Value = 1; Kind = [Microsoft.Win32.RegistryValueKind]::DWord }
            (Get-DarkModePlan 'test').Action | Should -Be @('Replace', 'Replace')
            $script:darkValue = [pscustomobject]@{ Value = 0; Kind = [Microsoft.Win32.RegistryValueKind]::DWord }
            (Get-DarkModePlan 'test').Action | Should -Be @('Skip', 'Skip')
            $script:darkValue = $null
        }
        It 'sets the Flow theme to TokyoNight' {
            $flowEntry = Get-FlowConfigEntry
            ([Text.Encoding]::UTF8.GetString($flowEntry.Bytes) | ConvertFrom-Json).Theme | Should -BeExactly 'TokyoNight'
        }
        It 'prefers archlinux, rejects ambiguous, missing and WSL1 distros' {
            $script:names = @('archlinux', 'Arch Test')
            Select-WslDistro | Should -Be 'archlinux'
            $script:names = @('Arch')
            Select-WslDistro | Should -Be 'Arch'
            $script:names = @('Arch', 'Arch Test')
            Throws { Select-WslDistro } 'nicht eindeutig'
            Select-WslDistro 'Arch Test' | Should -Be 'Arch Test'
            Throws { Select-WslDistro 'Missing' } 'nicht gefunden'
            $script:names = @('Ubuntu')
            Select-WslDistro | Should -BeNullOrEmpty
            $script:names = @('archlinux')
            $script:version = 1
            Throws { Select-WslDistro } 'WSL2'
            $script:version = 2
        }
        It 'returns null without wsl.exe and rejects an explicit distro' {
            $script:noWsl = $true
            try {
                Select-WslDistro | Should -BeNullOrEmpty
                Throws { Select-WslDistro 'archlinux' } 'nicht gefunden'
                Install-WindowsDesktop $script:source -DryRun
                Test-Path $script:temporary | Should -BeFalse
            } finally { $script:noWsl = $false }
        }
        It 'returns null without any distro and rejects an explicit missing one' {
            $script:names = @()
            try {
                Select-WslDistro | Should -BeNullOrEmpty
                $script:names = @('', " `0 ")
                Select-WslDistro | Should -BeNullOrEmpty
                Throws { Select-WslDistro 'archlinux' } 'nicht gefunden'
            } finally { $script:names = @('archlinux') }
        }
        It 'writes return nil to distro.lua without a distro' {
            $entry = @(Get-ConfigEntries $script:source $null) | Where-Object { $_.Path -like '*distro.lua' }
            [Text.Encoding]::UTF8.GetString($entry.Bytes) | Should -Be "return nil`n"
        }
        It 'removes UTF16 NUL characters from distro names' {
            $script:names = @("a`0r`0c`0h`0l`0i`0n`0u`0x`0")
            Select-WslDistro | Should -Be 'archlinux'
            $script:names = @('archlinux')
        }
    }

    Context 'wsl arch install and bootstrap' {
        BeforeAll {
            Use-TestProfile
            $script:wslCalls = @()
            $script:installCode = 0
            $script:installOutput = @('Installing')
            $script:registers = $true
            $script:bootstrapOutput = @('== wsl.conf', 'geschrieben: /etc/wsl.conf')
            $script:liveCode = 0
            function Invoke-Native {
                param($Program, $Arguments, $SuccessCodes)
                if ($Arguments -contains '--quiet') { return $script:names }
                if ($Arguments -contains '--verbose') { return ($script:names | ForEach-Object { "  $_    Stopped    2" }) }
                $script:wslCalls += , ($Arguments -join ' ')
                if ($Arguments -contains 'wslpath') { return '/mnt/c/mock/' + (Split-Path -Leaf $Arguments[-1]) }
                if ($Arguments -contains 'bash') { return $script:bootstrapOutput }
                return
            }
            function Invoke-NativeResult {
                param($Program, $Arguments)
                $script:wslCalls += , ($Arguments -join ' ')
                if ($script:registers -and $script:installCode -eq 0) { $script:names = @('archlinux') }
                return [pscustomobject]@{ Code = $script:installCode; Output = $script:installOutput }
            }
            function Invoke-NativeLive {
                param($Program, $Arguments)
                $script:wslCalls += , ($Arguments -join ' ')
                return $script:liveCode
            }
        }
        BeforeEach {
            $script:wslCalls = @()
            $script:names = @()
            $script:installCode = 0
            $script:installOutput = @('Installing')
            $script:registers = $true
            $script:bootstrapOutput = @('== wsl.conf', 'geschrieben: /etc/wsl.conf')
            $script:liveCode = 0
        }
        AfterAll { $script:names = @('archlinux') }
        It 'installs archlinux when absent' {
            Install-WslArch | Should -Be 'archlinux'
            $script:wslCalls | Should -Be @('--install archlinux --no-launch')
        }
        It 'does not install again when the distro exists' {
            $script:names = @('archlinux')
            Install-WslArch | Should -Be 'archlinux'
            $script:wslCalls | Should -BeNullOrEmpty
        }
        It 'asks for a reboot and rerun when WSL requires a restart' {
            $script:installCode = 3010
            Throws { Install-WslArch } 'Neustart.*erneut'
            $script:installCode = 1
            $script:installOutput = @('Changes will not be effective until the system is rebooted.')
            Throws { Install-WslArch } 'Neustart.*erneut'
        }
        It 'fails when the distro stays unregistered' {
            $script:registers = $false
            Throws { Install-WslArch } 'nicht registriert.*erneut'
        }
        It 'fails on a plain install error' {
            $script:installCode = 5
            Throws { Install-WslArch } 'Exit 5'
        }
        It 'sanitizes the Linux user name' {
            Get-WslUserName 'Max Mustermann' | Should -Be 'max_mustermann'
            Get-WslUserName '1abc' | Should -Be '_1abc'
            (Get-WslUserName ('a' * 40)).Length | Should -Be 32
            $env:USERNAME = 'Ada.L'
            try { Get-WslUserName | Should -Be 'ada_l' } finally { $env:USERNAME = $null }
            Throws { Get-WslUserName 'Root' } 'root'
        }
        It 'bootstraps as root, terminates after a wsl.conf change, then runs install.sh as the user' {
            $script:names = @('archlinux')
            Invoke-WslBootstrap $script:source 'archlinux' 'Ada Lovelace' -Backup 6>$null
            $script:wslCalls.Count | Should -Be 5 -Because '2x wslpath, bootstrap, terminate, install.sh'
            $script:wslCalls[2] | Should -Be ('-d archlinux -u root -- bash /mnt/c/mock/wsl-bootstrap.sh --user ada_lovelace --repo /mnt/c/mock/' + (Split-Path -Leaf (Split-Path -Parent $script:source)) + ' --backup')
            $script:wslCalls[4] | Should -Be '-d archlinux -u ada_lovelace --cd ~ -- bash ./dotfiles/install.sh --backup'
        }
        It 'orders the calls: root bootstrap, terminate, install.sh' {
            Invoke-WslBootstrap $script:source 'archlinux' 'ada' 6>$null
            ($script:wslCalls | Where-Object { $_ -like '*bash /mnt/c/mock/wsl-bootstrap.sh*' }).Count | Should -Be 1
            $script:wslCalls[-3] | Should -Match '^-d archlinux -u root -- bash .*--user ada --repo'
            $script:wslCalls[-2] | Should -Be '--terminate archlinux'
            $script:wslCalls[-1] | Should -Be '-d archlinux -u ada --cd ~ -- bash ./dotfiles/install.sh'
        }
        It 'is idempotent: no terminate without a wsl.conf change, no backup unless asked' {
            $script:bootstrapOutput = @('ok: /etc/wsl.conf default=ada')
            Invoke-WslBootstrap $script:source 'archlinux' 'ada' 6>$null
            $script:wslCalls | Should -Not -Contain '--terminate archlinux'
            $script:wslCalls[-1] | Should -Not -Match '--backup'
            $script:wslCalls[-1] | Should -Match 'install\.sh$'
        }
        It 'fails when install.sh fails' {
            $script:liveCode = 3
            Throws { Invoke-WslBootstrap $script:source 'archlinux' 'ada' 6>$null } 'install\.sh \(Exit 3\)'
        }
        It 'dry run with no distro plans the install but changes nothing' {
            $output = (Install-WindowsDesktop $script:source -DryRun -Backup -WslUser ada 6>&1 | Out-String)
            $output | Should -Match '--install archlinux --no-launch'
            $output | Should -Match 'install\.sh --backup'
            $script:wslCalls | Should -BeNullOrEmpty
            Test-Path $script:temporary | Should -BeFalse
        }
        It '-NoWsl skips the WSL steps' {
            $output = (Install-WindowsDesktop $script:source -DryRun -NoWsl 6>&1 | Out-String)
            $output | Should -Not -Match 'install\.sh|--install archlinux'
            $output | Should -Not -Match '\.wslconfig'
            $script:wslCalls | Should -BeNullOrEmpty
        }
    }

    Context 'wslconfig' {
        BeforeAll { Use-TestProfile }
        BeforeEach {
            $script:wslPath = Join-Path $env:USERPROFILE '.wslconfig'
            Remove-Item -LiteralPath $script:wslPath -ErrorAction SilentlyContinue
        }
        AfterAll { Remove-Item -LiteralPath (Join-Path $env:USERPROFILE '.wslconfig') -ErrorAction SilentlyContinue }
        It 'creates mirrored networking, then skips' {
            $entry = Get-WslConfigEntry
            [Text.Encoding]::UTF8.GetString($entry.Bytes) | Should -Match '(?m)^\[wsl2\]\r?\nnetworkingMode=mirrored'
            Write-FilePlan @(Get-FilePlan @($entry))
            (Get-FilePlan @(Get-WslConfigEntry)).Action | Should -Be 'Skip'
        }
        It 'preserves unrelated sections and keys' {
            [IO.File]::WriteAllText($script:wslPath, "[wsl2]`nmemory=8GB`n[experimental]`nautoMemoryReclaim=gradual`n")
            $text = [Text.Encoding]::UTF8.GetString((Get-WslConfigEntry).Bytes)
            $text | Should -Be "[wsl2]`nnetworkingMode=mirrored`nmemory=8GB`n[experimental]`nautoMemoryReclaim=gradual`n"
            [IO.File]::WriteAllText($script:wslPath, "[experimental]`nsparseVhd=true`n")
            $text = [Text.Encoding]::UTF8.GetString((Get-WslConfigEntry).Bytes)
            $text | Should -Be "[experimental]`nsparseVhd=true`n`n[wsl2]`nnetworkingMode=mirrored`n"
        }
        It 'conflicts on networkingMode=nat without Backup and replaces with Backup' {
            [IO.File]::WriteAllText($script:wslPath, "[wsl2]`nnetworkingMode=nat`nmemory=8GB`n")
            Throws { Get-FilePlan @(Get-WslConfigEntry) } 'Dateikonflikt'
            $plan = @(Get-FilePlan @(Get-WslConfigEntry) -Backup)
            $plan[0].Action | Should -Be 'Replace'
            [Text.Encoding]::UTF8.GetString($plan[0].Bytes) | Should -Be "[wsl2]`nnetworkingMode=mirrored`nmemory=8GB`n"
        }
    }

    Context 'winget packages' {
        BeforeAll { Use-TestProfile; $script:repo = Split-Path -Parent $script:source }
        It 'returns the ten base packages' {
            $ids = @(Get-WingetPackages $script:repo)
            $ids.Count | Should -Be 10
            $ids | Should -Contain 'Git.Git'
            $ids | Should -Not -Contain 'Microsoft.VisualStudio.2022.Community'
        }
        It 'adds Visual Studio with -Extra vs' {
            @(Get-WingetPackages $script:repo -Extra vs) | Should -Contain 'Microsoft.VisualStudio.2022.Community'
        }
        It 'rejects an unknown extra' {
            Throws { Get-WingetPackages $script:repo -Extra nope } 'Unbekanntes Extra'
        }
        It 'dry run lists every package' {
            $out = Install-WindowsDesktop $script:source -DryRun -Extra vs 6>&1 | Out-String
            foreach ($id in Get-WingetPackages $script:repo -Extra vs) { $out | Should -Match ([regex]::Escape($id)) }
        }
    }

    Context 'config entries and file plan' {
        BeforeAll {
            Use-TestProfile
            $script:entries = @(Get-ConfigEntries $script:source 'archlinux')
        }
        It 'NoAutostart removes exactly one entry' {
            $noAuto = @(Get-ConfigEntries $script:source 'archlinux' -NoAutostart)
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
        It 'stages wsl_connections as valid JSONC for the distro only' {
            $zedPath = Join-Path $env:APPDATA 'Zed/settings.json'
            $text = [Text.Encoding]::UTF8.GetString(@($script:entries | Where-Object Path -eq $zedPath)[0].Bytes)
            $json = ($text -split "`r?`n" | Where-Object { $_.TrimStart() -notlike '//*' }) -join "`n" -replace ',(\s*[}\]])', '$1'
            $parsed = $json | ConvertFrom-Json
            $parsed.wsl_connections[0].distro_name | Should -Be 'archlinux'
            $source = [IO.File]::ReadAllText((Join-Path $script:source '../zed-config/.config/zed/settings.json'))
            $source | Should -Not -Match 'wsl_connections'
            $none = @(Get-ConfigEntries $script:source $null | Where-Object Path -eq $zedPath)[0]
            [Text.Encoding]::UTF8.GetString($none.Bytes) | Should -Not -Match 'wsl_connections'
            $off = @(Get-ConfigEntries $script:source 'archlinux' -NoWsl | Where-Object Path -eq $zedPath)[0]
            [Text.Encoding]::UTF8.GetString($off.Bytes) | Should -Not -Match 'wsl_connections'
        }
        It 'omits .wslconfig with NoWsl' {
            @(Get-ConfigEntries $script:source 'archlinux' -NoWsl | Where-Object Path -like '*.wslconfig').Count | Should -Be 0
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
            $target = Join-Path $env:USERPROFILE '.config/wezterm/wezterm.lua'
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
        It 'replaces generated distro.lua on distro change without Backup while wezterm.lua still conflicts' {
            $distroPath = Join-Path $env:USERPROFILE '.config/wezterm/distro.lua'
            $changedEntries = @(Get-ConfigEntries $script:source 'Arch')
            $plan = @(Get-FilePlan $changedEntries)
            (@($plan | Where-Object Path -eq $distroPath)[0]).Action | Should -Be 'Replace'
            Write-FilePlan $plan
            [IO.File]::ReadAllText($distroPath) | Should -Be "return `"Arch`"`n"
            $weztermPath = Join-Path $env:USERPROFILE '.config/wezterm/wezterm.lua'
            [IO.File]::WriteAllText($weztermPath, 'user-edited')
            Throws { Get-FilePlan $changedEntries } 'Dateikonflikt'
            Write-FilePlan @(Get-FilePlan $changedEntries -Backup)
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

    Context 'agent config' {
        BeforeAll {
            Use-TestProfile
            $script:repo = Split-Path -Parent $script:source
            $script:savedDirs = @($env:CLAUDE_CONFIG_DIR, $env:PI_CODING_AGENT_DIR)
            $env:CLAUDE_CONFIG_DIR = $null
            $env:PI_CODING_AGENT_DIR = $null
            $script:agentEntries = @(Get-AgentConfigEntries $script:repo)
        }
        AfterAll { $env:CLAUDE_CONFIG_DIR, $env:PI_CODING_AGENT_DIR = $script:savedDirs }
        It 'targets .claude and .pi/agent below USERPROFILE' {
            $claude = Join-Path $env:USERPROFILE '.claude'
            $pi = Join-Path $env:USERPROFILE '.pi/agent'
            $script:agentEntries.Path | Should -Contain (Join-Path $claude 'CLAUDE.md')
            $script:agentEntries.Path | Should -Contain (Join-Path $claude 'settings.json')
            $script:agentEntries.Path | Should -Contain (Join-Path $pi 'AGENTS.md')
            $script:agentEntries.Path | Should -Contain (Join-Path $pi 'skills/next/SKILL.md')
            $script:agentEntries.Path | Should -Not -Match 'claude-frontmatter'
        }
        It '-Only limits the tool' {
            @(Get-AgentConfigEntries $script:repo -Only pi).Path | Should -Not -Match '[\\/]\.claude[\\/]'
            @(Get-AgentConfigEntries $script:repo -Only claude).Path | Should -Not -Match '[\\/]\.pi[\\/]'
        }
        It 'dry run lists the agent targets and writes nothing' {
            $before = Test-Path (Join-Path $env:USERPROFILE '.claude')
            $out = Install-WindowsDesktop $script:source -DryRun 6>&1 | Out-String
            $out | Should -Match 'CLAUDE\.md'
            $out | Should -Match 'AGENTS\.md'
            Test-Path (Join-Path $env:USERPROFILE '.claude') | Should -Be $before
        }
        It 'renders the same bytes as scripts/agents.py' -Skip:(-not (Get-Command python3 -ErrorAction SilentlyContinue)) {
            $code = 'import sys, hashlib; sys.path.insert(0, sys.argv[1]); import agents, pathlib; ' +
                'r = agents.render(pathlib.Path(sys.argv[2])); ' +
                '[print(t, k, hashlib.sha256(v).hexdigest()) for t, f in r.items() for k, v in sorted(f.items())]'
            $lines = @(& python3 -I -c $code (Join-Path $script:repo 'scripts') $script:repo)
            $lines.Count | Should -BeGreaterThan 0
            $expected = @{}
            foreach ($line in $lines) {
                $tool, $rel, $hash = $line -split ' '
                $root = if ($tool -eq 'claude') { '.claude' } else { '.pi/agent' }
                $expected[(Join-Path (Join-Path $env:USERPROFILE $root) $rel)] = $hash
            }
            $script:agentEntries.Count | Should -Be $expected.Count
            foreach ($entry in $script:agentEntries) {
                $hash = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($entry.Bytes)).Replace('-', '').ToLowerInvariant()
                $hash | Should -BeExactly $expected[$entry.Path] -Because $entry.Path
            }
        }
        It 'injects the frontmatter after the first line for Claude only' {
            $next = Join-Path $env:USERPROFILE '.claude/skills/next/SKILL.md'
            $text = [Text.Encoding]::UTF8.GetString(@($script:agentEntries | Where-Object Path -eq $next)[0].Bytes)
            $extra = [IO.File]::ReadAllText((Join-Path $script:repo 'agent-config/skills/next/claude-frontmatter.txt'))
            $text.StartsWith("---`n" + $extra.TrimEnd("`n") + "`n") | Should -BeTrue
            $pi = Join-Path $env:USERPROFILE '.pi/agent/skills/next/SKILL.md'
            $piBytes = @($script:agentEntries | Where-Object Path -eq $pi)[0].Bytes
            [Convert]::ToBase64String($piBytes) | Should -BeExactly ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $script:repo 'agent-config/skills/next/SKILL.md'))))
        }
        It 'second write is all Skip and creates no backups' {
            Write-FilePlan @(Get-FilePlan $script:agentEntries)
            $second = @(Get-FilePlan $script:agentEntries)
            @($second | Where-Object Action -ne 'Skip').Count | Should -Be 0
            Write-FilePlan $second
            @(Get-ChildItem (Join-Path $env:USERPROFILE '.claude') -Recurse -Filter '*.backup-*').Count | Should -Be 0
        }
        It 'a conflict without -Backup is an error' {
            $target = Join-Path $env:USERPROFILE '.claude/CLAUDE.md'
            [IO.File]::WriteAllText($target, 'custom')
            Throws { Get-FilePlan $script:agentEntries } 'Dateikonflikt'
            @(Get-FilePlan $script:agentEntries -Backup | Where-Object Path -eq $target)[0].Action | Should -Be 'Replace'
            [IO.File]::WriteAllBytes($target, @($script:agentEntries | Where-Object Path -eq $target)[0].Bytes)
        }
    }

    Context 'full installation' {
        BeforeAll {
            Use-TestProfile
            $script:entries = @(Get-ConfigEntries $script:source 'archlinux')
            $script:target = Join-Path $env:USERPROFILE '.config/wezterm/wezterm.lua'
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
            Install-WindowsDesktop $script:source -NoWsl
            Install-WindowsDesktop $script:source -NoWsl
            $script:registryWrites | Should -Be 2 -Because 'steps after skipped packages did not run'
            $installedFonts = @(Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Microsoft/Windows/Fonts') -Filter '*.ttf')
            $installedFonts.Count | Should -Be 40 -Because 'both Ioskeley families must install all 20 styles'
            @($script:listedPackages | Where-Object { $_ -eq 'Flow-Launcher.Flow-Launcher' }).Count | Should -Be 2
            $script:packageCalls | Should -Be 20 -Because 'full installation did not process packages'
        }
        It 'runs the conflict preflight before any package' {
            [IO.File]::WriteAllText($script:target, 'conflict again')
            $before = $script:packageCalls
            Throws { Install-WindowsDesktop $script:source -NoWsl } 'Dateikonflikt'
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
    It 'rejects missing <_> before distro or package calls' -ForEach 'winget.exe' {
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
