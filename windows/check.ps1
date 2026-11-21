# Parse check plus Pester 5 tests. Run: pwsh -NoProfile -File windows/check.ps1
$ErrorActionPreference = 'Stop'
$files = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -Recurse) + (Get-Item -LiteralPath "$PSScriptRoot/../bootstrap.ps1")
foreach ($file in $files) {
    $tokens = $null
    $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
    if ($parseErrors) { throw ($parseErrors -join "`n") }
}
Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop
Invoke-Pester -Path "$PSScriptRoot/tests" -CI
