# Pester 5. Runs only on Windows; never touches the real Fonts key.
BeforeDiscovery {
    $script:notWindows = [Environment]::OSVersion.Platform -ne 'Win32NT'
}

Describe 'Windows HKCU registry integration' -Skip:$script:notWindows {
    BeforeAll {
        . "$PSScriptRoot/../installer-core.ps1"
        $script:subKey = 'Software\DotfilesRegistryTests\' + [guid]::NewGuid().ToString('N')
        $script:backupDirectory = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
        $script:entries = @([pscustomobject]@{
            Path = 'C:\Fonts\IoskeleyMonoTermNerdFontMono-Regular.ttf'
            RegistryName = 'IoskeleyMonoTermNerdFontMono-Regular (TrueType)'
        })
    }
    AfterAll {
        [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($script:subKey, $false)
        if (Test-Path $script:backupDirectory) { Remove-Item $script:backupDirectory -Recurse -Force }
    }

    It 'plans Create for a missing key and writes it' {
        $plan = @(Get-FontRegistryPlan $script:entries $script:subKey)
        $plan[0].Action | Should -Be 'Create'
        Write-FontRegistryPlan $plan $script:subKey $script:backupDirectory
    }
    It 'returns null for a missing value' {
        Read-FontRegistryValue $script:subKey 'missing' | Should -BeNullOrEmpty
    }
    It 'does not write before the backup succeeded' {
        $plan = @(Get-FontRegistryPlan $script:entries $script:subKey)
        $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($script:subKey, $true)
        try { $key.SetValue('Foreign font', 'preserve'); $key.SetValue($plan[0].Name, 'old') } finally { $key.Dispose() }
        $plan = @(Get-FontRegistryPlan $script:entries $script:subKey -Backup)
        function Invoke-Native { throw 'backup failed' }
        $caught = $null
        try { Write-FontRegistryPlan $plan $script:subKey $script:backupDirectory } catch { $caught = $_ }
        $caught.Exception.Message | Should -BeExactly 'backup failed'
        (Read-FontRegistryValue $script:subKey $plan[0].Name).Value | Should -Be 'old'
    }
    It 'backs up, replaces and preserves foreign entries' {
        $plan = @(Get-FontRegistryPlan $script:entries $script:subKey -Backup)
        Write-FontRegistryPlan $plan $script:subKey $script:backupDirectory
        (Get-FontRegistryPlan $script:entries $script:subKey).Action | Should -Be 'Skip'
        (Read-FontRegistryValue $script:subKey 'Foreign font').Value | Should -Be 'preserve'
        $saved = @(Get-ChildItem $script:backupDirectory -Filter '*.reg')
        $saved.Count | Should -Be 1
        (Get-Content $saved[0].FullName -Raw) | Should -Match '"old"'
    }
}

Describe 'Windows HKCU dark mode' -Skip:$script:notWindows {
    BeforeAll {
        . "$PSScriptRoot/../installer-core.ps1"
        $script:subKey = 'Software\DotfilesRegistryTests\' + [guid]::NewGuid().ToString('N')
        $script:backupDirectory = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
    }
    AfterAll {
        [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($script:subKey, $false)
        if (Test-Path $script:backupDirectory) { Remove-Item $script:backupDirectory -Recurse -Force }
    }

    It 'creates both DWORD values as 0 and then skips' {
        $plan = @(Get-DarkModePlan $script:subKey)
        $plan.Action | Should -Be @('Create', 'Create')
        Write-DarkModePlan $plan $script:subKey $script:backupDirectory
        foreach ($name in 'AppsUseLightTheme', 'SystemUsesLightTheme') {
            $value = Read-FontRegistryValue $script:subKey $name
            $value.Value | Should -Be 0
            $value.Kind | Should -Be ([Microsoft.Win32.RegistryValueKind]::DWord)
        }
        (Get-DarkModePlan $script:subKey).Action | Should -Be @('Skip', 'Skip')
        Test-Path $script:backupDirectory | Should -BeFalse
    }
    It 'backs up and replaces light mode, keeping foreign values' {
        $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($script:subKey, $true)
        try { $key.SetValue('AppsUseLightTheme', 1, 'DWord'); $key.SetValue('Foreign', 'keep') } finally { $key.Dispose() }
        $plan = @(Get-DarkModePlan $script:subKey)
        $plan.Action | Should -Be @('Replace', 'Skip')
        Write-DarkModePlan $plan $script:subKey $script:backupDirectory
        (Read-FontRegistryValue $script:subKey 'AppsUseLightTheme').Value | Should -Be 0
        (Read-FontRegistryValue $script:subKey 'Foreign').Value | Should -Be 'keep'
        @(Get-ChildItem $script:backupDirectory -Filter 'Personalize.backup-*.reg').Count | Should -Be 1
    }
}
