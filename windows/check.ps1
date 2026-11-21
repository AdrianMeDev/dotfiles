# Parse check plus Pester 5 tests. Run: pwsh -NoProfile -File windows/check.ps1
$ErrorActionPreference = 'Stop'
foreach ($file in (Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -Recurse)) {
    $tokens = $null
    $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
    if ($parseErrors) { throw ($parseErrors -join "`n") }
}
Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop
Invoke-Pester -Path "$PSScriptRoot/tests" -CI
