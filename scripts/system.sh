#!/usr/bin/env bash
install_system() {
    if is_wsl; then
        log 'WSL erkannt: DNF lässt den Windows-seitig bereitgestellten Linux-Kernel aus.'
    fi
    pkg_upgrade
    if has_extra rpmfusion; then
        local release
        if ((DRY_RUN)); then release=FEDORA_VERSION; else release=$(rpm -E %fedora); fi
        for variant in free nonfree; do
            if ((DRY_RUN)) || ! rpm -q "rpmfusion-$variant-release" >/dev/null 2>&1; then
                run sudo dnf install -y "https://download1.rpmfusion.org/$variant/fedora/rpmfusion-$variant-release-$release.noarch.rpm"
            fi
        done
    fi
    pkg_install_manifest
}
