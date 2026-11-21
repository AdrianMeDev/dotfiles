#!/usr/bin/env bash
# Löst logische Paketnamen aus manifests/packages.tsv pro Distro-Familie auf.
# Spalten: logical, group (base|desktop), arch, fedora, debian. "-" = überspringen.

if ! declare -F die >/dev/null 2>&1; then
    # shellcheck source=scripts/common.sh
    source "${BASH_SOURCE[0]%/*}/common.sh"
fi

PKG_MANIFEST=${PKG_MANIFEST:-${BASH_SOURCE[0]%/*}/../manifests/packages.tsv}

_pkg_column() {
    case "$1" in
        arch) printf '3\n' ;;
        fedora) printf '4\n' ;;
        debian) printf '5\n' ;;
        *) die "Unbekannte Distro-Familie: ${1:-<leer>}" ;;
    esac
}

# pkg_names LOGICAL [FAMILY]: Paketnamen (einer pro Zeile) für einen logischen Namen.
pkg_names() {
    local logical=${1:-} family=${2:-${DISTRO_FAMILY:-}}
    [[ -n $logical ]] || die 'pkg_names: logischer Name fehlt.'
    local col
    col=$(_pkg_column "$family") || return 1
    [[ -r $PKG_MANIFEST ]] || die "Paketmanifest fehlt: $PKG_MANIFEST"

    local name group c_arch c_fedora c_debian cell pkg found=0
    while IFS=$'\t' read -r name group c_arch c_fedora c_debian || [[ -n $name ]]; do
        [[ -z $name || $name == \#* ]] && continue
        [[ $name == "$logical" ]] || continue
        found=1
        case "$col" in 3) cell=$c_arch ;; 4) cell=$c_fedora ;; *) cell=$c_debian ;; esac
        [[ $cell == - ]] && continue
        local IFS=,
        for pkg in $cell; do printf '%s\n' "$pkg"; done
    done < "$PKG_MANIFEST"
    ((found)) || die "Unbekanntes Paket im Manifest: $logical"
}

# pkg_resolve FAMILY PROFILE: Paketnamen (einer pro Zeile); base immer, desktop nur bei Profil desktop.
pkg_resolve() {
    local family=${1:-} profile=${2:-}
    local col
    col=$(_pkg_column "$family") || return 1
    case "$profile" in
        headless|desktop) ;;
        *) die "Unbekanntes Profil: ${profile:-<leer>}" ;;
    esac
    [[ -r $PKG_MANIFEST ]] || die "Paketmanifest fehlt: $PKG_MANIFEST"

    local name group c_arch c_fedora c_debian cell pkg
    while IFS=$'\t' read -r name group c_arch c_fedora c_debian || [[ -n $name ]]; do
        [[ -z $name || $name == \#* ]] && continue
        [[ $group == base || ($group == desktop && $profile == desktop) ]] || continue
        case "$col" in 3) cell=$c_arch ;; 4) cell=$c_fedora ;; *) cell=$c_debian ;; esac
        [[ $cell == - ]] && continue
        local IFS=,
        for pkg in $cell; do printf '%s\n' "$pkg"; done
    done < "$PKG_MANIFEST"
}

# pkg_need: prüft, dass der Paketmanager der Familie vorhanden ist.
pkg_need() {
    local family=${1:-${DISTRO_FAMILY:-}} tool
    case "$family" in
        arch) tool=pacman ;;
        fedora) tool=dnf ;;
        debian) tool=apt-get ;;
        *) die "Unbekannte Distro-Familie: ${family:-<leer>}" ;;
    esac
    have "$tool" || die "Paketmanager fehlt: $tool."
}

# pkg_available PKG: 0, wenn das Paket in den Repos der Familie existiert (nur lesend).
pkg_available() {
    local pkg=${1:-}
    [[ -n $pkg ]] || die 'pkg_available: Paketname fehlt.'
    case "${DISTRO_FAMILY:-}" in
        arch) pacman -Si "$pkg" >/dev/null 2>&1 ;;
        fedora) dnf -q info "$pkg" >/dev/null 2>&1 ;;
        debian) apt-cache show "$pkg" >/dev/null 2>&1 ;;
        *) die "Unbekannte Distro-Familie: ${DISTRO_FAMILY:-<leer>}" ;;
    esac
}

# pkg_aur_helper: gibt den vorhandenen AUR-Helfer aus (paru vor yay); Status 1, wenn keiner da ist.
pkg_aur_helper() {
    local helper
    for helper in paru yay; do
        if have "$helper"; then
            printf '%s\n' "$helper"
            return 0
        fi
    done
    return 1
}

# pkg_ensure_aur_helper: setzt PKG_AUR_HELPER. Ohne Helfer: paru per pacman, sonst paru-bin per makepkg.
pkg_ensure_aur_helper() {
    local helper
    if helper=$(pkg_aur_helper); then
        PKG_AUR_HELPER=$helper
        return 0
    fi
    PKG_AUR_HELPER=paru
    log 'Kein AUR-Helfer gefunden: installiere paru.'
    if ((${DRY_RUN:-0})); then
        run sudo pacman -S --needed --noconfirm paru
        run git clone https://aur.archlinux.org/paru-bin.git paru-bin
        return 0
    fi
    if DISTRO_FAMILY=arch pkg_available paru; then
        run sudo pacman -S --needed --noconfirm paru
        return $?
    fi
    pkg_need arch
    have git || die 'Programm fehlt: git (für paru-bin).'
    have makepkg || die 'Programm fehlt: makepkg (base-devel).'
    workspace
    run git clone https://aur.archlinux.org/paru-bin.git "$WORK_DIR/paru-bin" || return $?
    (cd "$WORK_DIR/paru-bin" && run makepkg -si --noconfirm --needed)
}

# pkg_install PKG...: installiert Pakete mit dem Paketmanager der Familie; "aur:NAME" nur auf Arch.
pkg_install() {
    local family=${DISTRO_FAMILY:-}
    (($#)) || return 0
    local repo=() aur=() pkg
    for pkg in "$@"; do
        if [[ $pkg == aur:* ]]; then
            [[ $family == arch ]] || die "AUR-Paket nur auf Arch möglich: ${pkg#aur:}"
            aur+=("${pkg#aur:}")
        else
            repo+=("$pkg")
        fi
    done
    case "$family" in
        arch)
            if ((${#repo[@]})); then
                run sudo pacman -S --needed --noconfirm "${repo[@]}" || return $?
            fi
            if ((${#aur[@]})); then
                pkg_ensure_aur_helper || return $?
                run "$PKG_AUR_HELPER" -S --needed --noconfirm "${aur[@]}" || return $?
            fi
            ;;
        fedora) run sudo dnf install -y "${repo[@]}" ;;
        debian) run sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${repo[@]}" ;;
        *) die "Unbekannte Distro-Familie: ${family:-<leer>}" ;;
    esac
}

# pkg_install_manifest [FAMILY] [PROFILE]: installiert alle Pakete des Profils aus dem Manifest.
pkg_install_manifest() {
    local family=${1:-${DISTRO_FAMILY:-}} profile=${2:-${PROFILE:-}} resolved
    resolved=$(pkg_resolve "$family" "$profile") || return $?
    local packages=()
    [[ -z $resolved ]] || mapfile -t packages <<< "$resolved"
    DISTRO_FAMILY=$family pkg_install "${packages[@]}"
}

# pkg_upgrade: aktualisiert das System (unter WSL ohne Kernel-Pakete auf Fedora).
pkg_upgrade() {
    case "${DISTRO_FAMILY:-}" in
        arch) run sudo pacman -Syu --noconfirm ;;
        fedora)
            local extra=()
            if is_wsl; then extra=(--exclude='kernel*'); fi
            run sudo dnf upgrade --refresh -y "${extra[@]}"
            ;;
        debian)
            run sudo env DEBIAN_FRONTEND=noninteractive apt-get update || return $?
            run sudo env DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y
            ;;
        *) die "Unbekannte Distro-Familie: ${DISTRO_FAMILY:-<leer>}" ;;
    esac
}
