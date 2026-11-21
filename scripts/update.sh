#!/usr/bin/env bash
# `dot update`: System, mise-Tools, Flatpaks und zsh-Plugins aktualisieren.
# Setzt common.sh, detect.sh und pkg.sh voraus (von dot geladen).

update_usage() {
    cat <<'USAGE'
dot update [--dry-run] [--profile desktop|headless]
  Aktualisiert Systempakete (inkl. AUR auf Arch), mise-Tools, installierte Agenten
  (Claude Code, pi, Ollama), Flatpaks (nur desktop) und installierte zsh-Plugins.
--dry-run    Zeigt Schritte ohne Schreibzugriffe oder sudo.
--profile    Wählt desktop oder headless. Standard ist die automatische Erkennung.
--help       Zeigt diese Hilfe.
USAGE
}

_update_mise_versions() { mise ls --current --no-header 2>/dev/null | awk '{print $1, $2}' | sort; }

_update_mise() {
    if ! have mise; then
        log 'mise fehlt: Tool-Update übersprungen.'
        return 0
    fi
    if ((DRY_RUN)); then
        run mise upgrade --yes
        return 0
    fi
    local before after
    before=$(_update_mise_versions)
    run mise upgrade --yes || return $?
    after=$(_update_mise_versions)
    if [[ $before == "$after" ]]; then
        printf 'mise: keine Versionsänderungen.\n'
    else
        printf 'mise: Versionsänderungen (alt -> neu):\n'
        diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | sed -n 's/^[<>] /  &/p' || true
    fi
}

# Claude Code, pi and upstream-installed Ollama (Arch packages come with the system upgrade).
_update_agents() {
    local pi_before=$1 rc=0
    if have claude; then run claude update || rc=$?; fi
    if ((pi_before)) || have pi; then
        run mise exec -- npm install -g @earendil-works/pi-coding-agent@latest || rc=$?
        run mise reshim || rc=$?
    fi
    if have ollama && [[ $DISTRO_FAMILY != arch ]]; then
        upstream_installer ollama https://ollama.com/install.sh sh || rc=$?
        if [[ -n ${WORK_DIR:-} ]]; then rm -rf -- "$WORK_DIR"; WORK_DIR=''; fi
    fi
    return "$rc"
}

_update_zsh_plugins() {
    local dir rc=0 root=${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins
    [[ -d $root ]] || return 0
    for dir in "$root"/*/; do
        [[ -d ${dir}.git ]] || continue
        run git -C "${dir%/}" pull --ff-only || rc=$?
    done
    return "$rc"
}

dot_update() {
    DRY_RUN=0
    local profile=''
    while (($#)); do
        case "$1" in
            --dry-run) DRY_RUN=1 ;;
            --profile)
                (($# >= 2)) || die "Wert für $1 fehlt."
                case "$2" in
                    desktop|headless) profile=$2 ;;
                    *) die "Ungültiges Profil: $2 (erwartet: desktop oder headless)." ;;
                esac
                shift ;;
            -h|--help) update_usage; return 0 ;;
            *) die "Unbekannte Option: $1" ;;
        esac
        shift
    done
    DISTRO_FAMILY=$(detect_family) || die 'Distro nicht erkennbar.'
    [[ -n $profile ]] || profile=$(detect_profile)
    PATH="$HOME/.local/bin:${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims:$PATH"
    if ((!DRY_RUN)); then
        ((EUID != 0)) || die 'Bitte ohne sudo starten; Paketverwaltungsschritte verwenden sudo.'
        need sudo
        pkg_need
    fi

    log "Update: System ($DISTRO_FAMILY)"
    pkg_upgrade || return $?
    pkg_upgrade_aur || return $?

    log 'Update: mise-Tools'
    local pi_before=0
    if have pi; then pi_before=1; fi
    _update_mise || return $?

    log 'Update: Agenten'
    _update_agents "$pi_before" || return $?

    if [[ $profile == desktop ]] && have flatpak; then
        log 'Update: Flatpaks (user)'
        run flatpak update --user --noninteractive -y || return $?
    fi

    log 'Update: zsh-Plugins'
    _update_zsh_plugins || return $?

    log 'Neovim-Plugins werden nicht automatisch aktualisiert: in nvim :lua vim.pack.update() ausführen und nvim-pack-lock.json prüfen/committen.'
    if ((DRY_RUN)); then log 'Vorschau abgeschlossen; keine Änderungen vorgenommen.'; fi
}
