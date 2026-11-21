#!/usr/bin/env bash

capture_git_identity() {
    local current_name current_email
    current_name=$(git config --global --includes --get user.name || true)
    current_email=$(git config --global --includes --get user.email || true)
    if [[ -n $current_name && -n $current_email ]]; then
        IDENTITY_NAME=$current_name IDENTITY_EMAIL=$current_email
        return
    fi
    IDENTITY_NAME=$current_name IDENTITY_EMAIL=$current_email
    if [[ ! -t 0 ]]; then
        log 'Git-Identität unvollständig; später ./install.sh --only dotfiles im Terminal ausführen.'
        return
    fi
    local input
    while [[ -z $IDENTITY_NAME ]]; do
        read -r -p 'Git-Benutzername: ' input || break
        IDENTITY_NAME=$input
    done
    while [[ -z $IDENTITY_EMAIL ]]; do
        read -r -p 'Git-E-Mail: ' input || break
        IDENTITY_EMAIL=$input
    done
}

save_git_identity() {
    local target="$HOME/.gitconfig-local"
    [[ ! -L $target ]] || die 'Git-Identität darf nicht über einen Symlink geschrieben werden.'
    # git config writes are atomic; umask also protects the temporary lock file.
    (
        umask 077
        if [[ -n $IDENTITY_NAME ]]; then git config --file "$target" user.name "$IDENTITY_NAME"; fi
        if [[ -n $IDENTITY_EMAIL ]]; then git config --file "$target" user.email "$IDENTITY_EMAIL"; fi
        if [[ -f $target ]]; then chmod 600 "$target"; fi
    )
}

rebuild_bat_cache() {
    local bat_cmd
    bat_cmd=$(command -v bat || command -v batcat || true)
    [[ -n $bat_cmd ]] || return 0
    local source="$HOME/.config/bat/themes/tokyonight_night.tmTheme"
    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/bat"
    [[ -e $source ]] || return 0
    if [[ -f $cache_dir/themes.bin && ! $source -nt $cache_dir/themes.bin ]]; then
        return 0
    fi
    run "$bat_cmd" cache --build
}

offer_zsh_login_shell() {
    local user current zsh_path answer
    user=$(id -un)
    current=$(getent passwd "$user" 2>/dev/null | cut -d: -f7 || true)
    [[ -n $current ]] || current=${SHELL:-}
    [[ ${current##*/} != zsh ]] || return 0
    zsh_path=$(command -v zsh || true)
    [[ -n $zsh_path ]] || return 0
    grep -qxF -- "$zsh_path" "${SHELLS_FILE:-/etc/shells}" 2>/dev/null || return 0
    if [[ ! -t 0 ]] || ! have chsh; then
        log "Login-Shell ist nicht zsh; manuell wechseln: chsh -s $zsh_path"
        return 0
    fi
    read -r -p "Login-Shell auf $zsh_path umstellen? [j/N] " answer || return 0
    [[ $answer == [jJyY]* ]] || return 0
    run chsh -s "$zsh_path" || log "chsh fehlgeschlagen; manuell wiederholen: chsh -s $zsh_path"
}

install_dotfiles() {
    if ((DRY_RUN)); then
        log 'Git-Identität lokal erfassen, ggf. Konflikte sichern und Stow-Pakete verlinken.'
        log "Stow-Ziel: $HOME (keine Verzeichnisfaltung)."
        log 'Nach erfolgreicher Verlinkung eigene alte Fish-Dateilinks entfernen.'
        log 'Falls die Login-Shell nicht zsh ist: Wechsel per chsh -s anbieten (nur im Terminal, nach Bestätigung).'
        return
    fi
    capture_git_identity
    local flags=()
    ((BACKUP)) && flags+=(--backup)
    python3 "$REPO_DIR/scripts/links.py" "${flags[@]}"
    local packages=()
    mapfile -t packages < "$REPO_DIR/manifests/stow.txt"
    run stow --dir "$REPO_DIR" --target "$HOME" --no-folding --simulate "${packages[@]}"
    save_git_identity
    run stow --dir "$REPO_DIR" --target "$HOME" --no-folding "${packages[@]}"
    python3 "$REPO_DIR/scripts/links.py" --remove-legacy-fish-links
    rebuild_bat_cache
    offer_zsh_login_shell
    chmod 700 "$HOME/.ssh"
    log 'Dotfiles verlinkt. Private Overrides bleiben außerhalb des Repos.'
}
