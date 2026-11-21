# pi + Claude Code Konfiguration installieren (Windows, nativ)
#
#   .\install.ps1                 -> pi und Claude Code
#   .\install.ps1 -Only pi
#   .\install.ps1 -Only claude
#   .\install.ps1 -DryRun         -> nur anzeigen
#   .\install.ps1 -Backup         -> abweichende Dateien sichern und ersetzen
#
# Duenner Wrapper um windows/installer-core.ps1 (gleiche Dateiplanung wie windows/install.ps1).
# Fuer die Arbeit in WSL: stattdessen install.sh bzw. scripts/agents.py innerhalb von WSL.
[CmdletBinding()]
param([ValidateSet('all', 'pi', 'claude')] [string]$Only = 'all', [switch]$DryRun, [switch]$Backup)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $repo 'windows/installer-core.ps1')
try {
    $entries = @(Get-AgentConfigEntries $repo -Only $Only)
    Write-FilePlan @(Get-FilePlan $entries -Backup:$Backup) -DryRun:$DryRun
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
