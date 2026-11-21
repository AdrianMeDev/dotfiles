#requires -Version 5.1
[CmdletBinding()]
param([switch]$DryRun, [switch]$Backup, [string]$Distro, [switch]$NoAutostart, [string[]]$Extra = @())
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'installer-core.ps1')
try {
    Install-WindowsDesktop -SourceRoot $PSScriptRoot -DryRun:$DryRun -Backup:$Backup -Distro $Distro -NoAutostart:$NoAutostart -Extra $Extra
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
