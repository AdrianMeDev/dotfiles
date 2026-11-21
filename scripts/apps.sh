#!/usr/bin/env bash

install_wezterm() {
    if command -v wezterm >/dev/null 2>&1; then log 'WezTerm ist vorhanden.'; return; fi
    if ((DRY_RUN)); then log 'WezTerm: Fedora-Paket, sonst stabiles Upstream-AppImage (x86_64), entpackt ohne FUSE.'; return; fi
    if pkg_available wezterm; then
        pkg_install wezterm
        command -v wezterm >/dev/null 2>&1 || die 'WezTerm-Paket enthält kein ausführbares wezterm.'
        return
    fi
    [[ $(uname -m) == x86_64 ]] || die 'Kein stabiles WezTerm-Paket für aarch64 verfügbar. WezTerm manuell installieren und Modul wiederholen.'
    workspace
    github_asset wezterm/wezterm 'WezTerm-.*-Ubuntu20\.04\.AppImage' "$WORK_DIR/wezterm.AppImage"
    chmod +x "$WORK_DIR/wezterm.AppImage"
    (cd "$WORK_DIR" && ./wezterm.AppImage --appimage-extract >/dev/null)
    mkdir -p "$HOME/.local/opt/wezterm" "$HOME/.local/bin" "$HOME/.local/share/applications"
    cp -a "$WORK_DIR/squashfs-root/." "$HOME/.local/opt/wezterm/"
    cat > "$HOME/.local/bin/wezterm" <<'EOF'
#!/usr/bin/env bash
exec "$HOME/.local/opt/wezterm/AppRun" "$@"
EOF
    chmod +x "$HOME/.local/bin/wezterm"
    # Desktop Exec quoting must also work when HOME contains spaces.
    python3 - <<'PY'
from pathlib import Path
home = Path.home()
exe = str(home / '.local/bin/wezterm')
exe = exe.replace('\\', '\\\\').replace('"', '\\"').replace('`', '\\`').replace('$', '\\$').replace('%', '%%')
desktop = '[Desktop Entry]\nType=Application\nName=WezTerm\nExec="' + exe + '" start\nIcon=org.wezfurlong.wezterm\nTerminal=false\nCategories=System;TerminalEmulator;\n'
(home / '.local/share/applications/org.wezfurlong.wezterm.desktop').write_text(desktop)
PY
}

install_zed() {
    if have zed || have zeditor; then
        log 'Zed ist vorhanden.'
        return
    fi
    local resolved pkgs=()
    resolved=$(pkg_names zed)
    if [[ -n $resolved ]]; then
        mapfile -t pkgs <<< "$resolved"
        pkg_install "${pkgs[@]}"
        if ((!DRY_RUN)); then
            have zed || have zeditor ||
                die 'Zed-Paket enthält kein ausführbares zed oder zeditor.'
        fi
        return
    fi
    upstream_installer zed https://zed.dev/install.sh sh
}

install_claude() {
    if have claude; then log 'Claude Code ist vorhanden.'; return; fi
    upstream_installer claude https://claude.ai/install.sh bash
}

install_pi() {
    if have pi; then log 'pi ist vorhanden.'; return; fi
    # Node comes from mise; the repo config is read before the Stow links exist.
    local -x MISE_GLOBAL_CONFIG_FILE="$REPO_DIR/mise/.config/mise/config.toml"
    run mise exec -- npm install -g @earendil-works/pi-coding-agent
    run mise reshim
}

install_ollama() {
    has_extra ollama || has_extra ollama-models || return 0
    if have ollama; then log 'Ollama ist vorhanden.'; return; fi
    if [[ ${DISTRO_FAMILY:-} == arch ]]; then
        local resolved pkgs=()
        resolved=$(pkg_names ollama)
        mapfile -t pkgs <<< "$resolved"
        pkg_install "${pkgs[@]}"
        return
    fi
    upstream_installer ollama https://ollama.com/install.sh sh
}

# Models pulled by the ollama-models extra; override with OLLAMA_MODELS (space separated).
install_ollama_models() {
    has_extra ollama-models || return 0
    local model
    for model in ${OLLAMA_MODELS:-qwen2.5-coder:7b-base}; do
        run ollama pull "$model"
    done
}

install_apps() {
    # Upstream installers also invoke mise shims before the Stow links exist.
    local -x MISE_GLOBAL_CONFIG_FILE="$REPO_DIR/mise/.config/mise/config.toml"
    install_claude
    install_pi
    install_ollama
    install_ollama_models
    if [[ ${PROFILE:-desktop} == headless ]]; then log 'Profil headless: GUI-Apps (WezTerm, Zed) werden übersprungen.'; return; fi
    install_wezterm
    install_zed
}
