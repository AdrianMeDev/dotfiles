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
done

printf '==> Werkzeuge prüfen\n'
as_dev 'zsh -c "command -v dot && node --version && uv --version"'
nvim_version=$(as_dev 'zsh -c "nvim --version"')
[[ $nvim_version =~ NVIM\ v([0-9]+)\.([0-9]+) ]] || { printf 'nvim-Version nicht lesbar.\n' >&2; exit 1; }
((BASH_REMATCH[1] > 0 || BASH_REMATCH[2] >= 12)) || { printf 'nvim >= 0.12 erwartet, gefunden: %s.%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" >&2; exit 1; }

printf '==> dot update\n'
as_dev 'zsh -c "dot update --dry-run"'
as_dev 'zsh -c "dot update"'

printf '==> dot doctor\n'
as_dev 'zsh -c "dot doctor"'
