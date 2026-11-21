#!/usr/bin/env bash
# pi + Claude Code Konfiguration installieren (Linux / WSL)
#
#   ./install.sh          → pi und Claude Code
#   ./install.sh pi       → nur pi
#   ./install.sh claude   → nur Claude Code
#
# Vorhandene Dateien werden als *.bak.<zeitstempel> gesichert.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d%H%M%S)"
WHAT="${1:-all}"

copy() {  # copy <quelle> <ziel>
  mkdir -p "$(dirname "$2")"
  if [[ -e "$2" ]]; then cp -r "$2" "$2.bak.$STAMP"; fi
  cp -r "$1" "$2"
}

install_skills() {  # install_skills <skills-ordner> [claude]
  for dir in "$SRC"/skills/*/; do
    name="$(basename "$dir")"
    # Backup außerhalb des Skills-Ordners, sonst lädt das Tool den Skill doppelt
    if [[ -e "$1/$name" ]]; then mkdir -p "$1.bak.$STAMP"; mv "$1/$name" "$1.bak.$STAMP/"; fi
    mkdir -p "$1"
    cp -r "$dir" "$1/$name"
    extra="$1/$name/claude-frontmatter.txt"
    if [[ -f "$extra" ]]; then
      # Claude-Code-Felder (context: fork, model, effort …) nach dem ersten '---' einfügen
      if [[ "${2:-}" == "claude" ]]; then
        awk -v f="$extra" 'NR==1 && /^---$/ {print; while ((getline l < f) > 0) print l; next} {print}' \
          "$1/$name/SKILL.md" > "$1/$name/SKILL.md.tmp" && mv "$1/$name/SKILL.md.tmp" "$1/$name/SKILL.md"
      fi
      rm "$extra"
    fi
  done
}

retire() {  # alte Versionen (deutsche Skill-Namen, alter /plan-Prompt) wegsichern
  for old in "$@"; do
    if [[ -e "$old" ]]; then mkdir -p "$(dirname "$old").bak.$STAMP"; mv "$old" "$(dirname "$old").bak.$STAMP/"; fi
  done
}

if [[ "$WHAT" == "all" || "$WHAT" == "pi" ]]; then
  PI="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
  retire "$PI/skills/erklaeren" "$PI/skills/projekt-erklaeren" "$PI/prompts/plan.md"
  copy "$SRC/pi/settings.json" "$PI/settings.json"
  copy "$SRC/pi/models.json"   "$PI/models.json"
  copy "$SRC/pi/AGENTS.md"     "$PI/AGENTS.md"
  mkdir -p "$PI/prompts"
  for f in "$SRC"/pi/prompts/*.md; do copy "$f" "$PI/prompts/$(basename "$f")"; done
  install_skills "$PI/skills"
  echo "✓ pi → $PI"
fi

if [[ "$WHAT" == "all" || "$WHAT" == "claude" ]]; then
  CL="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  retire "$CL/skills/erklaeren" "$CL/skills/projekt-erklaeren"
  copy "$SRC/claude/settings.json" "$CL/settings.json"
  copy "$SRC/claude/CLAUDE.md"     "$CL/CLAUDE.md"
  install_skills "$CL/skills" claude
  echo "✓ Claude Code → $CL"
fi

echo "Backups (falls vorhanden): *.bak.$STAMP"
