#requires -Version 5.1
# Deprecated: use bootstrap.ps1 (repo root) or windows/dot.ps1 install.
[CmdletBinding()]
param([switch]$DryRun, [switch]$Backup, [string]$Distro, [switch]$NoAutostart, [string[]]$Extra = @())
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Write-Warning 'windows/install.ps1 ist veraltet; bitte bootstrap.ps1 oder windows/dot.ps1 install verwenden.'
$arguments = @{ Extra = $Extra }
if ($Distro) { $arguments.Distro = $Distro }
& (Join-Path $PSScriptRoot 'dot.ps1') install @arguments -DryRun:$DryRun -Backup:$Backup -NoAutostart:$NoAutostart
exit $LASTEXITCODE
