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
    It 'fails with a clear error when winget is missing' {
        function Test-Winget { $false }
        { & $script:bootstrap -DotScript $script:fake -ErrorAction Stop 2>&1 | Out-Null; if ($LASTEXITCODE) { throw "exit $LASTEXITCODE" } } | Should -Throw
        Test-Path -LiteralPath $script:argsFile | Should -BeFalse
        (& $script:bootstrap -DotScript $script:fake 2>&1 | Out-String) | Should -Match 'winget.exe'
        function Test-Winget { $true }
    }
}
