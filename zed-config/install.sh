#!/usr/bin/env bash
# Zed-Konfiguration installieren (Linux / WSL)
#
#   ./install.sh                       → globale Dateien nach ~/.config/zed (mit Backup)
#   ./install.sh angular ~/code/shop   → Projektvorlage (.zed/) in ein Projekt kopieren
#   ./install.sh django  ~/code/api
#   ./install.sh dotnet  ~/code/backend
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -ge 2 ]]; then
  kind="$1"; target="$2"
  tpl="$SRC/projects/$kind/.zed"
  [[ -d "$tpl" ]] || { echo "Unbekannte Vorlage: $kind (angular | django | dotnet)"; exit 1; }
  mkdir -p "$target/.zed"
  for f in "$tpl"/*.json; do
    name="$(basename "$f")"
    if [[ -e "$target/.zed/$name" ]]; then
      cp "$target/.zed/$name" "$target/.zed/$name.bak.$(date +%Y%m%d%H%M%S)"
    fi
    cp "$f" "$target/.zed/$name"
  done
  echo "✓ Vorlage '$kind' nach $target/.zed kopiert"
  exit 0
fi

DEST="${XDG_CONFIG_HOME:-$HOME/.config}/zed"
mkdir -p "$DEST"
stamp="$(date +%Y%m%d%H%M%S)"
for name in settings.json keymap.json tasks.json debug.json; do
  if [[ -e "$DEST/$name" ]]; then
    cp "$DEST/$name" "$DEST/$name.bak.$stamp"
  fi
  cp "$SRC/$name" "$DEST/$name"
done
echo "✓ Globale Konfiguration nach $DEST installiert (Backups: *.bak.$stamp)"
