#!/usr/bin/env bash
# Shared by install.sh and its modules; never enable shell tracing (identity data).
log() { printf '\n%s\n' "$*"; }
die() { printf 'Fehler: %s\n' "$*" >&2; exit 1; }
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
install_manifest() {
    local file=$1 line
    local packages=()
    while IFS= read -r line || [[ -n $line ]]; do
        [[ -z $line || $line == \#* ]] && continue
        packages+=("$line")
    done < "$REPO_DIR/manifests/$file"
    run sudo dnf install -y "${packages[@]}"
}
