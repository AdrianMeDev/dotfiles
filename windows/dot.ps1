#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$Verb,
    [switch]$DryRun,
    [switch]$Backup,
    [string[]]$Extra = @(),
    [string]$Distro,
    [switch]$NoAutostart,
    [switch]$NoWsl,
    [string]$WslUser,
    [Parameter(ValueFromRemainingArguments)][string[]]$Rest = @()
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'installer-core.ps1')
$usage = 'Usage: dot.ps1 install|update|doctor [-DryRun] [-Backup] [-Extra vs] [-Distro <Name>] [-NoAutostart] [-NoWsl] [-WslUser <Name>]'
foreach ($arg in $Rest) {
    if ($arg -eq '--dry-run') {
        $DryRun = $true
    } else {
        Write-Output $usage
        exit 2
    }
}
try {
    switch ($Verb) {
        'install' {
            Install-WindowsDesktop $PSScriptRoot -DryRun:$DryRun -Backup:$Backup -Extra $Extra -Distro $Distro -NoAutostart:$NoAutostart -NoWsl:$NoWsl -WslUser $WslUser
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
            Write-Output $usage
            exit 2
        }
    }
    exit 0
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
