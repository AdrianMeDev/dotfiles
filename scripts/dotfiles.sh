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

install_dotfiles() {
    if ((DRY_RUN)); then
        log 'Git-Identität lokal erfassen, ggf. Konflikte sichern und Stow-Pakete verlinken.'
        log "Stow-Ziel: $HOME (keine Verzeichnisfaltung)."
        log 'Nach erfolgreicher Verlinkung eigene alte Fish-Dateilinks entfernen.'
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
    chmod 700 "$HOME/.ssh"
    log 'Dotfiles verlinkt. Private Overrides bleiben außerhalb des Repos.'
}
