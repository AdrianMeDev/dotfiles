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
        function Select-WslDistro { return $null }
        function Get-Process { param($Name, $ErrorAction) }
        function Read-FontRegistryValue { param($SubKey, $Name) return $null }
        function Invoke-NativeResult {
            param($Program, $Arguments)
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
        $script:listed = @()
        $script:upgraded = @()
    }
    AfterAll {
        foreach ($name in $script:oldEnv.Keys) { [Environment]::SetEnvironmentVariable($name, $script:oldEnv[$name]) }
    }
    It 'prints exactly the manifest IDs in dry-run, without calling winget' {
        @(Update-WindowsDesktop $script:source -DryRun) | Should -Be $script:ids
        $script:listed.Count | Should -Be 0
        $script:upgraded.Count | Should -Be 0
        @(& "$script:source/dot.ps1" update --dry-run) | Should -Be $script:ids
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
    It 'prints usage and fails for an unknown verb' {
        (& "$script:source/dot.ps1" unknown) | Should -Match 'Usage:'
        $LASTEXITCODE | Should -Be 2
    }
}
