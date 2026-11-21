# pi + Claude Code Konfiguration installieren (Windows, nativ)
#
#   .\install.ps1                 -> pi und Claude Code
#   .\install.ps1 -Only pi
#   .\install.ps1 -Only claude
#
# Für die Arbeit in WSL: stattdessen install.sh innerhalb von WSL ausführen.
param([ValidateSet("all", "pi", "claude")] [string]$Only = "all")
$ErrorActionPreference = "Stop"
$src = $PSScriptRoot
$stamp = Get-Date -Format "yyyyMMddHHmmss"

function Copy-WithBackup($from, $to) {
  New-Item -ItemType Directory -Force -Path (Split-Path $to) | Out-Null
  if (Test-Path $to) { Copy-Item $to "$to.bak.$stamp" -Recurse }
  Copy-Item $from $to -Recurse -Force
}

function Install-Skills($target, [switch]$Claude) {
  New-Item -ItemType Directory -Force -Path $target | Out-Null
  Get-ChildItem (Join-Path $src "skills") -Directory | ForEach-Object {
    $dest = Join-Path $target $_.Name
    # Backup außerhalb des Skills-Ordners, sonst lädt das Tool den Skill doppelt
    if (Test-Path $dest) {
      $bak = "$target.bak.$stamp"
      New-Item -ItemType Directory -Force -Path $bak | Out-Null
      Move-Item $dest $bak
    }
    Copy-Item $_.FullName $dest -Recurse
    $extra = Join-Path $dest "claude-frontmatter.txt"
    if (Test-Path $extra) {
      if ($Claude) {
        # Claude-Code-Felder (context: fork, model, effort ...) nach dem ersten '---' einfügen
        $skill = Join-Path $dest "SKILL.md"
        $lines = [System.Collections.Generic.List[string]](Get-Content $skill -Encoding UTF8)
        $lines.InsertRange(1, [string[]](Get-Content $extra -Encoding UTF8))
        [System.IO.File]::WriteAllLines($skill, $lines, (New-Object System.Text.UTF8Encoding $false))
      }
      Remove-Item $extra
    }
  }
}

function Remove-Old([string[]]$paths) {  # alte Versionen wegsichern
  foreach ($old in $paths) {
    if (Test-Path $old) {
      $bak = "$(Split-Path $old).bak.$stamp"
      New-Item -ItemType Directory -Force -Path $bak | Out-Null
      Move-Item $old $bak
    }
  }
}

if ($Only -in "all", "pi") {
  $pi = if ($env:PI_CODING_AGENT_DIR) { $env:PI_CODING_AGENT_DIR } else { Join-Path $env:USERPROFILE ".pi\agent" }
  Remove-Old @((Join-Path $pi "skills\erklaeren"), (Join-Path $pi "skills\projekt-erklaeren"), (Join-Path $pi "prompts\plan.md"))
  foreach ($f in "settings.json", "models.json", "AGENTS.md") { Copy-WithBackup (Join-Path $src "pi\$f") (Join-Path $pi $f) }
  Get-ChildItem (Join-Path $src "pi\prompts") -Filter *.md | ForEach-Object {
    Copy-WithBackup $_.FullName (Join-Path $pi "prompts\$($_.Name)")
  }
  Install-Skills (Join-Path $pi "skills")
  Write-Host "OK: pi -> $pi"
}

if ($Only -in "all", "claude") {
  $cl = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE ".claude" }
  Remove-Old @((Join-Path $cl "skills\erklaeren"), (Join-Path $cl "skills\projekt-erklaeren"))
  Copy-WithBackup (Join-Path $src "claude\settings.json") (Join-Path $cl "settings.json")
  Copy-WithBackup (Join-Path $src "claude\CLAUDE.md") (Join-Path $cl "CLAUDE.md")
  Install-Skills (Join-Path $cl "skills") -Claude
  Write-Host "OK: Claude Code -> $cl"
}
Write-Host "Backups (falls vorhanden): *.bak.$stamp"
