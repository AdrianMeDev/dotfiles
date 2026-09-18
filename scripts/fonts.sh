#!/usr/bin/env bash
install_fonts() {
    local version=2.1.0
    local target="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/IoskeleyMono"
    if [[ -f $target/.version && $(< "$target/.version") == "$version" &&
          -f $target/editor/IoskeleyMono-Regular.ttf &&
          -f $target/terminal/IoskeleyMonoTermNerdFontMono-Regular.ttf ]]; then
        log 'Ioskeley Mono und Ioskeley Mono Term Nerd Font sind bereits installiert.'
        return
    fi
    log "Ioskeley Mono und Ioskeley Mono Term Nerd Font v$version → $target"
    if ((DRY_RUN)); then return; fi
    workspace
    download "https://github.com/ahatem/IoskeleyMono/releases/download/v$version/IoskeleyMono.zip" \
        "$WORK_DIR/ioskeley.zip"
    download "https://github.com/ahatem/IoskeleyMono/releases/download/v$version/IoskeleyMono-Term-NerdFont.zip" \
        "$WORK_DIR/ioskeley-term-nerd.zip"
    mkdir -p "$WORK_DIR/ioskeley" "$WORK_DIR/ioskeley-term" "$target/editor" "$target/terminal"
    unzip -q "$WORK_DIR/ioskeley.zip" -d "$WORK_DIR/ioskeley"
    unzip -q "$WORK_DIR/ioskeley-term-nerd.zip" -d "$WORK_DIR/ioskeley-term"
    local editor_fonts=("$WORK_DIR/ioskeley/Normal/Unhinted/"*.ttf)
    local terminal_fonts=("$WORK_DIR/ioskeley-term/Normal/"*.ttf)
    [[ ${#editor_fonts[@]} -eq 20 && -f ${editor_fonts[0]} ]] ||
        die 'Ioskeley-Mono-Archiv enthält nicht die erwarteten 20 Editor-TTF-Dateien.'
    [[ ${#terminal_fonts[@]} -eq 20 && -f ${terminal_fonts[0]} ]] ||
        die 'Ioskeley-Term-Nerd-Font-Archiv enthält nicht die erwarteten 20 Terminal-TTF-Dateien.'
    install -m 644 "${editor_fonts[@]}" "$target/editor/"
    install -m 644 "${terminal_fonts[@]}" "$target/terminal/"
    printf '%s\n' "$version" > "$target/.version"
    fc-cache -f "$target"
}
