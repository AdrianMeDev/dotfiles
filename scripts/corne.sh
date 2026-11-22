#!/usr/bin/env bash
# Corne keyboard: Vial GUI plus the udev rule that lets Vial reach the keyboard without sudo.

# Official Vial rule for keyboards whose serial is "vial:f64c2b3c".
corne_udev_rule() {
    printf '%s\n' 'KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{serial}=="vial:f64c2b3c", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"'
}

corne_udev_path() { printf '%s\n' "${VIAL_UDEV_RULE:-/etc/udev/rules.d/99-vial.rules}"; }

corne_install_vial() {
    # vial-appimage installs /usr/bin/Vial; other installs provide vial.
    if have Vial || have vial; then log 'Vial ist vorhanden.'; return 0; fi
    if [[ $DISTRO_FAMILY == arch ]]; then
        local pkg pkgs=()
        while IFS= read -r pkg; do pkgs+=("aur:$pkg"); done < <(pkg_names vial)
        pkg_install "${pkgs[@]}"
        return
    fi
    if ((${DRY_RUN:-0})); then
        log 'Vial: stabiles Upstream-AppImage (x86_64) mit SHA-256-Prüfung → ~/.local/opt/vial, Wrapper ~/.local/bin/vial.'
        return 0
    fi
    [[ $(uname -m) == x86_64 ]] || die 'Kein Vial-AppImage für aarch64 verfügbar. Vial manuell installieren und Modul wiederholen.'
    workspace
    github_asset vial-kb/vial-gui 'Vial-v.*-x86_64\.AppImage' "$WORK_DIR/vial.AppImage" || return $?
    chmod +x "$WORK_DIR/vial.AppImage"
    (cd "$WORK_DIR" && ./vial.AppImage --appimage-extract >/dev/null) || return $?
    [[ -x $WORK_DIR/squashfs-root/AppRun ]] || die 'Ungültiges Vial-AppImage (AppRun fehlt).'
    mkdir -p "$HOME/.local/opt" "$HOME/.local/bin" "$HOME/.local/share/applications"
    rm -rf -- "$HOME/.local/opt/vial"
    cp -a "$WORK_DIR/squashfs-root" "$HOME/.local/opt/vial"
    cat > "$HOME/.local/bin/vial" <<'WRAPPER'
#!/usr/bin/env bash
exec "$HOME/.local/opt/vial/AppRun" "$@"
WRAPPER
    chmod +x "$HOME/.local/bin/vial"
    # Desktop Exec quoting must also work when HOME contains spaces.
    python3 - <<'PY'
from pathlib import Path
home = Path.home()
exe = str(home / '.local/bin/vial')
exe = exe.replace('\\', '\\\\').replace('"', '\\"').replace('`', '\\`').replace('$', '\\$').replace('%', '%%')
desktop = '[Desktop Entry]\nType=Application\nName=Vial\nExec="' + exe + '"\nIcon=vial\nTerminal=false\nCategories=Utility;\n'
(home / '.local/share/applications/vial.desktop').write_text(desktop)
PY
}

corne_install_udev() {
    local target dir content priv=(sudo)
    target=$(corne_udev_path)
    dir=$(dirname -- "$target")
    content=$(corne_udev_rule)
    # No sudo when running as root or when the (overridden) target is user-writable.
    while [[ ! -d $dir ]]; do dir=$(dirname -- "$dir"); done
    if ((EUID == 0)) || { [[ -w $dir ]] && [[ ! -e $target || -w $target ]]; }; then priv=(); fi

    if [[ -e $target || -L $target ]]; then
        if [[ -f $target && ! -L $target && $(< "$target") == "$content" ]]; then
            log "udev-Regel ist aktuell: $target"
            return 0
        fi
        if ((!${BACKUP:-0})); then
            die "$target weicht von der Vial-Regel ab. Mit --backup wird sie gesichert und ersetzt."
        fi
        local backups
        backups=$HOME/.local/state/dotfiles/backups/corne-$(date +%Y%m%d-%H%M%S)
        run mkdir -p "$backups"
        run cp -a -- "$target" "$backups/$(basename -- "$target")"
    fi
    printf '%s\n' "$content" | run "${priv[@]}" install -D -m 0644 /dev/stdin "$target"
    if ((!${DRY_RUN:-0})) && ! have udevadm; then
        log 'udevadm fehlt; die Regel wird nach dem nächsten Neustart wirksam.'
        return 0
    fi
    run "${priv[@]}" udevadm control --reload-rules
    run "${priv[@]}" udevadm trigger --subsystem-match=hidraw --action=add
}

install_corne() {
    if [[ ${PROFILE:-desktop} != desktop ]] || is_wsl; then
        log 'Corne wird übersprungen (benötigt das Desktop-Profil außerhalb von WSL).'
        return 0
    fi
    case "${DISTRO_FAMILY:-}" in
        arch|fedora|debian) ;;
        *) die "Unbekannte Distro-Familie: ${DISTRO_FAMILY:-<leer>}" ;;
    esac
    corne_install_vial || return $?
    corne_install_udev
}
