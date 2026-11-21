#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$Verb,
    [Alias('dry-run', '-dry-run')][switch]$DryRun,
    [switch]$Backup,
    [string[]]$Extra = @(),
    [string]$Distro,
    [switch]$NoAutostart
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'installer-core.ps1')
try {
    switch ($Verb) {
        'install' {
            Install-WindowsDesktop $PSScriptRoot -DryRun:$DryRun -Backup:$Backup -Extra $Extra -Distro $Distro -NoAutostart:$NoAutostart
        }
        'update' {
            Update-WindowsDesktop $PSScriptRoot -DryRun:$DryRun -Backup:$Backup -Distro $Distro -NoAutostart:$NoAutostart
        }
        'doctor' {
            $report = @(Get-DoctorReport $PSScriptRoot -Extra $Extra -Distro $Distro -NoAutostart:$NoAutostart)
            $report.Message
            if ($report.Problem -contains $true) { exit 1 }
        }
        default {
            Write-Output 'Usage: dot.ps1 install|update|doctor [-DryRun] [-Backup] [-Extra vs] [-Distro <Name>] [-NoAutostart]'
            exit 2
        }
    }
    exit 0
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
