#!/usr/bin/env bash
system_arch() {
    pkg_upgrade || return $?
    pkg_install_manifest || return $?
    pkg_ensure_aur_helper
}

system_fedora() {
    if is_wsl; then
        log 'WSL erkannt: DNF lässt den Windows-seitig bereitgestellten Linux-Kernel aus.'
    fi
    pkg_upgrade || return $?
    if has_extra rpmfusion; then
        local release variant
        if ((DRY_RUN)); then release=FEDORA_VERSION; else release=$(rpm -E %fedora); fi
        for variant in free nonfree; do
            if ((DRY_RUN)) || ! rpm -q "rpmfusion-$variant-release" >/dev/null 2>&1; then
                run sudo dnf install -y "https://download1.rpmfusion.org/$variant/fedora/rpmfusion-$variant-release-$release.noarch.rpm" || return $?
            fi
        done
    fi
    pkg_install_manifest
}

system_debian() {
    pkg_upgrade || return $?
    pkg_install_manifest
}

install_system() {
    if [[ ${DISTRO_FAMILY:-} != fedora ]] && has_extra rpmfusion; then
        log "Extra rpmfusion gilt nur für Fedora und wird auf ${DISTRO_FAMILY:-<leer>} übersprungen."
    fi
    case "${DISTRO_FAMILY:-}" in
        arch) system_arch ;;
        fedora) system_fedora ;;
        debian) system_debian ;;
        *) die "Unbekannte Distro-Familie: ${DISTRO_FAMILY:-<leer>}" ;;
    esac
}
