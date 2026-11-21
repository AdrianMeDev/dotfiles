#!/usr/bin/env bash
# Idempotent root bootstrap for a fresh Arch WSL2 instance (`wsl --install archlinux`).
# Creates the regular user, sudo, zsh and a Linux-side dotfiles clone so install.sh can run.
# Run as root inside the instance. Safe to repeat; managed files that differ are only
# replaced with --backup (the old file is kept as <file>.bak.<timestamp>).
set -euo pipefail

SHELL_PATH=/usr/bin/zsh
PACKAGES=(sudo git python zsh)
SUDOERS_LINE='%wheel ALL=(ALL:ALL) NOPASSWD: ALL'

USER_NAME=
REPO=
ORIGIN=
DRY_RUN=0
BACKUP=0
SYSROOT=

die() { printf 'Fehler: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }
usage() {
    cat <<'EOF'
Usage: wsl-bootstrap.sh --user NAME --repo SOURCE [--origin URL] [--dry-run] [--backup]

  --user NAME    Linux user to create/update (group wheel, login shell /usr/bin/zsh)
  --repo SOURCE  Git repository (URL or path, e.g. /mnt/c/...) to clone into NAME's home as dotfiles
  --origin URL   URL the clone's "origin" remote must have (default: origin of SOURCE)
  --dry-run      Print the actions, change nothing
  --backup       Replace differing /etc/sudoers.d/10-wheel and /etc/wsl.conf default after backing them up
  --sysroot DIR  Prefix for managed paths (offline tests only)
EOF
}

while (($#)); do
    case $1 in
        --user | --repo | --origin | --sysroot)
            (($# >= 2)) || die "$1 braucht einen Wert."
            case $1 in
                --user) USER_NAME=$2 ;;
                --repo) REPO=$2 ;;
                --origin) ORIGIN=$2 ;;
                --sysroot) SYSROOT=${2%/} ;;
            esac
            shift 2
            ;;
        --dry-run) DRY_RUN=1; shift ;;
        --backup) BACKUP=1; shift ;;
        -h | --help) usage; exit 0 ;;
        *) usage >&2; die "Unbekannte Option: $1" ;;
    esac
done

[[ -n $USER_NAME ]] || die "--user fehlt."
[[ -n $REPO ]] || die "--repo fehlt."
[[ $USER_NAME =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || die "Ungültiger Benutzername: $USER_NAME"
[[ $USER_NAME != root ]] || die "--user darf nicht root sein."
if [[ -z $SYSROOT ]] && ((EUID != 0)); then die "Als root ausführen."; fi

STAMP=$(date +%Y%m%d%H%M%S)
SUDOERS_FILE=$SYSROOT/etc/sudoers.d/10-wheel
WSL_CONF=$SYSROOT/etc/wsl.conf
DEST=$SYSROOT/home/$USER_NAME/dotfiles

run() {
    printf '  +'; printf ' %q' "$@"; printf '\n'
    if ((!DRY_RUN)); then "$@"; fi
}

# write_managed TARGET MODE CONTENT VALIDATOR NEEDS_BACKUP
# MODE/VALIDATOR may be empty (keep existing mode or 644 / no validation).
write_managed() {
    local target=$1 mode=$2 content=$3 validator=$4 needs_backup=$5 tmp
    if [[ -e $target ]]; then
        if [[ $(<"$target") == "$content" ]]; then
            if [[ -n $mode && $(stat -c %a -- "$target") != "$mode" ]]; then run chmod "$mode" "$target"; fi
            info "ok: $target"
            return
        fi
        if ((needs_backup)); then
            ((BACKUP)) || die "$target weicht ab; mit --backup sichern und ersetzen."
            run cp -p -- "$target" "$target.bak.$STAMP"
        fi
        [[ -n $mode ]] || mode=$(stat -c %a -- "$target")
    fi
    [[ -n $mode ]] || mode=644
    if ((DRY_RUN)); then
        info "  + write $target (mode $mode)"
        return
    fi
    mkdir -p -- "$(dirname -- "$target")"
    tmp=$(mktemp -- "$target.tmp.XXXXXX")
    printf '%s\n' "$content" >"$tmp"
    chmod "$mode" -- "$tmp"
    if [[ -n $validator ]] && ! "$validator" "$tmp"; then
        rm -f -- "$tmp"
        die "Validierung fehlgeschlagen für $target."
    fi
    mv -f -- "$tmp" "$target"
    info "geschrieben: $target"
}

validate_sudoers() { visudo -cf "$1" >/dev/null; }

# Prints the value of default= in the [user] section (empty if none).
wsl_conf_default() {
    awk '
        /^[[:space:]]*\[/ { sec = ($0 ~ /^[[:space:]]*\[user\][[:space:]]*$/) }
        sec && /^[[:space:]]*default[[:space:]]*=/ { sub(/^[^=]*=[[:space:]]*/, ""); sub(/[[:space:]]+$/, ""); v = $0 }
        END { print v }
    ' "$1"
}

# render_wsl_conf FILE USER HAS_DEFAULT: FILE with [user] default=USER merged in.
render_wsl_conf() {
    awk -v user="$2" -v has="$3" '
        /^[[:space:]]*\[/ {
            insec = ($0 ~ /^[[:space:]]*\[user\][[:space:]]*$/)
            print
            if (insec && !has && !done) { print "default=" user; done = 1 }
            next
        }
        insec && has && /^[[:space:]]*default[[:space:]]*=/ {
            if (!done) { print "default=" user; done = 1 }
            next
        }
        { print }
        END { if (!done) { if (NR > 0) print ""; print "[user]"; print "default=" user } }
    ' "$1"
}

step_keyring() {
    info "== pacman keyring"
    if [[ -e $SYSROOT/etc/pacman.d/gnupg/trustdb.gpg ]]; then
        info "ok: keyring vorhanden"
        return
    fi
    run pacman-key --init
    run pacman-key --populate archlinux
}

step_packages() {
    info "== Pakete: ${PACKAGES[*]}"
    local missing=() pkg
    for pkg in "${PACKAGES[@]}"; do
        pacman -Q "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
    done
    if ((${#missing[@]} == 0)); then
        info "ok: alle installiert"
        return
    fi
    run pacman -Syu --noconfirm --needed "${missing[@]}"
}

step_user() {
    info "== Benutzer $USER_NAME"
    local entry args=()
    entry=$(getent passwd "$USER_NAME" || true)
    if [[ -z $entry ]]; then
        run useradd --create-home --groups wheel --shell "$SHELL_PATH" "$USER_NAME"
        return
    fi
    [[ ${entry##*:} == "$SHELL_PATH" ]] || args+=(--shell "$SHELL_PATH")
    [[ " $(id -nG "$USER_NAME") " == *" wheel "* ]] || args+=(--append --groups wheel)
    if ((${#args[@]})); then
        run usermod "${args[@]}" "$USER_NAME"
    else
        info "ok: Benutzer vorhanden (wheel, zsh)"
    fi
}

step_sudoers() {
    info "== sudoers"
    write_managed "$SUDOERS_FILE" 440 "$SUDOERS_LINE" validate_sudoers 1
}

step_wsl_conf() {
    info "== wsl.conf"
    local source=/dev/null current=
    if [[ -e $WSL_CONF ]]; then source=$WSL_CONF; current=$(wsl_conf_default "$WSL_CONF"); fi
    if [[ $current == "$USER_NAME" ]]; then
        info "ok: $WSL_CONF default=$USER_NAME"
        return
    fi
    local has=0 needs_backup=0
    if [[ -n $current ]]; then has=1; needs_backup=1; fi
    write_managed "$WSL_CONF" "" "$(render_wsl_conf "$source" "$USER_NAME" "$has")" "" "$needs_backup"
}

step_clone() {
    info "== Dotfiles-Clone $DEST"
    local origin=$ORIGIN current
    local -a as_user=(runuser -u "$USER_NAME" --)
    local -a git_cmd=(git -c 'safe.directory=*')
    if [[ -z $origin ]]; then
        origin=$("${git_cmd[@]}" -C "$REPO" remote get-url origin 2>/dev/null || true)
    fi
    if [[ -e $DEST/.git ]]; then
        current=$("${as_user[@]}" "${git_cmd[@]}" -C "$DEST" remote get-url origin 2>/dev/null || true)
        info "ok: Clone vorhanden (origin: ${current:-keiner})"
        if [[ -n $origin && $current != "$origin" ]]; then
            info "Warnung: origin ist nicht $origin; unverändert gelassen." >&2
        fi
        return
    fi
    if [[ -e $DEST ]] && [[ -n $(ls -A -- "$DEST") ]]; then
        die "$DEST existiert und ist kein Git-Clone."
    fi
    run "${as_user[@]}" "${git_cmd[@]}" clone -- "$REPO" "$DEST"
    if [[ -n $origin && $origin != "$REPO" ]]; then
        run "${as_user[@]}" "${git_cmd[@]}" -C "$DEST" remote set-url origin "$origin"
    fi
}

((DRY_RUN)) && info "DRY RUN: es wird nichts geändert."
step_keyring
step_packages
step_user
step_sudoers
step_wsl_conf
step_clone
info "Fertig. Danach: wsl --terminate <Distro>, dann install.sh aus $DEST ausführen."
