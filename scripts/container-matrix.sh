#!/usr/bin/env bash
# Läuft install.sh in frischen Distro-Containern: scripts/container-matrix.sh [arch|fedora|debian ...]
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)

declare -A IMAGES=(
    [arch]=docker.io/library/archlinux:latest
    [fedora]=docker.io/library/fedora:latest
    [debian]=docker.io/library/debian:stable
)

distros=("$@")
((${#distros[@]})) || distros=(arch fedora debian)
for distro in "${distros[@]}"; do
    [[ -n ${IMAGES[$distro]:-} ]] || { printf 'Unbekannte Distro: %s (erwartet: arch, fedora, debian)\n' "$distro" >&2; exit 2; }
done

engine=${CONTAINER_ENGINE:-}
if [[ -z $engine ]]; then
    if command -v podman >/dev/null 2>&1; then engine=podman
    elif command -v docker >/dev/null 2>&1; then engine=docker
    else printf 'Weder podman noch docker gefunden.\n' >&2; exit 2; fi
fi

failed=()
passed=()
for distro in "${distros[@]}"; do
    printf '==> %s (%s)\n' "$distro" "${IMAGES[$distro]}"
    if "$engine" run --rm -v "$REPO_DIR:/dotfiles:ro,z" "${IMAGES[$distro]}" \
        bash /dotfiles/scripts/container-entry.sh "$distro"; then
        passed+=("$distro")
    else
        failed+=("$distro")
    fi
done

printf '\nZusammenfassung:\n'
for distro in "${passed[@]}"; do printf '  grün  %s\n' "$distro"; done
for distro in "${failed[@]}"; do printf '  rot   %s\n' "$distro"; done
((${#failed[@]} == 0))
