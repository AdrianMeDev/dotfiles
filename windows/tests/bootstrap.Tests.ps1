Describe 'bootstrap.ps1' {
    BeforeAll {
        $script:bootstrap = [IO.Path]::GetFullPath("$PSScriptRoot/../../bootstrap.ps1")
        $global:fake = Join-Path $TestDrive 'dot.ps1'
        Set-Content -LiteralPath $global:fake -Value @'
param([string]$Verb, [switch]$DryRun, [switch]$Backup, [string[]]$Extra, [string]$Distro, [switch]$NoAutostart, [switch]$NoWsl, [string]$WslUser)
[pscustomobject]@{ Verb = $Verb; DryRun = [bool]$DryRun; Backup = [bool]$Backup; Extra = @($Extra); Distro = $Distro; NoAutostart = [bool]$NoAutostart; NoWsl = [bool]$NoWsl; WslUser = $WslUser } |
    ConvertTo-Json -Compress | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'args.json')
'@
        $script:argsFile = Join-Path $TestDrive 'args.json'
        function Test-Windows11 { $true }
        function Test-Winget { $true }
    }
    BeforeEach { Remove-Item -LiteralPath $script:argsFile -ErrorAction SilentlyContinue }
    It 'forwards its arguments to dot.ps1 install' {
        & $script:bootstrap -DotScript $global:fake -DryRun -Backup -Extra vs -Distro Arch -NoAutostart *> $null
        $forwarded = Get-Content -LiteralPath $script:argsFile -Raw | ConvertFrom-Json
        $forwarded.Verb | Should -Be 'install'
        $forwarded.DryRun | Should -BeTrue
        $forwarded.Backup | Should -BeTrue
        $forwarded.Extra | Should -Be @('vs')
        $forwarded.Distro | Should -Be 'Arch'
        $forwarded.NoAutostart | Should -BeTrue
    }
    It 'forwards -NoWsl and -WslUser' {
        & $script:bootstrap -DotScript $global:fake -NoWsl -WslUser ada *> $null
        $forwarded = Get-Content -LiteralPath $script:argsFile -Raw | ConvertFrom-Json
        $forwarded.NoWsl | Should -BeTrue
        $forwarded.WslUser | Should -Be 'ada'
    }
    It 'forwards no flags by default' {
        & $script:bootstrap -DotScript $global:fake *> $null
        $forwarded = Get-Content -LiteralPath $script:argsFile -Raw | ConvertFrom-Json
        $forwarded.DryRun | Should -BeFalse
        $forwarded.Backup | Should -BeFalse
        $forwarded.NoWsl | Should -BeFalse
        $forwarded.WslUser | Should -BeNullOrEmpty
    }
    It 'rejects unsupported Windows versions before invoking dot.ps1' {
        function Test-Windows11 { $false }
        ((& $script:bootstrap -DotScript $global:fake 2>&1 | ForEach-Object { "$_" }) -join ' ') | Should -Match 'Windows 11 ist erforderlich'
        $LASTEXITCODE | Should -Be 1
        Test-Path -LiteralPath $script:argsFile | Should -BeFalse
        function Test-Windows11 { $true }
    }
    It 'fails with a clear error when winget is missing' {
        function Test-Winget { $false }
        { & $script:bootstrap -DotScript $global:fake -ErrorAction Stop 2>&1 | Out-Null; if ($LASTEXITCODE) { throw "exit $LASTEXITCODE" } } | Should -Throw
        Test-Path -LiteralPath $script:argsFile | Should -BeFalse
        ((& $script:bootstrap -DotScript $global:fake 2>&1 | ForEach-Object { "$_" }) -join ' ') | Should -Match 'winget.exe'
        function Test-Winget { $true }
    }
    Context 'standalone (no local checkout)' {
        BeforeAll {
            # A copy without windows/dot.ps1 next to it forces the remote path.
            $script:standalone = Join-Path $TestDrive 'solo/bootstrap.ps1'
            New-Item -ItemType Directory -Path (Split-Path $script:standalone) | Out-Null
            Copy-Item -LiteralPath $script:bootstrap -Destination $script:standalone
            $global:cloneCalls = 0
            $global:gitInstalls = 0
            $global:gitPresent = $true
            function Test-Git { $global:gitPresent }
            function Install-Git { $global:gitInstalls++; $global:gitPresent = $true }
            function Invoke-GitClone([string]$Url, [string]$Path) {
                $global:cloneCalls++
                New-Item -ItemType Directory -Path (Join-Path $Path 'windows'), (Join-Path $Path '.git') -Force | Out-Null
                Copy-Item -LiteralPath $global:fake -Destination (Join-Path $Path 'windows/dot.ps1')
            }
        }
        BeforeEach {
            $global:cloneCalls = 0; $global:gitInstalls = 0; $global:gitPresent = $true
            $script:target = Join-Path $TestDrive 'clone'
            Remove-Item -LiteralPath $script:target -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath (Join-Path $script:target 'windows/args.json') -ErrorAction SilentlyContinue
        }
        It 'clones and runs dot.ps1 install with forwarded parameters' {
            & $script:standalone -TargetDir $script:target -Backup -NoWsl *> $null
            $global:cloneCalls | Should -Be 1
            $global:gitInstalls | Should -Be 0
            $forwarded = Get-Content -LiteralPath (Join-Path $script:target 'windows/args.json') -Raw | ConvertFrom-Json
            $forwarded.Verb | Should -Be 'install'
            $forwarded.Backup | Should -BeTrue
            $forwarded.NoWsl | Should -BeTrue
        }
        It 'installs Git first when git.exe is missing' {
            $global:gitPresent = $false
            & $script:standalone -TargetDir $script:target *> $null
            $global:gitInstalls | Should -Be 1
            $global:cloneCalls | Should -Be 1
        }
        It 'is idempotent on a repeat run' {
            & $script:standalone -TargetDir $script:target *> $null
            & $script:standalone -TargetDir $script:target *> $null
            $global:cloneCalls | Should -Be 1
            Test-Path -LiteralPath (Join-Path $script:target 'windows/args.json') | Should -BeTrue
        }
        It 'writes nothing on -DryRun' {
            $global:gitPresent = $false
            & $script:standalone -TargetDir $script:target -DryRun *> $null
            $global:cloneCalls | Should -Be 0
            $global:gitInstalls | Should -Be 0
            Test-Path -LiteralPath $script:target | Should -BeFalse
        }
        It 'fails on a non-empty non-Git target' {
            New-Item -ItemType Directory -Path $script:target | Out-Null
            Set-Content -LiteralPath (Join-Path $script:target 'file.txt') -Value 'x'
            ((& $script:standalone -TargetDir $script:target 2>&1 | ForEach-Object { "$_" }) -join ' ') | Should -Match 'kein Git-Klon'
            $global:cloneCalls | Should -Be 0
        }
        AfterAll {
            Remove-Variable -Scope Global -Name cloneCalls, gitInstalls, gitPresent, fake -ErrorAction SilentlyContinue
        }
    }
}
