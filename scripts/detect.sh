#!/usr/bin/env bash
# Distro-Familien-, WSL- und Profil-Erkennung für install.sh und seine Module.

if ! declare -F is_wsl >/dev/null 2>&1; then
    # shellcheck source=scripts/common.sh
    source "${BASH_SOURCE[0]%/*}/common.sh"
fi

detect_family() {
    local sysroot=${DOTFILES_SYSROOT:-}
    local os_release="$sysroot/etc/os-release"
    if [[ ! -r $os_release && -r "$sysroot/usr/lib/os-release" ]]; then
        os_release="$sysroot/usr/lib/os-release"
    fi
    [[ -r $os_release ]] || die "Distro nicht erkennbar: $sysroot/etc/os-release fehlt."
    [[ ! -e "$sysroot/run/ostree-booted" ]] || die 'Immutable/ostree-Systeme (z. B. Fedora Atomic/Silverblue) werden nicht unterstützt.'

    local id_pair
    id_pair=$(
        set -e
        ID=''
        ID_LIKE=''
        # shellcheck source=/dev/null
        source "$os_release"
        printf '%s|%s\n' "${ID:-}" "${ID_LIKE:-}"
    ) || die "Konnte $os_release nicht lesen."

    local os_id='' os_id_like=''
    IFS='|' read -r os_id os_id_like <<< "$id_pair"
    os_id=${os_id,,}
    os_id_like=${os_id_like,,}

    case "$os_id" in
        arch|cachyos|endeavouros|manjaro|garuda|artix)
            printf 'arch\n'
            return 0 ;;
        fedora)
            printf 'fedora\n'
            return 0 ;;
        debian|ubuntu|linuxmint|pop|raspbian)
            printf 'debian\n'
            return 0 ;;
    esac

    local token
    for token in $os_id_like; do
        case "$token" in
            arch)
                printf 'arch\n'
                return 0 ;;
            fedora)
                printf 'fedora\n'
                return 0 ;;
            debian|ubuntu)
                printf 'debian\n'
                return 0 ;;
        esac
    done

    die "Unbekannte oder nicht unterstützte Distro (ID=${os_id:-<leer>}, ID_LIKE=${os_id_like:-<leer>})."
}

detect_profile() {
    local sysroot=${DOTFILES_SYSROOT:-}

    if is_wsl; then
        printf 'headless\n'
        return 0
    fi

    if [[ -e "$sysroot/.dockerenv" || -e "$sysroot/run/.containerenv" || -n ${container:-} ]]; then
        printf 'headless\n'
        return 0
    fi

    if [[ -n ${WAYLAND_DISPLAY:-}${DISPLAY:-}${XDG_CURRENT_DESKTOP:-} || ${XDG_SESSION_TYPE:-} == wayland || ${XDG_SESSION_TYPE:-} == x11 ]]; then
        printf 'desktop\n'
        return 0
    fi

    if command -v systemctl >/dev/null 2>&1; then
        local target
        target=$(systemctl get-default 2>/dev/null || true)
        if [[ $target == graphical.target ]]; then
            printf 'desktop\n'
            return 0
        fi
    fi

    printf 'headless\n'
}
