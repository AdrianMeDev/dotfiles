# Zed-Konfiguration installieren (Windows)
#
#   .\install.ps1                                  -> globale Dateien nach %APPDATA%\Zed
#   .\install.ps1 -Template angular -Target C:\code\shop
#   (Für Projekte in WSL besser install.sh innerhalb von WSL verwenden.)
param(
  [ValidateSet("angular", "django", "dotnet")] [string]$Template,
  [string]$Target
)
$ErrorActionPreference = "Stop"
$src = $PSScriptRoot
$stamp = Get-Date -Format "yyyyMMddHHmmss"

if ($Template) {
  if (-not $Target) { throw "Bitte -Target <Projektordner> angeben." }
  $dest = Join-Path $Target ".zed"
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  Get-ChildItem (Join-Path $src "projects\$Template\.zed") -Filter *.json | ForEach-Object {
    $out = Join-Path $dest $_.Name
    if (Test-Path $out) { Copy-Item $out "$out.bak.$stamp" }
    Copy-Item $_.FullName $out
  }
  Write-Host "OK: Vorlage '$Template' nach $dest kopiert"
  exit 0
}

$dest = Join-Path $env:APPDATA "Zed"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
foreach ($name in "settings.json", "keymap.json", "tasks.json", "debug.json") {
  $out = Join-Path $dest $name
  if (Test-Path $out) { Copy-Item $out "$out.bak.$stamp" }
  Copy-Item (Join-Path $src $name) $out
}
Write-Host "OK: Globale Konfiguration nach $dest installiert (Backups: *.bak.$stamp)"
