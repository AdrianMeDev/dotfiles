#!/usr/bin/env bash
# Läuft als root im Container: scripts/container-entry.sh <arch|fedora|debian>
set -euo pipefail

family=${1:?Distro-Familie fehlt}
((EUID == 0)) || { printf 'Muss als root laufen.\n' >&2; exit 1; }

case "$family" in
    arch) pacman -Syu --noconfirm --needed sudo python ;;
    fedora) dnf install -y sudo python3 ;;
    debian) apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y sudo python3 ;;
    *) printf 'Unbekannte Distro: %s\n' "$family" >&2; exit 2 ;;
esac

useradd -m -s /bin/bash dev
printf 'dev ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/dev
chmod 0440 /etc/sudoers.d/dev

as_dev() { sudo --preserve-env=GITHUB_TOKEN -u dev -i bash -c "$1"; }

dot=/dotfiles/dot/.local/bin/dot

# --dry-run must not write anything below $HOME.
# shellcheck disable=SC2016 # expanded by the inner shell on purpose
snapshot() { as_dev 'find "$HOME" -printf "%p %y %s %T@\n" | sort'; }
before=$(snapshot)
preview=$(as_dev "$dot install --dry-run")
printf '%s\n' "$preview"
grep -qF "Distro-Familie: $family" <<< "$preview" || { printf 'dot install --dry-run: Familie %s nicht erkannt.\n' "$family" >&2; exit 1; }
[[ $before == "$(snapshot)" ]] || { printf 'dot install --dry-run hat Dateien geschrieben.\n' >&2; exit 1; }

for run in 1 2; do
    printf '==> dot install (Lauf %s)\n' "$run"
    as_dev "$dot install"
    # The second run must be a no-op: no backup directory may have been created.
    if ((run == 1)); then
        # shellcheck disable=SC2016 # expanded by the inner shell on purpose
        as_dev 'rm -rf "$HOME/.local/state/dotfiles/backups"'
    fi
done
# shellcheck disable=SC2016 # expanded by the inner shell on purpose
backups=$(as_dev 'ls -A "$HOME/.local/state/dotfiles/backups" 2>/dev/null || true')
[[ -z $backups ]] || { printf 'Zweiter dot install hat Backups erzeugt: %s\n' "$backups" >&2; exit 1; }

printf '==> Werkzeuge prüfen\n'
as_dev 'zsh -c "command -v dot && node --version && uv --version"'
as_dev 'zsh -c "claude --version && pi --version"'

printf '==> Agent-Config prüfen\n'
sudo --preserve-env=GITHUB_TOKEN -u dev -i bash -s <<'EOF'
    set -euo pipefail
    for f in .claude/CLAUDE.md .claude/settings.json .claude/skills/next/SKILL.md \
        .pi/agent/AGENTS.md .pi/agent/settings.json .pi/agent/models.json \
        .pi/agent/prompts/next.md .pi/agent/skills/next/SKILL.md; do
        [[ -f $HOME/$f ]] || { printf 'Agent-Datei fehlt: %s\n' "$f" >&2; exit 1; }
    done
    grep -qx 'context: fork' "$HOME/.claude/skills/next/SKILL.md" || {
        printf 'Claude-Frontmatter nicht gerendert.\n' >&2
        exit 1
    }
    ! grep -q 'context: fork' "$HOME/.pi/agent/skills/next/SKILL.md" || {
        printf 'Claude-Frontmatter im pi-Skill gefunden.\n' >&2
        exit 1
    }
    [[ -z $(find "$HOME/.claude" "$HOME/.pi" -name claude-frontmatter.txt) ]] || {
        printf 'claude-frontmatter.txt wurde mitkopiert.\n' >&2
        exit 1
    }
EOF
nvim_version=$(as_dev 'zsh -c "nvim --version"')
[[ $nvim_version =~ NVIM\ v([0-9]+)\.([0-9]+) ]] || { printf 'nvim-Version nicht lesbar.\n' >&2; exit 1; }
((BASH_REMATCH[1] > 0 || BASH_REMATCH[2] >= 12)) || { printf 'nvim >= 0.12 erwartet, gefunden: %s.%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" >&2; exit 1; }

printf '==> Zed-Links prüfen\n'
sudo --preserve-env=GITHUB_TOKEN -u dev -i bash -s <<'EOF'
    set -euo pipefail
    for f in settings.json keymap.json tasks.json debug.json; do
        link="$HOME/.config/zed/$f"
        [[ -L $link ]] || { printf 'Zed-Link ist kein Symlink: %s\n' "$link" >&2; exit 1; }
        target=$(readlink -f "$link")
        [[ $target == "/dotfiles/zed-config/.config/zed/$f" ]] || {
            printf 'Zed-Link zeigt falsch: %s -> %s\n' "$link" "$target" >&2
            exit 1
        }
    done
    [[ ! -e "$HOME/README.md" && ! -e "$HOME/projects" ]] || {
        printf 'Unerwartete zed-config-Artefakte im HOME.\n' >&2
        exit 1
    }
EOF

printf '==> dot zed-template prüfen\n'
sudo --preserve-env=GITHUB_TOKEN -u dev -i bash -s <<'EOF'
    set -euo pipefail
    rm -rf /tmp/x
    zsh -c "dot zed-template dotnet /tmp/x"
    for f in settings.json tasks.json debug.json; do
        cmp -s "/tmp/x/.zed/$f" "/dotfiles/zed-config/projects/dotnet/.zed/$f" || {
            printf 'Zed-Vorlage fehlt oder weicht ab: %s\n' "$f" >&2
            exit 1
        }
    done
    out=$(zsh -c "dot zed-template dotnet /tmp/x")
    grep -qF "bereits aktuell" <<< "$out" || {
        printf 'dot zed-template nicht idempotent: %s\n' "$out" >&2
        exit 1
    }
    rm -rf /tmp/x
EOF

printf '==> dot update\n'
as_dev 'zsh -c "dot update --dry-run"'
as_dev 'zsh -c "dot update"'

printf '==> dot doctor\n'
as_dev 'zsh -c "dot doctor"'
