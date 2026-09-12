#!/usr/bin/env bash
install_system() {
    run sudo dnf upgrade --refresh -y
    if has_extra rpmfusion; then
        local release
        if ((DRY_RUN)); then release=FEDORA_VERSION; else release=$(rpm -E %fedora); fi
        for variant in free nonfree; do
            if ((DRY_RUN)) || ! rpm -q "rpmfusion-$variant-release" >/dev/null 2>&1; then
                run sudo dnf install -y "https://download1.rpmfusion.org/$variant/fedora/rpmfusion-$variant-release-$release.noarch.rpm"
            fi
        done
    fi
    install_manifest system.txt
}
