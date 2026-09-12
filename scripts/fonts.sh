#!/usr/bin/env bash
install_fonts() {
    local version=3.4.0
    local target="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/JetBrainsMonoNerd"
    if [[ -f $target/.version && $(< "$target/.version") == "$version" && -f $target/JetBrainsMonoNerdFont-Regular.ttf ]]; then
        log 'JetBrains Mono Nerd Font ist bereits installiert.'
        return
    fi
    log "JetBrains Mono Nerd Font v$version → $target"
    if ((DRY_RUN)); then return; fi
    workspace
    download "https://github.com/ryanoasis/nerd-fonts/releases/download/v$version/JetBrainsMono.zip" "$WORK_DIR/fonts.zip"
    mkdir -p "$WORK_DIR/fonts" "$target"
    unzip -q "$WORK_DIR/fonts.zip" -d "$WORK_DIR/fonts"
    local fonts=("$WORK_DIR/fonts/"*.ttf)
    [[ -f ${fonts[0]} ]] || die 'Font-Archiv enthält keine TTF-Dateien.'
    install -m 644 "${fonts[@]}" "$target/"
    printf '%s\n' "$version" > "$target/.version"
    fc-cache -f "$target"
}
