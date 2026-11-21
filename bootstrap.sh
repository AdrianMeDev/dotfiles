#!/usr/bin/env bash
# One-command Linux bootstrap:
#   curl -fsSL https://raw.githubusercontent.com/AdrianMeDev/dotfiles/main/bootstrap.sh | bash
#   curl -fsSL .../bootstrap.sh | bash -s -- --dry-run --profile headless
# Standalone on purpose: it runs before the repository exists.
set -Eeuo pipefail

DEFAULT_REPO='https://github.com/AdrianMeDev/dotfiles.git'

usage() {
    cat <<'EOF'
Linux-Bootstrap: installiert git/python3 falls nötig, klont die Dotfiles und startet `dot install`.
  bootstrap.sh [--dry-run] [--repo URL] [--dir PFAD] [--branch NAME] [install-Optionen...]
--dry-run    Zeigt die Schritte, ohne zu schreiben oder sudo zu nutzen.
--repo       Git-URL (Standard: https://github.com/AdrianMeDev/dotfiles.git).
--dir        Zielverzeichnis (Standard: ~/dotfiles).
--branch     Branch für den Klon (Standard: Default-Branch des Repos).
--help       Zeigt diese Hilfe.
Alle übrigen Optionen gehen unverändert an `dot install` (z. B. --profile, --extras, --backup).
EOF
}

die() { printf 'Fehler: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# Echo the command, run it unless in dry-run mode.
run() {
    printf '  +'; printf ' %q' "$@"; printf '\n'
    if ((!DRY_RUN)); then "$@"; fi
}

# Print the distro family (arch|fedora|debian) from os-release; empty if unknown.
detect_family() {
    local sysroot=${DOTFILES_SYSROOT:-} file='' ids
    for file in "$sysroot/etc/os-release" "$sysroot/usr/lib/os-release"; do
        [[ -r $file ]] && break
        file=''
    done
    [[ -n $file ]] || return 0
    ids=$(
        # shellcheck source=/dev/null
        source "$file" 2>/dev/null
        printf '%s %s' "${ID:-}" "${ID_LIKE:-}"
    )
    local token
    for token in ${ids,,}; do
        case "$token" in
            arch|cachyos|endeavouros|manjaro|garuda|artix) printf 'arch\n'; return 0 ;;
            fedora|rhel) printf 'fedora\n'; return 0 ;;
            debian|ubuntu|linuxmint|pop|raspbian) printf 'debian\n'; return 0 ;;
        esac
    done
}

install_prerequisites() {
    local missing=() family
    have git || missing+=(git)
    have python3 || missing+=(python3)
    ((${#missing[@]})) || return 0
    family=$(detect_family)
    printf 'Fehlende Voraussetzungen: %s (Distro-Familie: %s)\n' "${missing[*]}" "${family:-unbekannt}"
    case "$family" in
        arch) run sudo pacman -S --needed --noconfirm "${missing[@]}" ;;
        fedora) run sudo dnf install -y "${missing[@]}" ;;
        debian)
            run sudo apt-get update
            run sudo apt-get install -y "${missing[@]}" ;;
        *) die "Distro nicht unterstützt. Bitte manuell installieren: ${missing[*]}" ;;
    esac
}

# Clone into $1 or reuse an existing clone untouched.
prepare_repo() {
    local repo=$1 dir=$2 branch=$3 entries
    if [[ -e $dir/.git ]]; then
        printf 'Vorhandenen Klon wiederverwendet (unverändert): %s\n' "$dir"
        return 0
    fi
    if [[ -e $dir || -L $dir ]]; then
        [[ -d $dir ]] || die "$dir existiert und ist kein Verzeichnis."
        entries=$(find "$dir" -mindepth 1 -maxdepth 1 -print -quit)
        [[ -z $entries ]] || die "$dir ist nicht leer und kein Git-Klon. Anderes Ziel mit --dir wählen."
    fi
    local args=(git clone)
    [[ -z $branch ]] || args+=(--branch "$branch")
    run "${args[@]}" "$repo" "$dir"
}

main() {
    local repo=$DEFAULT_REPO dir=$HOME/dotfiles branch='' forward=()
    DRY_RUN=0
    while (($#)); do
        case "$1" in
            --dry-run) DRY_RUN=1 ;;
            --repo|--dir|--branch)
                (($# >= 2)) || die "Wert für $1 fehlt."
                case "$1" in
                    --repo) repo=$2 ;;
                    --dir) dir=$2 ;;
                    --branch) branch=$2 ;;
                esac
                shift ;;
            -h|--help) usage; return 0 ;;
            *) forward+=("$1") ;;
        esac
        shift
    done

    [[ -n $dir && -n $repo ]] || die 'Leerer Wert für --repo oder --dir.'
    if ((EUID == 0 && !DRY_RUN)); then
        die 'Nicht als root ausführen; als normaler Benutzer mit sudo starten.'
    fi
    [[ -d $HOME && $HOME != / ]] || die 'HOME muss ein bestehendes Benutzerverzeichnis sein.'

    install_prerequisites
    prepare_repo "$repo" "$dir" "$branch"

    local dot=$dir/dot/.local/bin/dot
    if ((DRY_RUN)); then
        printf '  + %q install' "$dot"
        ((${#forward[@]})) && printf ' %q' "${forward[@]}"
        printf '\nDry-Run: nichts geschrieben.\n'
        return 0
    fi
    [[ -x $dot ]] || die "$dot fehlt oder ist nicht ausführbar."

    # Piped via curl | bash: stdin is the script; give installer prompts the terminal back.
    if [[ ! -t 0 && -t 1 ]] && { : </dev/tty; } 2>/dev/null; then
        exec </dev/tty
    fi
    exec "$dot" install "${forward[@]}"
}

main "$@"
