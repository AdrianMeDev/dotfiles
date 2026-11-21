Describe 'Windows dot commands' {
    BeforeAll {
        $script:source = [IO.Path]::GetFullPath("$PSScriptRoot/..")
        . "$script:source/installer-core.ps1"
        $script:ids = @(Get-Content "$script:source/../manifests/winget.tsv" |
            Where-Object { $_.Trim() -and -not $_.StartsWith('#') } |
            ForEach-Object { ($_ -split "`t")[2] })
        $script:oldEnv = @{}
        foreach ($name in 'USERPROFILE', 'APPDATA', 'LOCALAPPDATA', 'CLAUDE_CONFIG_DIR', 'PI_CODING_AGENT_DIR') {
            $script:oldEnv[$name] = [Environment]::GetEnvironmentVariable($name)
            [Environment]::SetEnvironmentVariable($name, (Join-Path $TestDrive $name))
        }
        function Assert-WindowsPrerequisites {}
        function Select-WslDistro { return $script:wslDistro }
        function Invoke-NativeLive {
            param($Program, $Arguments)
            $Program | Should -Be 'wsl.exe'
            $script:wslCalls += , ($Arguments -join ' ')
            return $script:wslCode
        }
        function Get-Process { param($Name, $ErrorAction) }
        function Invoke-RestMethod {
            param($Uri)
            $script:restCalls++
            [pscustomobject]@{ tag_name = $script:vialTag; prerelease = $false; draft = $false; assets = @(
                [pscustomobject]@{ name = "Vial-$script:vialTag-portable.zip"; browser_download_url = 'https://example.invalid/vial.zip'; digest = $null }) }
        }
        function Invoke-WebRequest { param($Uri, $OutFile, [switch]$UseBasicParsing) $script:downloads++; [IO.File]::WriteAllText($OutFile, 'vial archive') }
        function Expand-Archive {
            param($LiteralPath, $DestinationPath)
            [IO.Directory]::CreateDirectory($DestinationPath) | Out-Null
            [IO.File]::WriteAllText((Join-Path $DestinationPath 'Vial.exe'), 'exe')
        }
        function New-VialShortcut { param($Target) }
        function Read-FontRegistryValue { param($SubKey, $Name) return $null }
        function Invoke-NativeResult {
            param($Program, $Arguments)
            if ($Program -eq 'wsl.exe') {
                $script:wslCalls += , ($Arguments -join ' ')
                return [pscustomobject]@{ Code = $script:wslCode; Output = @('wsl doctor output') }
            }
            if ($Program -eq 'claude' -and $Arguments[0] -eq '--version') {
                return [pscustomobject]@{ Code = 0; Output = @('test version') }
            }
            $Program | Should -Be 'winget.exe'
            $id = $Arguments[[Array]::IndexOf($Arguments, '--id') + 1]
            $Arguments | Should -Contain '--exact'
            if ($Arguments[0] -eq 'list') {
                $script:listed += $id
                $code = if ($id -eq 'Git.Git') { -1978335212 } else { 0 }
            } else {
                $Arguments[0] | Should -Be 'upgrade'
                $script:upgraded += $id
                $code = -1978335189
            }
            return [pscustomobject]@{ Code = $code; Output = @() }
        }
    }
    BeforeEach {
        # Fresh profile per case: generated files (distro.lua, .wslconfig, Zed settings) depend on the selected distro.
        $script:run = [guid]::NewGuid().ToString('N')
        foreach ($name in 'USERPROFILE', 'APPDATA', 'LOCALAPPDATA', 'CLAUDE_CONFIG_DIR', 'PI_CODING_AGENT_DIR') {
            [Environment]::SetEnvironmentVariable($name, (Join-Path $TestDrive "$script:run/$name"))
        }
        $script:listed = @()
        $script:upgraded = @()
        $script:wslDistro = $null
        $script:wslCode = 0
        $script:wslCalls = @()
        $script:vialTag = 'v0.7.5'
        $script:restCalls = 0
        $script:downloads = 0
    }
    AfterAll {
        foreach ($name in $script:oldEnv.Keys) { [Environment]::SetEnvironmentVariable($name, $script:oldEnv[$name]) }
    }
    It 'prints exactly the manifest IDs in dry-run, without calling winget' {
        @(Update-WindowsDesktop $script:source -DryRun) | Should -Be $script:ids
        $script:listed.Count | Should -Be 0
        $script:upgraded.Count | Should -Be 0
        @(& "$script:source/dot.ps1" update -DryRun -NoWsl) | Should -Be $script:ids
        $LASTEXITCODE | Should -Be 0
        @(& "$script:source/dot.ps1" update --dry-run -NoWsl) | Should -Be $script:ids
        $LASTEXITCODE | Should -Be 0
    }
    It 'upgrades only installed manifest IDs and reapplies configs and agents' {
        Update-WindowsDesktop $script:source
        $script:listed | Should -Be $script:ids
        $script:upgraded | Should -Be @($script:ids | Where-Object { $_ -ne 'Git.Git' })
        Test-Path "$env:APPDATA/Zed/settings.json" | Should -BeTrue
        Test-Path "$env:CLAUDE_CONFIG_DIR/CLAUDE.md" | Should -BeTrue
    }
    It 'reports altered config and agent files, package status and registry drift without repairs' {
        $entries = @(Get-ConfigEntries $script:source '')
        Write-FilePlan @(Get-FilePlan $entries -Backup)
        $config = Join-Path $env:APPDATA 'Zed/settings.json'
        $agent = Join-Path $env:CLAUDE_CONFIG_DIR 'CLAUDE.md'
        foreach ($path in $config, $agent) { [IO.File]::WriteAllText($path, 'modified') }
        $report = @(Get-DoctorReport $script:source)
        $issues = @($report | Where-Object Problem | ForEach-Object Message)
        $issues | Should -Contain "Replace: $config"
        $issues | Should -Contain "Replace: $agent"
        $issues | Should -Contain 'Winget Git.Git - fehlt'
        $issues | Should -Contain "Create: HKCU\$(Get-DarkModeSubKey)\AppsUseLightTheme"
        $report.Message | Should -Contain 'Claude: test version'
        [IO.File]::ReadAllText($config) | Should -BeExactly 'modified'
        $script:upgraded.Count | Should -Be 0
    }
    It 'reports the WSL update in dry-run without launching WSL' {
        $script:wslDistro = 'archlinux'
        $output = Update-WindowsDesktop $script:source -DryRun 6>&1
        @($output | Where-Object { $_ -is [string] }) | Should -Be $script:ids
        (@($output | Where-Object { $_ -isnot [string] }) | Out-String) | Should -Match 'archlinux'
        $script:wslCalls.Count | Should -Be 0
    }
    It 'runs dot update in the WSL distro after the Windows update' {
        $script:wslDistro = 'archlinux'
        Update-WindowsDesktop $script:source 6>$null
        $script:upgraded | Should -Be @($script:ids | Where-Object { $_ -ne 'Git.Git' })
        $script:wslCalls | Should -Be @('-d archlinux --cd ~ -- bash -c exec "$HOME/.local/bin/dot" update')
    }
    It 'skips WSL with -NoWsl or without a distro' {
        $script:wslDistro = 'archlinux'
        Update-WindowsDesktop $script:source -NoWsl 6>$null
        $script:wslDistro = $null
        Update-WindowsDesktop $script:source 6>$null
        $script:wslCalls.Count | Should -Be 0
        [IO.File]::ReadAllText((Join-Path $env:USERPROFILE '.config/wezterm/distro.lua')) | Should -Be "return nil`n"
    }
    It 'replaces distro.lua on distro change without -Backup while wezterm.lua still conflicts' {
        $script:wslDistro = 'archlinux'
        Update-WindowsDesktop $script:source -NoWsl 6>$null
        $distroPath = Join-Path $env:USERPROFILE '.config/wezterm/distro.lua'
        [IO.File]::ReadAllText($distroPath) | Should -Be "return `"archlinux`"`n"
        $script:wslDistro = 'Arch'
        Update-WindowsDesktop $script:source -NoWsl 6>$null
        [IO.File]::ReadAllText($distroPath) | Should -Be "return `"Arch`"`n"
        $weztermPath = Join-Path $env:USERPROFILE '.config/wezterm/wezterm.lua'
        [IO.File]::WriteAllText($weztermPath, 'custom')
        { Update-WindowsDesktop $script:source -NoWsl 6>$null } | Should -Throw '*Dateikonflikt*'
    }
    It 'fails when dot update in WSL fails' {
        $script:wslDistro = 'archlinux'
        $script:wslCode = 4
        { Update-WindowsDesktop $script:source 6>$null } | Should -Throw '*Exit 4*'
    }
    It 'reports WSL Arch health read-only in doctor' {
        $script:wslDistro = 'archlinux'
        $report = @(Get-DoctorReport $script:source)
        $report.Message | Should -Contain 'WSL2 Arch: archlinux (WSL2)'
        ($report.Message -join "`n") | Should -Match 'WSL dot doctor \(Exit 0\)'
        $script:wslCalls | Should -Be @('-d archlinux --cd ~ -- bash -c exec "$HOME/.local/bin/dot" doctor')
    }
    It 'reports missing Arch, WSL doctor failures and -NoWsl in doctor' {
        $report = @(Get-DoctorReport $script:source)
        ($report | Where-Object Problem).Message | Should -Contain 'WSL2 Arch: nicht installiert'
        $script:wslDistro = 'archlinux'
        $script:wslCode = 1
        $report = @(Get-DoctorReport $script:source)
        @($report | Where-Object { $_.Problem -and $_.Message -like 'WSL dot doctor*' }).Message | Should -Match 'WSL dot doctor \(Exit 1\)'
        $script:wslCalls = @()
        $report = @(Get-DoctorReport $script:source -NoWsl)
        $report.Message | Should -Contain 'WSL2: uebersprungen (-NoWsl)'
        $script:wslCalls.Count | Should -Be 0
    }
    It 'skips Vial in update when it is not installed, without network' {
        Update-WindowsDesktop $script:source -NoWsl 6>$null
        $script:restCalls | Should -Be 0
        Test-Path (Join-Path $env:LOCALAPPDATA 'Vial') | Should -BeFalse
    }
    It 'upgrades Vial in update only for a newer release tag' {
        $dir = Join-Path $env:LOCALAPPDATA 'Vial'
        [IO.Directory]::CreateDirectory($dir) | Out-Null
        [IO.File]::WriteAllText((Join-Path $dir '.version'), 'v0.7.5')
        Update-WindowsDesktop $script:source -NoWsl 6>$null
        $script:downloads | Should -Be 0
        $script:vialTag = 'v0.8.0'
        Update-WindowsDesktop $script:source -NoWsl 6>$null
        $script:downloads | Should -Be 1
        Get-Content -LiteralPath (Join-Path $dir '.version') -Raw | Should -Be 'v0.8.0'
        Update-WindowsDesktop $script:source -NoWsl 6>$null
        $script:downloads | Should -Be 1
    }
    It 'reports Vial status read-only in doctor' {
        $report = @(Get-DoctorReport $script:source -NoWsl)
        (($report | Where-Object Problem).Message -join "`n") | Should -Match 'Vial: nicht installiert'
        $dir = Join-Path $env:LOCALAPPDATA 'Vial'
        [IO.Directory]::CreateDirectory($dir) | Out-Null
        [IO.File]::WriteAllText((Join-Path $dir '.version'), 'v0.7.5')
        $report = @(Get-DoctorReport $script:source -NoWsl)
        (($report | Where-Object Problem).Message -join "`n") | Should -Match 'Vial.exe fehlt'
        [IO.File]::WriteAllText((Join-Path $dir 'Vial.exe'), 'exe')
        $report = @(Get-DoctorReport $script:source -NoWsl)
        $report.Message | Should -Contain 'Vial: v0.7.5'
        $script:restCalls | Should -Be 0
        $script:downloads | Should -Be 0
    }
    It 'prints usage and fails for an unknown verb' {
        (& "$script:source/dot.ps1" unknown) | Should -Match 'Usage:'
        $LASTEXITCODE | Should -Be 2
    }
    It 'prints usage and fails for an unknown argument' {
        (& "$script:source/dot.ps1" update --unknown) | Should -Match 'Usage:'
        $LASTEXITCODE | Should -Be 2
    }
}
