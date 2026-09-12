#!/usr/bin/env bash

# Select a stable upstream asset. Never substitute a nightly release.
github_asset() {
    local repo=$1 pattern=$2 output=$3
    workspace
    download "https://api.github.com/repos/$repo/releases/latest" "$WORK_DIR/release.json"
    local url
    url=$(python3 - "$WORK_DIR/release.json" "$pattern" <<'PY'
import json, re, sys
release = json.load(open(sys.argv[1]))
if release.get('prerelease') or release.get('draft'):
    raise SystemExit('Kein stabiles Release.')
assets = [a for a in release['assets'] if re.fullmatch(sys.argv[2], a['name'])]
if len(assets) != 1:
    raise SystemExit('Kein eindeutiges stabiles Release für diese Architektur gefunden.')
print(assets[0]['browser_download_url'])
PY
    )
    download "$url" "$output"
    # Newer GitHub assets provide a SHA-256 digest; verify it when supplied.
    python3 - "$WORK_DIR/release.json" "$url" "$output" <<'PY'
import hashlib, json, sys
asset = next(a for a in json.load(open(sys.argv[1]))['assets'] if a['browser_download_url'] == sys.argv[2])
digest = asset.get('digest')
if digest and digest.startswith('sha256:'):
    with open(sys.argv[3], 'rb') as f:
        actual = hashlib.file_digest(f, 'sha256').hexdigest()
    if actual != digest.removeprefix('sha256:'):
        raise SystemExit('SHA-256-Prüfung fehlgeschlagen.')
else:
    print('Hinweis: Upstream liefert keinen SHA-256-Digest; Download ist HTTPS-gesichert.')
PY
}

neovim_compatible() {
    command -v nvim >/dev/null 2>&1 || return 1
    local version
    version=$(nvim --version | head -n 1)
    [[ $version =~ NVIM\ v([0-9]+)\.([0-9]+) ]] || return 1
    ((BASH_REMATCH[1] > 0 || BASH_REMATCH[2] >= 12))
}

install_neovim() {
    if ((DRY_RUN)); then log 'Neovim >= 0.12: stabiles offizielles Linux-Archiv nach ~/.local/opt/neovim installieren.'; return; fi
    if neovim_compatible; then log 'Neovim >= 0.12 ist vorhanden.'; return; fi
    workspace
    local arch=x86_64
    [[ $(uname -m) == aarch64 ]] && arch=arm64
    github_asset neovim/neovim "nvim-linux-$arch\\.tar\\.gz" "$WORK_DIR/nvim.tar.gz"
    mkdir -p "$WORK_DIR/neovim"
    tar -xzf "$WORK_DIR/nvim.tar.gz" --strip-components=1 -C "$WORK_DIR/neovim"
    local version
    version=$("$WORK_DIR/neovim/bin/nvim" --version | head -n 1)
    [[ $version =~ NVIM\ v([0-9]+)\.([0-9]+) ]] || die 'Ungültiges Neovim-Archiv.'
    ((BASH_REMATCH[1] > 0 || BASH_REMATCH[2] >= 12)) || die 'Das stabile Neovim-Release ist älter als 0.12; diese Konfiguration benötigt vim.pack. Kein Nightly installiert.'
    mkdir -p "$HOME/.local/opt/neovim" "$HOME/.local/bin"
    cp -a "$WORK_DIR/neovim/." "$HOME/.local/opt/neovim/"
    ln -sfn "$HOME/.local/opt/neovim/bin/nvim" "$HOME/.local/bin/nvim"
}

install_tree_sitter() {
    if ((DRY_RUN)); then log 'tree-sitter CLI >= 0.26.1: offizielles natives Release nach ~/.local/bin.'; return; fi
    local version=''
    if command -v tree-sitter >/dev/null 2>&1; then version=$(tree-sitter --version); fi
    if [[ $version =~ tree-sitter\ ([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        if ((BASH_REMATCH[1] > 0 || BASH_REMATCH[2] > 26 || (BASH_REMATCH[2] == 26 && BASH_REMATCH[3] >= 1))); then return; fi
    fi
    workspace
    local arch=x64
    [[ $(uname -m) == aarch64 ]] && arch=arm64
    github_asset tree-sitter/tree-sitter "tree-sitter-linux-$arch\\.gz" "$WORK_DIR/tree-sitter.gz"
    python3 - "$WORK_DIR/tree-sitter.gz" "$WORK_DIR/tree-sitter" <<'PY'
import gzip, shutil, sys
with gzip.open(sys.argv[1], 'rb') as source, open(sys.argv[2], 'wb') as target:
    shutil.copyfileobj(source, target)
PY
    chmod +x "$WORK_DIR/tree-sitter"
    version=$("$WORK_DIR/tree-sitter" --version)
    [[ $version =~ tree-sitter\ ([0-9]+)\.([0-9]+)\.([0-9]+) ]] || die 'Ungültiges tree-sitter-Archiv.'
    ((BASH_REMATCH[1] > 0 || BASH_REMATCH[2] > 26 || (BASH_REMATCH[2] == 26 && BASH_REMATCH[3] >= 1))) || die 'Das stabile tree-sitter-Release ist älter als die benötigte Version 0.26.1.'
    mkdir -p "$HOME/.local/bin"
    install -m 755 "$WORK_DIR/tree-sitter" "$HOME/.local/bin/tree-sitter"
}

install_wezterm() {
    if command -v wezterm >/dev/null 2>&1; then log 'WezTerm ist vorhanden.'; return; fi
    if ((DRY_RUN)); then log 'WezTerm: Fedora-Paket, sonst stabiles Upstream-AppImage (x86_64), entpackt ohne FUSE.'; return; fi
    if dnf -q list --available wezterm >/dev/null 2>&1; then
        run sudo dnf install -y wezterm
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

install_development() {
    run sudo dnf install -y dotnet-sdk-10.0
    if ! command -v starship >/dev/null 2>&1; then
        if ((!DRY_RUN)); then mkdir -p "$HOME/.local/bin"; fi
        upstream_installer starship https://starship.rs/install.sh sh --yes --bin-dir "$HOME/.local/bin"
    fi
    if ! command -v fnm >/dev/null 2>&1; then
        upstream_installer fnm https://fnm.vercel.app/install bash --install-dir "${XDG_DATA_HOME:-$HOME/.local/share}/fnm" --skip-shell
    fi
    run fnm install 24
    run fnm default 24
    # nvim-treesitter explicitly requires the native CLI rather than the npm wrapper.
    install_tree_sitter

    if ! command -v mise >/dev/null 2>&1; then
        upstream_installer mise https://mise.run sh
    fi
    if ! command -v uv >/dev/null 2>&1; then
        export UV_NO_MODIFY_PATH=1 UV_INSTALL_DIR="$HOME/.local/bin"
        upstream_installer uv https://astral.sh/uv/install.sh sh
    fi
    run uv python install 3.14
    install_neovim
    install_wezterm
    if ! command -v zed >/dev/null 2>&1; then
        upstream_installer zed https://zed.dev/install.sh sh
    fi
    if has_extra java; then
        # Keep runtime state outside the Stow configuration; use via mise exec or local config.
        run mise install java@21
        log 'Java 21 installiert. Aktivieren: mise exec java@21 -- java -version; siehe README.'
    fi
    if has_extra rust; then
        if ! command -v rustup >/dev/null 2>&1 && [[ ! -x $HOME/.cargo/bin/rustup ]]; then
            upstream_installer rustup https://sh.rustup.rs sh -y --no-modify-path --profile minimal --default-toolchain stable
        else
            local rustup_cmd=rustup
            [[ -x $HOME/.cargo/bin/rustup ]] && rustup_cmd="$HOME/.cargo/bin/rustup"
            run "$rustup_cmd" toolchain install stable --profile minimal
        fi
    fi
}
