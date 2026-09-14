$ErrorActionPreference = 'Stop'
foreach ($file in (Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -Recurse)) {
    $tokens = $null
    $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
    if ($parseErrors) { throw ($parseErrors -join "`n") }
}
& "$PSScriptRoot/tests/installer.Tests.ps1"
