#requires -Version 5.1
# One-command Windows 11 setup: pwsh -File bootstrap.ps1 [-DryRun] [-Backup] [-Extra vs] [-NoWsl] [-WslUser <Name>]
# Standalone (no checkout): irm https://raw.githubusercontent.com/AdrianMeDev/dotfiles/main/bootstrap.ps1 | iex
# Without a local windows/dot.ps1 it clones the repo to -TargetDir (default $env:USERPROFILE\dotfiles) first.
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Backup,
    [string[]]$Extra = @(),
    [string]$Distro,
    [switch]$NoAutostart,
    [switch]$NoWsl,
    [string]$WslUser,
    [string]$DotScript,
    [string]$TargetDir
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
if (-not (Test-Path -Path function:Test-Git)) {
    function Test-Git { return [bool](Get-Command 'git.exe' -ErrorAction SilentlyContinue) }
}
if (-not (Test-Path -Path function:Install-Git)) {
    function Install-Git {
        winget install --id Git.Git --exact --source winget --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE) { throw "winget install Git.Git fehlgeschlagen (Exit $LASTEXITCODE)." }
        # Make the fresh install visible in this session.
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    }
}
if (-not (Test-Path -Path function:Invoke-GitClone)) {
    function Invoke-GitClone([string]$Url, [string]$Path) {
        git clone $Url $Path
        if ($LASTEXITCODE) { throw "git clone fehlgeschlagen (Exit $LASTEXITCODE)." }
    }
}
if (-not (Test-Path -Path function:Update-GitClone)) {
    function Update-GitClone([string]$Path) {
        git -C $Path pull --ff-only
        if ($LASTEXITCODE) { throw "git pull in '$Path' fehlgeschlagen (Exit $LASTEXITCODE). Lokale Aenderungen pruefen." }
    }
}
# Under `irm | iex` the script runs inside the caller's session: `exit` would close the window.
function Stop-Bootstrap([int]$Code) {
    if ($PSCommandPath) { exit $Code }
    $global:LASTEXITCODE = $Code
}
$repoUrl = 'https://github.com/AdrianMeDev/dotfiles.git'
try {
    if (-not (Test-Windows11)) { throw 'Windows 11 ist erforderlich. Aus WSL bitte windows/install.sh verwenden.' }
    if (-not (Test-Winget)) { throw 'Voraussetzung fehlt: winget.exe (App Installer aus dem Microsoft Store installieren).' }
    if (-not $DotScript) {
        # $PSScriptRoot is empty when run via `irm | iex`.
        $local = if ($PSScriptRoot) { Join-Path $PSScriptRoot 'windows/dot.ps1' }
        if ($local -and (Test-Path -LiteralPath $local)) {
            $DotScript = $local
        } else {
            if (-not $TargetDir) { $TargetDir = Join-Path $env:USERPROFILE 'dotfiles' }
            $isClone = Test-Path -LiteralPath (Join-Path $TargetDir '.git')
            if (-not $isClone -and (Test-Path -LiteralPath $TargetDir) -and @(Get-ChildItem -LiteralPath $TargetDir -Force).Count) {
                throw "Zielverzeichnis '$TargetDir' ist nicht leer und kein Git-Klon."
            }
            $needGit = -not (Test-Git)
            if ($DryRun) {
                if ($needGit) { Write-Host 'DRY-RUN: winget install Git.Git' }
                if ($isClone) { Write-Host "DRY-RUN: git -C $TargetDir pull --ff-only" }
                else { Write-Host "DRY-RUN: git clone $repoUrl $TargetDir" }
            } else {
                if ($needGit) { Install-Git }
                if ($isClone) { Update-GitClone $TargetDir } else { Invoke-GitClone $repoUrl $TargetDir }
            }
            $DotScript = Join-Path $TargetDir 'windows/dot.ps1'
            if ($DryRun -and -not (Test-Path -LiteralPath $DotScript)) { return }
        }
    }
    $arguments = @{ Extra = $Extra }
    if ($Distro) { $arguments.Distro = $Distro }
    if ($WslUser) { $arguments.WslUser = $WslUser }
    & $DotScript install @arguments -DryRun:$DryRun -Backup:$Backup -NoAutostart:$NoAutostart -NoWsl:$NoWsl
    if ($LASTEXITCODE) { Stop-Bootstrap $LASTEXITCODE; return }
    if (-not $DryRun) {
        Write-Host 'Bitte jetzt ab- und wieder anmelden (Fonts, PATH, GlazeWM-Autostart).'
        Write-Host 'Spaeter aktualisieren: pwsh -File windows/dot.ps1 update'
    }
} catch {
    Write-Error $_ -ErrorAction Continue
    Stop-Bootstrap 1
}
