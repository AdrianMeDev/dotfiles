#!/usr/bin/env bash
# Hyprland-Stack (Manifest-Gruppe hypr): nur Arch/Fedora, Profil desktop, nicht unter WSL.
HYPRLAND_MIN_VERSION=0.57

desktop_warn_version() {
    have hyprland || return 0
    local version
    version=$(hyprland --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1) || true
    [[ -n $version ]] || return 0
    if [[ $(printf '%s\n%s\n' "$HYPRLAND_MIN_VERSION" "$version" | sort -V | head -n 1) != "$HYPRLAND_MIN_VERSION" ]]; then
        printf 'Warnung: Hyprland %s ist älter als %s; die Lua-Konfiguration benötigt mindestens %s.\n' \
            "$version" "$HYPRLAND_MIN_VERSION" "$HYPRLAND_MIN_VERSION" >&2
    fi
}

install_desktop() {
    if [[ ${PROFILE:-} != desktop ]]; then
        log 'Hyprland-Stack wird im Profil headless übersprungen (--profile desktop erzwingt es).'
        return 0
    fi
    if is_wsl; then
        log 'Hyprland-Stack wird unter WSL übersprungen.'
        return 0
    fi
    case "${DISTRO_FAMILY:-}" in
        arch|fedora) ;;
        debian)
            log 'Hyprland-Stack wird auf Debian übersprungen (keine Pakete im Manifest).'
            return 0 ;;
        *) die "Unbekannte Distro-Familie: ${DISTRO_FAMILY:-<leer>}" ;;
    esac

    if [[ $DISTRO_FAMILY == fedora ]]; then
        run sudo dnf copr enable -y solopasha/hyprland || return $?
    fi
    local logical pkg packages=()
    while IFS=$'\t' read -r logical group _; do
        [[ $group == hypr && $logical != theme-* ]] || continue
        while IFS= read -r pkg; do packages+=("$pkg"); done < <(pkg_names "$logical")
    done < <(grep -v '^#' "$PKG_MANIFEST")
    pkg_install "${packages[@]}" || return $?
    desktop_warn_version
}
