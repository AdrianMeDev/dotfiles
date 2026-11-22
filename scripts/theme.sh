#!/usr/bin/env bash

# GTK settings are a starting point: copied once, never linked, so KDE's GTK sync cannot write into the repo.
theme_copy_gtk() {
    local version file src target stamp='' backups
    for version in 3 4; do
        for file in settings.ini gtk.css; do
            src=$REPO_DIR/theme/gtk-$version.0/$file
            target=${XDG_CONFIG_HOME:-$HOME/.config}/gtk-$version.0/$file
            if [[ -L $target ]]; then
                # Old Stow link (dangling after the move): migrate to a real file.
                run rm -f -- "$target"
            elif [[ -e $target ]]; then
                cmp -s -- "$src" "$target" && continue
                if ((!${BACKUP:-0})); then
                    log "$target weicht ab und bleibt unverändert (KDE oder manuell geändert). Mit --backup wird sie gesichert und ersetzt."
                    continue
                fi
                [[ -n $stamp ]] || stamp=$(date +%Y%m%d-%H%M%S)
                backups=$HOME/.local/state/dotfiles/backups/gtk-$stamp/gtk-$version.0
                run mkdir -p "$backups"
                run cp -a -- "$target" "$backups/$file"
            fi
            run install -D -m 0644 "$src" "$target"
        done
    done
}

install_theme() {
    if [[ $PROFILE != desktop ]] || is_wsl || [[ $DISTRO_FAMILY == debian ]]; then
        log 'Desktop-Theme wird übersprungen (benötigt Arch/Fedora im Desktop-Profil außerhalb von WSL).'
        return 0
    fi

    local logical group pkg packages=()
    while IFS=$'\t' read -r logical group _; do
        [[ $group == hypr && $logical == theme-* ]] || continue
        while IFS= read -r pkg; do
            [[ $logical != theme-bibata ]] || pkg="aur:$pkg"
            packages+=("$pkg")
        done < <(pkg_names "$logical")
    done < "$PKG_MANIFEST"
    pkg_install "${packages[@]}" || return $?

    local cursor=Bibata-Modern-Classic icons="${XDG_DATA_HOME:-$HOME/.local/share}/icons"
    if [[ $DISTRO_FAMILY == fedora && ! -f $icons/$cursor/cursors/left_ptr ]]; then
        local url="https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/$cursor.tar.xz"
        log "Bibata-Cursor installieren: $url → $icons/$cursor"
        if ((!DRY_RUN)); then
            workspace
            download "$url" "$WORK_DIR/bibata.tar.xz"
            tar -xJf "$WORK_DIR/bibata.tar.xz" -C "$WORK_DIR"
            [[ -f $WORK_DIR/$cursor/cursors/left_ptr ]] || die 'Ungültiges Bibata-Archiv.'
            mkdir -p "$icons"
            cp -aT "$WORK_DIR/$cursor" "$icons/$cursor"
        fi
    fi

    theme_copy_gtk

    local interface=org.gnome.desktop.interface
    if ((DRY_RUN)) || { have gsettings && grep -qxF "$interface" <(gsettings list-schemas 2>/dev/null); }; then
        run gsettings set "$interface" color-scheme prefer-dark
        run gsettings set "$interface" gtk-theme adw-gtk3-dark
        run gsettings set "$interface" icon-theme Papirus-Dark
        run gsettings set "$interface" cursor-theme "$cursor"
        run gsettings set "$interface" cursor-size 24
    else
        log "gsettings oder das Schema $interface fehlt (gsettings-desktop-schemas) – GTK-Einstellungen übersprungen."
    fi

    local wallpaper="$HOME/.local/share/dotfiles/wallpaper.png"
    if [[ ! -e $wallpaper && ! -L $wallpaper ]]; then
        run python3 "$REPO_DIR/scripts/wallpaper.py" "$wallpaper"
    fi
}
