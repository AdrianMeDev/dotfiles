# Run only on Windows; never touches the real Fonts key.
#requires -Version 5.1
$ErrorActionPreference = 'Stop'
if ([Environment]::OSVersion.Platform -ne 'Win32NT') {
    Write-Host 'SKIP: Windows HKCU registry integration requires Windows'
    return
}
. "$PSScriptRoot/../installer-core.ps1"
function Assert($Condition, $Message) { if (-not $Condition) { throw "FAIL: $Message" } }
$subKey = 'Software\DotfilesRegistryTests\' + [guid]::NewGuid().ToString('N')
$backupDirectory = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
$native = ${function:Invoke-Native}
try {
    $entries = @([pscustomobject]@{
        Path = 'C:\Fonts\IoskeleyMonoTermNerdFontMono-Regular.ttf'
        RegistryName = 'IoskeleyMonoTermNerdFontMono-Regular (TrueType)'
    })
    $plan = @(Get-FontRegistryPlan $entries $subKey)
    Assert ($plan[0].Action -eq 'Create') 'missing key'
    Write-FontRegistryPlan $plan $subKey $backupDirectory
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($subKey, $true)
    try { $key.SetValue('Foreign font', 'preserve'); $key.SetValue($plan[0].Name, 'old') } finally { $key.Dispose() }
    Assert ($null -eq (Read-FontRegistryValue $subKey 'missing')) 'missing value'
    $plan = @(Get-FontRegistryPlan $entries $subKey -Backup)
    function Invoke-Native { throw 'backup failed' }
    try { Write-FontRegistryPlan $plan $subKey $backupDirectory; throw 'expected backup failure' }
    catch { Assert ($_.Exception.Message -eq 'backup failed') 'backup failure propagation' }
    Assert ((Read-FontRegistryValue $subKey $plan[0].Name).Value -eq 'old') 'write before backup'
    ${function:Invoke-Native} = $native
    Write-FontRegistryPlan $plan $subKey $backupDirectory
    Assert ((Get-FontRegistryPlan $entries $subKey).Action -eq 'Skip') 'repeat registry write'
    Assert ((Read-FontRegistryValue $subKey 'Foreign font').Value -eq 'preserve') 'foreign entry lost'
    $saved = @(Get-ChildItem $backupDirectory -Filter '*.reg')
    Assert ($saved.Count -eq 1) 'registry backup missing'
    Assert ((Get-Content $saved[0].FullName -Raw) -match '"old"') 'backup must contain original value'
    Write-Host 'PASS: Windows HKCU registry integration'
} finally {
    ${function:Invoke-Native} = $native
    [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($subKey, $false)
    if (Test-Path $backupDirectory) { Remove-Item $backupDirectory -Recurse -Force }
}
