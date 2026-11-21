Describe 'bootstrap.ps1' {
    BeforeAll {
        $script:bootstrap = [IO.Path]::GetFullPath("$PSScriptRoot/../../bootstrap.ps1")
        $script:fake = Join-Path $TestDrive 'dot.ps1'
        Set-Content -LiteralPath $script:fake -Value @'
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
        & $script:bootstrap -DotScript $script:fake -DryRun -Backup -Extra vs -Distro Arch -NoAutostart *> $null
        $forwarded = Get-Content -LiteralPath $script:argsFile -Raw | ConvertFrom-Json
        $forwarded.Verb | Should -Be 'install'
        $forwarded.DryRun | Should -BeTrue
        $forwarded.Backup | Should -BeTrue
        $forwarded.Extra | Should -Be @('vs')
        $forwarded.Distro | Should -Be 'Arch'
        $forwarded.NoAutostart | Should -BeTrue
    }
    It 'forwards -NoWsl and -WslUser' {
        & $script:bootstrap -DotScript $script:fake -NoWsl -WslUser ada *> $null
        $forwarded = Get-Content -LiteralPath $script:argsFile -Raw | ConvertFrom-Json
        $forwarded.NoWsl | Should -BeTrue
        $forwarded.WslUser | Should -Be 'ada'
    }
    It 'forwards no flags by default' {
        & $script:bootstrap -DotScript $script:fake *> $null
        $forwarded = Get-Content -LiteralPath $script:argsFile -Raw | ConvertFrom-Json
        $forwarded.DryRun | Should -BeFalse
        $forwarded.Backup | Should -BeFalse
        $forwarded.NoWsl | Should -BeFalse
        $forwarded.WslUser | Should -BeNullOrEmpty
    }
    It 'rejects unsupported Windows versions before invoking dot.ps1' {
        function Test-Windows11 { $false }
        (& $script:bootstrap -DotScript $script:fake 2>&1 | Out-String) | Should -Match 'Windows 11 ist erforderlich'
        $LASTEXITCODE | Should -Be 1
        Test-Path -LiteralPath $script:argsFile | Should -BeFalse
        function Test-Windows11 { $true }
    }
    It 'fails with a clear error when winget is missing' {
        function Test-Winget { $false }
        { & $script:bootstrap -DotScript $script:fake -ErrorAction Stop 2>&1 | Out-Null; if ($LASTEXITCODE) { throw "exit $LASTEXITCODE" } } | Should -Throw
        Test-Path -LiteralPath $script:argsFile | Should -BeFalse
        (& $script:bootstrap -DotScript $script:fake 2>&1 | Out-String) | Should -Match 'winget.exe'
        function Test-Winget { $true }
    }
    Context 'standalone (no local checkout)' {
        BeforeAll {
            # A copy without windows/dot.ps1 next to it forces the remote path.
            $script:standalone = Join-Path $TestDrive 'solo/bootstrap.ps1'
            New-Item -ItemType Directory -Path (Split-Path $script:standalone) | Out-Null
            Copy-Item -LiteralPath $script:bootstrap -Destination $script:standalone
            $script:cloneCalls = 0
            $script:gitInstalls = 0
            $script:gitPresent = $true
            function Test-Git { $script:gitPresent }
            function Install-Git { $script:gitInstalls++; $script:gitPresent = $true }
            function Invoke-GitClone([string]$Url, [string]$Path) {
                $script:cloneCalls++
                New-Item -ItemType Directory -Path (Join-Path $Path 'windows'), (Join-Path $Path '.git') -Force | Out-Null
                Copy-Item -LiteralPath $script:fake -Destination (Join-Path $Path 'windows/dot.ps1')
            }
        }
        BeforeEach {
            $script:cloneCalls = 0; $script:gitInstalls = 0; $script:gitPresent = $true
            $script:target = Join-Path $TestDrive 'clone'
            Remove-Item -LiteralPath $script:target -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath (Join-Path $script:target 'windows/args.json') -ErrorAction SilentlyContinue
        }
        It 'clones and runs dot.ps1 install with forwarded parameters' {
            & $script:standalone -TargetDir $script:target -Backup -NoWsl *> $null
            $script:cloneCalls | Should -Be 1
            $script:gitInstalls | Should -Be 0
            $forwarded = Get-Content -LiteralPath (Join-Path $script:target 'windows/args.json') -Raw | ConvertFrom-Json
            $forwarded.Verb | Should -Be 'install'
            $forwarded.Backup | Should -BeTrue
            $forwarded.NoWsl | Should -BeTrue
        }
        It 'installs Git first when git.exe is missing' {
            $script:gitPresent = $false
            & $script:standalone -TargetDir $script:target *> $null
            $script:gitInstalls | Should -Be 1
            $script:cloneCalls | Should -Be 1
        }
        It 'is idempotent on a repeat run' {
            & $script:standalone -TargetDir $script:target *> $null
            & $script:standalone -TargetDir $script:target *> $null
            $script:cloneCalls | Should -Be 1
            Test-Path -LiteralPath (Join-Path $script:target 'windows/args.json') | Should -BeTrue
        }
        It 'writes nothing on -DryRun' {
            $script:gitPresent = $false
            & $script:standalone -TargetDir $script:target -DryRun *> $null
            $script:cloneCalls | Should -Be 0
            $script:gitInstalls | Should -Be 0
            Test-Path -LiteralPath $script:target | Should -BeFalse
        }
        It 'fails on a non-empty non-Git target' {
            New-Item -ItemType Directory -Path $script:target | Out-Null
            Set-Content -LiteralPath (Join-Path $script:target 'file.txt') -Value 'x'
            (& $script:standalone -TargetDir $script:target 2>&1 | Out-String) | Should -Match 'kein Git-Klon'
            $script:cloneCalls | Should -Be 0
        }
    }
}
