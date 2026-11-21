#requires -Version 5.1
# One-command Windows 11 setup: pwsh -File bootstrap.ps1 [-DryRun] [-Backup] [-Extra vs] [-NoWsl] [-WslUser <Name>]
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Backup,
    [string[]]$Extra = @(),
    [string]$Distro,
    [switch]$NoAutostart,
    [switch]$NoWsl,
    [string]$WslUser,
    [string]$DotScript = (Join-Path $PSScriptRoot 'windows/dot.ps1')
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
# Defined only if the caller has not provided them (tests inject stand-ins).
if (-not (Test-Path -Path function:Test-Windows11)) {
    function Test-Windows11 {
        return ([Environment]::OSVersion.Platform -eq 'Win32NT' -and [Environment]::OSVersion.Version.Build -ge 22000)
    }
}
if (-not (Test-Path -Path function:Test-Winget)) {
    function Test-Winget { return [bool](Get-Command 'winget.exe' -ErrorAction SilentlyContinue) }
}
try {
    if (-not (Test-Windows11)) { throw 'Windows 11 ist erforderlich. Aus WSL bitte windows/install.sh verwenden.' }
    if (-not (Test-Winget)) { throw 'Voraussetzung fehlt: winget.exe (App Installer aus dem Microsoft Store installieren).' }
    $arguments = @{ Extra = $Extra }
    if ($Distro) { $arguments.Distro = $Distro }
    if ($WslUser) { $arguments.WslUser = $WslUser }
    & $DotScript install @arguments -DryRun:$DryRun -Backup:$Backup -NoAutostart:$NoAutostart -NoWsl:$NoWsl
    if ($LASTEXITCODE) { exit $LASTEXITCODE }
    if (-not $DryRun) {
        Write-Host 'Bitte jetzt ab- und wieder anmelden (Fonts, PATH, GlazeWM-Autostart).'
        Write-Host 'Spaeter aktualisieren: pwsh -File windows/dot.ps1 update'
    }
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
