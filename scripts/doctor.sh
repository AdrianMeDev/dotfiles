#!/usr/bin/env bash
# `dot doctor`: read-only environment diagnostics.
# Setzt common.sh und detect.sh voraus (von dot geladen); REPO_DIR muss gesetzt sein.

_doc_errors=0
_doc_ok() { printf '[OK]      %s\n' "$*"; }
_doc_warn() { printf '[WARN]    %s\n' "$*"; }
_doc_err() { printf '[FEHLER]  %s\n' "$*"; _doc_errors=$((_doc_errors + 1)); }

# Core tools as "label:binary[|alternative]". Missing ones are errors, except optional ones.
_DOC_TOOLS=(mise nvim node uv starship tree-sitter lazygit rg 'fd:fd|fdfind' fzf 'bat:bat|batcat'
    delta shfmt shellcheck eza yazi tealdeer:tldr just lazydocker zsh tmux git stow podman claude pi ollama)
_DOC_OPTIONAL=' podman ollama '

_doc_version() {
    local bin=$1 out
    case "$bin" in
        tmux) out=$("$bin" -V 2>&1 || true) ;;
        shellcheck) out=$("$bin" --version 2>&1 | sed -n 's/^version: //p' || true) ;;
        *) out=$("$bin" --version 2>&1 || true) ;;
    esac
    printf '%s\n' "$out" | head -n 1
}

_doc_tools() {
    local entry label alts bin found cands version ver lowest
    for entry in "${_DOC_TOOLS[@]}"; do
        label=${entry%%:*}
        alts=${entry#*:}
        found=''
        IFS='|' read -ra cands <<< "$alts"
        for bin in "${cands[@]}"; do
            if have "$bin"; then found=$bin; break; fi
        done
        if [[ -z $found ]]; then
            if [[ $_DOC_OPTIONAL == *" $label "* ]]; then
                _doc_warn "$label fehlt (optional)."
            else
                _doc_err "$label fehlt."
            fi
            continue
        fi
        version=$(_doc_version "$found")
        if [[ $label == nvim ]]; then
            ver=$(printf '%s\n' "$version" | sed -n 's/^NVIM v\([0-9][0-9.]*\).*/\1/p')
            lowest=$(printf '%s\n0.12\n' "${ver:-0}" | sort -V | head -n 1)
            if [[ $lowest != 0.12 ]]; then
                _doc_err "nvim ${ver:-unbekannt} ist zu alt (benötigt >= 0.12)."
                continue
            fi
        fi
        _doc_ok "$label: ${version:-Version unbekannt}"
    done
}

_doc_git_identity() {
    # shellcheck disable=SC2088  # literal tilde for display
    local file=$HOME/.gitconfig-local name email mode label="~/.gitconfig-local"
    if [[ ! -f $file ]]; then
        _doc_warn 'Git-Identität: ~/.gitconfig-local fehlt.'
        return
    fi
    name=$(git config --file "$file" user.name 2>/dev/null || true)
    email=$(git config --file "$file" user.email 2>/dev/null || true)
    if [[ -n $name && -n $email ]]; then
        _doc_ok 'Git-Identität: user.name und user.email gesetzt.'
    else
        _doc_warn 'Git-Identität: user.name oder user.email in ~/.gitconfig-local nicht gesetzt.'
    fi
    mode=$(stat -c %a "$file" 2>/dev/null || true)
    if [[ $mode == 600 ]]; then
        _doc_ok "$label: Rechte 600."
    else
        _doc_warn "$label: Rechte ${mode:-unbekannt}, erwartet 600."
    fi
}

_doc_fnm() {
    local data=${XDG_DATA_HOME:-$HOME/.local/share}
    if have fnm || [[ -d $data/fnm || -d $HOME/.fnm ]]; then
        _doc_warn 'Legacy fnm gefunden; Node wird über mise verwaltet (fnm entfernen).'
    else
        _doc_ok 'Kein fnm-Überrest.'
    fi
}

_doc_agents() {
    local out line bad=() mod=() rc=0
    out=$(python3 "$REPO_DIR/scripts/agents.py" --status 2>&1) || rc=$?
    if ((rc)); then
        _doc_err 'Agent-Config: Prüfung fehlgeschlagen:'
        printf '%s\n' "$out" | sed 's/^/            /'
        return
    fi
    while IFS= read -r line; do
        case $line in
            '[missing]'*) bad+=("$line") ;;
            '[modified]'*|'[legacy]'*) mod+=("$line") ;;
        esac
    done <<< "$out"
    if ((${#bad[@]})); then
        _doc_err 'Agent-Config: Dateien fehlen (dot install --only agents ausführen):'
        printf '            %s\n' "${bad[@]}"
    fi
    if ((${#mod[@]})); then
        _doc_warn 'Agent-Config: lokal abweichende Dateien:'
        printf '            %s\n' "${mod[@]}"
    fi
    if ((!${#bad[@]} && !${#mod[@]})); then _doc_ok 'Agent-Config: stimmt mit dem Repo überein.'; fi
}

# Hyprland stack (binary names of manifest group hypr); missing ones are warnings only.
_DOC_DESKTOP_TOOLS=(hyprland waybar fuzzel mako hyprlock hypridle hyprpaper cliphist grim slurp wpctl brightnessctl playerctl)
_DOC_HYPRLAND_MIN=0.57

_doc_desktop() {
    local profile=$1 family=$2 bin version ver missing=() lua=$HOME/.config/hypr/hyprland.lua out
    if ! have hyprland && [[ $profile != desktop || $family == debian ]]; then return 0; fi
    for bin in "${_DOC_DESKTOP_TOOLS[@]}"; do
        have "$bin" || missing+=("$bin")
    done
    if ((${#missing[@]})); then
        _doc_warn "Desktop-Tools fehlen: ${missing[*]} (dot install --only desktop --profile desktop)."
    else
        _doc_ok 'Desktop-Tools: Hyprland-Stack vollständig.'
    fi

    if have waybar; then
        version=$(waybar --version 2>&1 | head -n 1) || true
        _doc_ok "waybar: ${version:-Version unbekannt}"
    fi
    have hyprland || return 0
    version=$(hyprland --version 2>&1 | head -n 1) || true
    ver=$(printf '%s\n' "$version" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1) || true
    _doc_ok "hyprland: ${version:-Version unbekannt}"
    if [[ -n $ver && $(printf '%s\n%s\n' "$_DOC_HYPRLAND_MIN" "$ver" | sort -V | head -n 1) != "$_DOC_HYPRLAND_MIN" ]]; then
        _doc_warn "Hyprland $ver ist älter als $_DOC_HYPRLAND_MIN; die Lua-Konfiguration benötigt mindestens $_DOC_HYPRLAND_MIN."
    fi
    if [[ -e $HOME/.config/hypr/hyprland.conf ]]; then
        # shellcheck disable=SC2088  # literal tilde for display
        _doc_warn '~/.config/hypr/hyprland.conf ist ein Überrest; Hyprland >= 0.57 lädt nur hyprland.lua.'
    fi
    [[ -f $lua ]] || return 0
    if hyprland --help 2>&1 | grep -q -- '--verify-config'; then
        if out=$(hyprland --verify-config --config "$lua" 2>&1); then
            _doc_ok 'Hyprland-Konfiguration: hyprland --verify-config ohne Fehler.'
        else
            _doc_err 'Hyprland-Konfiguration: hyprland --verify-config meldet Fehler:'
            printf '%s\n' "$out" | sed 's/^/            /'
        fi
    elif [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && have hyprctl; then
        out=$(hyprctl configerrors 2>&1) || true
        if [[ -z $out || $out == *'no errors'* ]]; then
            _doc_ok 'Hyprland-Konfiguration: hyprctl configerrors ohne Fehler.'
        else
            _doc_err 'Hyprland-Konfiguration: hyprctl configerrors meldet Fehler:'
            printf '%s\n' "$out" | sed 's/^/            /'
        fi
    fi
}

_doc_corne() {
    local profile=$1 target
    if [[ $profile != desktop ]] || is_wsl; then return 0; fi
    # shellcheck source=scripts/corne.sh
    source "$REPO_DIR/scripts/corne.sh"
    if have vial; then _doc_ok 'Vial vorhanden.'; else _doc_warn 'Vial fehlt (dot install --only corne).'; fi
    target=$(corne_udev_path)
    if [[ ! -f $target ]]; then
        _doc_warn "Vial-udev-Regel fehlt: $target (dot install --only corne)."
    elif [[ $(< "$target") == "$(corne_udev_rule)" ]]; then
        _doc_ok "Vial-udev-Regel: $target"
    else
        _doc_warn "Vial-udev-Regel weicht ab: $target (dot install --only corne --backup)."
    fi
}

dot_doctor() {
    (($# == 0)) || { case "$1" in
        -h|--help) printf 'dot doctor\n  Read-only Diagnose: Umgebung, Tool-Versionen, mise, Stow-Links, Agent-Config, Git-Identität, fnm.\n'; return 0 ;;
        *) die "Unbekannte Option: $1" ;;
    esac; }
    _doc_errors=0
    local family profile out
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) _doc_ok 'PATH enthält ~/.local/bin.' ;;
        *) _doc_warn 'PATH enthält ~/.local/bin nicht.' ;;
    esac
    PATH="$HOME/.local/bin:${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims:$PATH"

    if family=$(detect_family 2>&1); then
        profile=$(detect_profile)
        _doc_ok "Distro: $family, Profil: $profile, WSL: $(is_wsl && echo ja || echo nein)"
    else
        _doc_err "Umgebung: $family"
    fi

    _doc_tools

    if have mise; then
        out=$(mise ls --missing --no-header 2>&1) || true
        if [[ -n $out ]]; then
            _doc_err "Fehlende mise-Tools (mise install ausführen):"
            printf '%s\n' "$out" | sed 's/^/            /'
        else
            _doc_ok 'Alle mise-Tools installiert.'
        fi
    fi

    if out=$(python3 "$REPO_DIR/scripts/links.py" --check 2>&1); then
        _doc_ok 'Stow-Links: keine Konflikte.'
    else
        _doc_err 'Stow-Links: Konflikte:'
        printf '%s\n' "$out" | sed 's/^/            /'
    fi

    _doc_desktop "${profile:-}" "${family:-}"
    _doc_corne "${profile:-}"
    _doc_agents
    _doc_git_identity
    _doc_fnm

    if ((_doc_errors)); then
        printf '\n%d Fehler gefunden.\n' "$_doc_errors"
        return 1
    fi
    printf '\nKeine Fehler.\n'
}
