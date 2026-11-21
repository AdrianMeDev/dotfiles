#!/usr/bin/env bash
install_flatpak() {
    if [[ $PROFILE == headless ]]; then
        log 'Flatpak wird im Profil headless übersprungen.'
        return 0
    fi
    run flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    local name app
    while read -r name app; do
        [[ -z $name || $name == \#* ]] && continue
        if has_extra "$name"; then run flatpak install --user --noninteractive -y flathub "$app"; fi
    done < "$REPO_DIR/manifests/flatpaks.txt"
}
