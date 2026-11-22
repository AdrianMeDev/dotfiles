#!/usr/bin/env bash
# Läuft als root im Container: scripts/container-entry.sh <arch|fedora|debian>
set -euo pipefail

family=${1:?Distro-Familie fehlt}
((EUID == 0)) || { printf 'Muss als root laufen.\n' >&2; exit 1; }

case "$family" in
    # bat is needed to verify the theme cache below; Debian ships it as batcat.
    arch) pacman -Syu --noconfirm --needed sudo python bat ;;
    fedora) dnf install -y sudo python3 bat ;;
    debian) apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y sudo python3 bat ;;
    *) printf 'Unbekannte Distro: %s\n' "$family" >&2; exit 2 ;;
esac

useradd -m -s /bin/bash dev
printf 'dev ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/dev
chmod 0440 /etc/sudoers.d/dev

as_dev() { sudo --preserve-env=GITHUB_TOKEN -u dev -i bash -c "$1"; }

# The repository is cloned by bootstrap.sh itself (no pre-cloned checkout), into ~/dotfiles.
# shellcheck disable=SC2016 # expanded by the inner shell on purpose
dot='$HOME/dotfiles/dot/.local/bin/dot'
bootstrap='bash -s -- --repo /dotfiles'

# /dotfiles is a read-only mount owned by another user, and git only reads
# safe.directory from config files; use ~/.config/git/config rather than
# ~/.gitconfig because ~/.gitconfig is a Stow link of the dotfiles.
# shellcheck disable=SC2016 # expanded by the inner shell on purpose
as_dev 'mkdir -p "$HOME/.config/git" && printf "[safe]\n\tdirectory = *\n" > "$HOME/.config/git/config"'

# bootstrap.sh --dry-run (piped like curl | bash) must not write anything below $HOME.
# shellcheck disable=SC2016 # expanded by the inner shell on purpose
snapshot() { as_dev 'find "$HOME" -printf "%p %y %s %T@\n" | sort'; }
before=$(snapshot)
preview=$(as_dev "$bootstrap --dry-run < /dotfiles/bootstrap.sh")
printf '%s\n' "$preview"
grep -qF "Distro-Familie: $family" <<< "$preview" || { printf 'bootstrap.sh --dry-run: Familie %s nicht erkannt.\n' "$family" >&2; exit 1; }
grep -qF 'git' <<< "$preview" || { printf 'bootstrap.sh --dry-run: git-Installation fehlt in der Vorschau.\n' >&2; exit 1; }
[[ $before == "$(snapshot)" ]] || { printf 'bootstrap.sh --dry-run hat Dateien geschrieben.\n' >&2; exit 1; }
! as_dev 'command -v git >/dev/null' || { printf 'bootstrap.sh --dry-run hat git installiert.\n' >&2; exit 1; }

for run in 1 2; do
    printf '==> bootstrap.sh (Lauf %s)\n' "$run"
    as_dev "$bootstrap < /dotfiles/bootstrap.sh"
    # Neither run may silently replace existing files with backups.
    # shellcheck disable=SC2016 # expanded by the inner shell on purpose
    backups=$(as_dev 'find "$HOME/.local/state/dotfiles/backups" -mindepth 1 -print 2>/dev/null || true')
    [[ -z $backups ]] || { printf 'bootstrap.sh (Lauf %s) hat Backups erzeugt: %s\n' "$run" "$backups" >&2; exit 1; }
    if ((run == 1)); then
        # shellcheck disable=SC2016 # expanded by the inner shell on purpose
        as_dev 'git --version && git -C "$HOME/dotfiles" rev-parse --verify HEAD' >/dev/null
        # shellcheck disable=SC2016 # expanded by the inner shell on purpose
        repo_state=$(as_dev 'git -C "$HOME/dotfiles" rev-parse HEAD; git -C "$HOME/dotfiles" status --porcelain')
    else
        # shellcheck disable=SC2016 # expanded by the inner shell on purpose
        [[ $repo_state == "$(as_dev 'git -C "$HOME/dotfiles" rev-parse HEAD; git -C "$HOME/dotfiles" status --porcelain')" ]] || {
            printf 'Zweiter bootstrap.sh hat den Klon verändert.\n' >&2
            exit 1
        }
    fi
done

printf '==> Werkzeuge prüfen\n'
as_dev 'zsh -c "command -v dot && node --version && uv --version"'
as_dev 'zsh -c "claude --version && pi --version"'
as_dev 'zsh -c "eza --version && yazi --version && tldr --version && just --version && lazydocker --version"'

printf '==> Bootstrap-Links prüfen\n'
sudo --preserve-env=GITHUB_TOKEN -u dev -i bash -s <<'EOF'
    set -euo pipefail
    for rel in dot/.local/bin/dot zsh/.zshenv mise/.config/mise/config.toml; do
        link="$HOME/${rel#*/}"
        [[ -L $link && $(readlink -f "$link") == "$HOME/dotfiles/$rel" ]] || {
            printf 'Bootstrap-Link zeigt nicht in den Klon: %s\n' "$link" >&2
            exit 1
        }
    done
EOF

printf '==> Agent-Config prüfen\n'
sudo --preserve-env=GITHUB_TOKEN -u dev -i bash -s <<'EOF'
    set -euo pipefail
    for f in .claude/CLAUDE.md .claude/settings.json .claude/skills/next/SKILL.md \
        .pi/agent/AGENTS.md .pi/agent/settings.json .pi/agent/models.json \
        .pi/agent/themes/tokyo-night.json .pi/agent/prompts/next.md .pi/agent/skills/next/SKILL.md; do
        [[ -f $HOME/$f ]] || { printf 'Agent-Datei fehlt: %s\n' "$f" >&2; exit 1; }
    done
    # The theme is rendered (copied), not Stowed: it must equal the repo source.
    cmp -s "$HOME/.pi/agent/themes/tokyo-night.json" "$HOME/dotfiles/agent-config"/pi/themes/tokyo-night.json || {
        printf 'pi-Theme weicht vom Repo ab: ~/.pi/agent/themes/tokyo-night.json\n' >&2
        exit 1
    }
    python3 - "$HOME" <<'PY'
import json
import os
import sys
home = sys.argv[1]
with open(os.path.join(home, '.pi/agent/settings.json'), encoding='utf-8') as fh:
    settings = json.load(fh)
with open(os.path.join(home, '.pi/agent/themes/tokyo-night.json'), encoding='utf-8') as fh:
    theme = json.load(fh)
if not settings.get('theme'):
    sys.exit('pi settings.json: theme fehlt.')
if settings['theme'] != theme.get('name'):
    sys.exit(f"pi-Themeaktivierung passt nicht: settings={settings['theme']} theme={theme.get('name')}")
if theme.get('appearance') != 'dark' or not theme.get('vars') or not theme.get('colors'):
    sys.exit('pi-Theme ist unvollständig (appearance/vars/colors).')
PY
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
        [[ $target == "$HOME/dotfiles/zed-config/.config/zed/$f" ]] || {
            printf 'Zed-Link zeigt falsch: %s -> %s\n' "$link" "$target" >&2
            exit 1
        }
    done
    [[ ! -e "$HOME/README.md" && ! -e "$HOME/projects" ]] || {
        printf 'Unerwartete zed-config-Artefakte im HOME.\n' >&2
        exit 1
    }
EOF

printf '==> Theme-Links und bat-Cache prüfen\n'
sudo --preserve-env=GITHUB_TOKEN -u dev -i bash -s <<'EOF'
    set -euo pipefail
    for rel in \
        bat/.config/bat/config \
        bat/.config/bat/themes/tokyonight_night.tmTheme \
        lazygit/.config/lazygit/config.yml \
        btop/.config/btop/btop.conf \
        btop/.config/btop/themes/tokyo-night.theme \
        yazi/.config/yazi/theme.toml; do
        home_rel=${rel#*/}
        link="$HOME/$home_rel"
        [[ -L $link ]] || { printf 'Theme-Link ist kein Symlink: %s\n' "$link" >&2; exit 1; }
        target=$(readlink -f "$link")
        [[ $target == "$HOME/dotfiles/$rel" ]] || {
            printf 'Theme-Link zeigt falsch: %s -> %s\n' "$link" "$target" >&2
            exit 1
        }
    done
    # Debian installs bat as batcat and bat's PAGER/MANPAGER setup needs a hook;
    # resolve the binary like scripts/dotfiles.sh does.
    bat_cmd=$(zsh -ic 'command -v bat || command -v batcat' || true)
    [[ -n $bat_cmd ]] || { printf 'bat fehlt im PATH.\n' >&2; exit 1; }
    themes=$("$bat_cmd" --list-themes)
    grep -qF 'tokyonight_night' <<< "$themes" || {
        printf 'bat-Theme tokyonight_night fehlt in bat --list-themes.\n' >&2
        exit 1
    }
EOF

printf '==> dot zed-template prüfen\n'
sudo --preserve-env=GITHUB_TOKEN -u dev -i bash -s <<'EOF'
    set -euo pipefail
    rm -rf /tmp/x
    zsh -c "dot zed-template dotnet /tmp/x"
    for f in settings.json tasks.json debug.json; do
        cmp -s "/tmp/x/.zed/$f" "$HOME/dotfiles/zed-config/projects/dotnet/.zed/$f" || {
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

printf '==> Hyprland-Links und desktop/theme-Vorschau prüfen\n'
sudo --preserve-env=GITHUB_TOKEN -u dev -i bash -s <<'EOF'
    set -euo pipefail
    for f in hyprland.lua bindings.lua media.lua; do
        link="$HOME/.config/hypr/$f"
        [[ -L $link ]] || { printf 'Hypr-Link ist kein Symlink: %s\n' "$link" >&2; exit 1; }
        target=$(readlink -f "$link")
        [[ $target == "$HOME/dotfiles/hypr/.config/hypr/$f" ]] || {
            printf 'Hypr-Link zeigt falsch: %s -> %s\n' "$link" "$target" >&2
            exit 1
        }
    done
EOF
if [[ $family != debian ]]; then
    # The container is headless, so force the desktop profile; the preview must write nothing.
    before=$(snapshot)
    for module in desktop theme; do
        preview=$(as_dev "$dot install --only $module --profile desktop --dry-run")
        printf '%s\n' "$preview"
        grep -qF 'Profil: desktop' <<< "$preview" || { printf 'dot install --only %s: Profil desktop nicht gesetzt.\n' "$module" >&2; exit 1; }
    done
    [[ $before == "$(snapshot)" ]] || { printf 'desktop/theme --dry-run hat Dateien geschrieben.\n' >&2; exit 1; }
fi

printf '==> corne-Vorschau prüfen\n'
before=$(snapshot)
sys_before=$(find /etc -printf '%p %y %s %T@\n' | sort)
preview=$(as_dev "$dot install --only corne --profile desktop --dry-run")
printf '%s\n' "$preview"
grep -qF 'Profil: desktop' <<< "$preview" || { printf 'dot install --only corne: Profil desktop nicht gesetzt.\n' >&2; exit 1; }
grep -qF 'vial' <<< "$preview" || { printf 'dot install --only corne: Vial fehlt in der Vorschau.\n' >&2; exit 1; }
[[ $before == "$(snapshot)" && $sys_before == "$(find /etc -printf '%p %y %s %T@\n' | sort)" ]] || {
    printf 'corne --dry-run hat Dateien geschrieben.\n' >&2
    exit 1
}

printf '==> dot update\n'
as_dev 'zsh -c "dot update --dry-run"'
as_dev 'zsh -c "dot update"'

printf '==> dot doctor\n'
as_dev 'zsh -c "dot doctor"'

if [[ $family == arch ]]; then
    printf '==> windows/wsl-bootstrap.sh --dry-run prüfen\n'
    sys_snapshot() { find /etc /home -printf '%p %y %s %T@\n' | sort; }
    sys_before=$(sys_snapshot)
    wsl_preview=$(/dotfiles/windows/wsl-bootstrap.sh --user wsltest --repo /dotfiles --dry-run)
    printf '%s\n' "$wsl_preview"
    grep -qF 'DRY RUN: es wird nichts geändert.' <<< "$wsl_preview" || {
        printf 'wsl-bootstrap.sh --dry-run: DRY-RUN-Ausgabe fehlt.\n' >&2
        exit 1
    }
    [[ $sys_before == "$(sys_snapshot)" ]] || {
        printf 'wsl-bootstrap.sh --dry-run hat Dateien geschrieben.\n' >&2
        exit 1
    }
fi
