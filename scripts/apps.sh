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

install_apps() {
    if [[ ${PROFILE:-desktop} == headless ]]; then log 'Profil headless: GUI-Apps (WezTerm, Zed) werden übersprungen.'; return; fi
    install_wezterm
    install_zed
}
