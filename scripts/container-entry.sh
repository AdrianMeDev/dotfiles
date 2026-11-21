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

as_dev() { sudo -u dev -i bash -c "$1"; }

preview=$(as_dev 'bash /dotfiles/install.sh --dry-run')
printf '%s\n' "$preview"
grep -qF "Distro-Familie: $family" <<< "$preview" || { printf 'Erwartete Familie %s nicht erkannt.\n' "$family" >&2; exit 1; }

for run in 1 2; do
    printf '==> install.sh --only system --profile desktop (Lauf %s)\n' "$run"
    as_dev 'bash /dotfiles/install.sh --only system --profile desktop'
done
