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
