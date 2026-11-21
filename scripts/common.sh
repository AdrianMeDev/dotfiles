#!/usr/bin/env bash
# Shared by install.sh and its modules; never enable shell tracing (identity data).
log() { printf '\n%s\n' "$*"; }
die() { printf 'Fehler: %s\n' "$*" >&2; exit 1; }
# have CMD: wrapper around command -v (overridable in tests).
have() { command -v "$1" >/dev/null 2>&1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Programm fehlt: $1. Zuerst --only system ausführen."; }
has_extra() { [[ ",$EXTRAS," == *",$1,"* ]]; }
is_wsl() {
    [[ -n ${WSL_INTEROP:-}${WSL_DISTRO_NAME:-} ]] ||
        { [[ -r /proc/sys/kernel/osrelease ]] && [[ $(< /proc/sys/kernel/osrelease) == *[Mm]icrosoft* || $(< /proc/sys/kernel/osrelease) == *[Ww][Ss][Ll]* ]]; }
}
run() {
    printf '  +'; printf ' %q' "$@"; printf '\n'
    if ((!DRY_RUN)); then "$@"; fi
}
workspace() {
    if [[ -z ${WORK_DIR:-} ]]; then WORK_DIR=$(mktemp -d -t dotfiles.XXXXXXXX); fi
}
download() {
    curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 \
        --retry 3 --connect-timeout 20 --output "$2" "$1"
}
upstream_installer() {
    local name=$1 url=$2 interpreter=$3
    shift 3
    log "$name: offizieller Installer ($url)"
    if ((DRY_RUN)); then return; fi
    workspace
    download "$url" "$WORK_DIR/$name-install.sh"
    "$interpreter" "$WORK_DIR/$name-install.sh" "$@"
}

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
