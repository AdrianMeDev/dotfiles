#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
export REPO_DIR
# shellcheck source=scripts/common.sh
source "$REPO_DIR/scripts/common.sh"
# shellcheck source=scripts/detect.sh
source "$REPO_DIR/scripts/detect.sh"
# shellcheck source=scripts/pkg.sh
source "$REPO_DIR/scripts/pkg.sh"

usage() {
    cat <<'EOF'
Linux Developer Setup (als normaler Benutzer starten)
  ./install.sh [--dry-run] [--backup] [--only MODULE] [--extras LISTE] [--profile desktop|headless]
Module: system, development, flatpak, fonts, dotfiles
Extras (kommagetrennt): java, rust, rpmfusion, firefox, discord, spotify
--dry-run    Zeigt Schritte ohne Downloads, Schreibzugriffe oder sudo.
--backup     Sichert kollidierende Dateien vor dem Verlinken außerhalb des Repos.
--only       Führt genau ein Modul aus; Voraussetzungen müssen installiert sein.
--profile    Wählt desktop oder headless. Standard ist die automatische Erkennung.
--help       Zeigt diese Hilfe.
Ohne --only werden alle Module ausgeführt. Git-Identität wird lokal abgefragt.
EOF
}

DRY_RUN=0 BACKUP=0 ONLY='' EXTRAS='' PROFILE=''
while (($#)); do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --backup) BACKUP=1 ;;
        --only|--extras)
            (($# >= 2)) || die "Wert für $1 fehlt."
            if [[ $1 == --only ]]; then ONLY=$2; else EXTRAS=$2; fi
            shift ;;
        --profile)
            (($# >= 2)) || die "Wert für $1 fehlt."
            case "$2" in
                desktop|headless) PROFILE=$2 ;;
                *) die "Ungültiges Profil: $2 (erwartet: desktop oder headless)." ;;
            esac
            shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unbekannte Option: $1" ;;
    esac
    shift
done
MODULES=(system development flatpak fonts dotfiles)
if [[ -n $ONLY ]]; then
    [[ " ${MODULES[*]} " == *" $ONLY "* ]] || die "Unbekanntes Modul: $ONLY"
    MODULES=("$ONLY")
fi
IFS=',' read -r -a EXTRA_LIST <<< "$EXTRAS"
for extra in "${EXTRA_LIST[@]}"; do
    case "$extra" in java|rust|rpmfusion|firefox|discord|spotify) ;; *) die "Unbekanntes Extra: $extra" ;; esac
    case "$extra" in java|rust) owner=development ;; rpmfusion) owner=system ;; *) owner=flatpak ;; esac
    [[ -z $ONLY || $ONLY == "$owner" ]] || die "Extra $extra benötigt Modul $owner."
done

CURRENT_MODULE=preflight
on_error() {
    local code=$1 line=$2
    printf 'Fehler in Modul %s (Zeile %s, Status %s). Nach Behebung denselben Aufruf wiederholen.\n' "$CURRENT_MODULE" "$line" "$code" >&2
    exit "$code"
}
trap 'on_error "$?" "$LINENO"' ERR
trap 'if [[ -n ${WORK_DIR:-} ]]; then rm -rf -- "$WORK_DIR"; fi' EXIT

[[ -d $HOME && $HOME != / ]] || die 'HOME muss ein bestehendes Benutzerverzeichnis sein.'
[[ ${XDG_CONFIG_HOME:-$HOME/.config} == "$HOME/.config" ]] || die "Dieses Stow-Layout benötigt XDG_CONFIG_HOME=$HOME/.config."
if [[ $ONLY == dotfiles ]]; then
    DISTRO_FAMILY=$(detect_family 2>/dev/null) || DISTRO_FAMILY=unbekannt
else
    DISTRO_FAMILY=$(detect_family) || die 'Für reine Dotfiles: --only dotfiles.'
fi
[[ -n $PROFILE ]] || PROFILE=$(detect_profile)
if is_wsl; then wsl=ja; else wsl=nein; fi
log "Distro-Familie: $DISTRO_FAMILY · Profil: $PROFILE · WSL: $wsl"

if [[ $ONLY != dotfiles ]]; then
    case "$(uname -m)" in x86_64|aarch64) ;; *) die 'Unterstützte Architekturen: x86_64, aarch64.' ;; esac
    if ((!DRY_RUN)); then
        ((EUID != 0)) || die 'Bitte ohne sudo starten; Paketverwaltungsschritte verwenden sudo.'
        need sudo
        pkg_need
    fi
fi

if [[ " ${MODULES[*]} " == *' dotfiles '* ]]; then
    need python3
    flags=(--check)
    ((BACKUP)) && flags+=(--backup)
    python3 "$REPO_DIR/scripts/links.py" "${flags[@]}"
fi

# Dependencies for individually selected modules; the system module installs these.
if [[ -n $ONLY && $ONLY != system ]] && ((!DRY_RUN)); then
    case "$ONLY" in
        development) for cmd in curl tar unzip python3 git; do need "$cmd"; done ;;
        fonts) for cmd in curl unzip fc-cache; do need "$cmd"; done ;;
        flatpak) if [[ $PROFILE == desktop ]]; then need flatpak; fi ;;
        dotfiles) need stow; need git ;;
    esac
fi

export PATH="$HOME/.local/bin:${XDG_DATA_HOME:-$HOME/.local/share}/fnm:$PATH"
for CURRENT_MODULE in "${MODULES[@]}"; do
    log "Modul: $CURRENT_MODULE"
    # shellcheck source=/dev/null
    source "$REPO_DIR/scripts/$CURRENT_MODULE.sh"
    "install_$CURRENT_MODULE"
done
if ((DRY_RUN)); then log 'Vorschau abgeschlossen; keine Änderungen vorgenommen.'
else log 'Setup abgeschlossen. Neues Terminal öffnen; Hinweise und optionale Nacharbeiten stehen in README.md.'; fi
