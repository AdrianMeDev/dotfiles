#!/usr/bin/env bash
# `dot zed-template`: Zed-Projektvorlage (.zed/*.json) in ein Projekt kopieren.
# Setzt common.sh voraus und REPO_DIR (von dot geladen).

zed_template_usage() {
    cat <<'USAGE'
dot zed-template [--dry-run] [--backup] angular|django|dotnet <PFAD>
  Kopiert zed-config/projects/<Vorlage>/.zed/*.json nach <PFAD>/.zed/.
  Identische Dateien bleiben unverändert; abweichende Dateien brechen ab (nichts wird geschrieben),
  außer mit --backup (Sicherung als <Datei>.bak-<Zeitstempel>). Symlinks als Ziel werden abgelehnt.
--dry-run    Zeigt Schritte ohne Schreibzugriffe.
--backup     Sichert abweichende Zieldateien, bevor sie ersetzt werden.
--help       Zeigt diese Hilfe.
USAGE
}

dot_zed_template() {
    DRY_RUN=0
    local backup=0 template='' dest='' arg
    while (($#)); do
        arg=$1
        case "$arg" in
            --dry-run) DRY_RUN=1 ;;
            --backup) backup=1 ;;
            -h|--help) zed_template_usage; return 0 ;;
            -*) die "Unbekannte Option: $arg" ;;
            *)
                if [[ -z $template ]]; then template=$arg
                elif [[ -z $dest ]]; then dest=$arg
                else die "Unerwartetes Argument: $arg"
                fi ;;
        esac
        shift
    done
    case "$template" in
        angular|django|dotnet) ;;
        '') die 'Vorlage fehlt (angular, django oder dotnet).' ;;
        *) die "Unbekannte Vorlage: $template (erwartet: angular, django oder dotnet)." ;;
    esac
    [[ -n $dest ]] || die 'Zielpfad fehlt.'

    local src="$REPO_DIR/zed-config/projects/$template/.zed" target="$dest/.zed"
    [[ -d $src ]] || die "Vorlage nicht gefunden: $src"
    if [[ -e $dest && ! -d $dest ]]; then die "Zielpfad ist kein Verzeichnis: $dest"; fi
    if [[ -L $target ]]; then die "Ziel ist ein Symlink: $target"; fi
    if [[ -e $target && ! -d $target ]]; then die "Ziel ist kein Verzeichnis: $target"; fi

    # Pass 1: check every target before writing anything.
    local file name out
    local -a todo=() differing=()
    for file in "$src"/*.json; do
        name=${file##*/}
        out="$target/$name"
        if [[ -L $out ]]; then die "Zieldatei ist ein Symlink: $out"; fi
        if [[ ! -e $out ]]; then
            todo+=("$name")
        elif [[ ! -f $out ]]; then
            die "Zieldatei ist keine reguläre Datei: $out"
        elif ! cmp -s "$file" "$out"; then
            todo+=("$name")
            differing+=("$name")
        fi
    done
    if ((${#differing[@]} && !backup)); then
        printf 'Fehler: Abweichende Dateien in %s: %s\n' "$target" "${differing[*]}" >&2
        printf 'Nichts geschrieben. Mit --backup werden sie gesichert und ersetzt.\n' >&2
        return 1
    fi
    if ((!${#todo[@]})); then
        printf 'Zed-Vorlage %s: %s ist bereits aktuell.\n' "$template" "$target"
        return 0
    fi

    # Pass 2: write.
    log "Zed-Vorlage $template -> $target"
    run mkdir -p "$target" || return $?
    local stamp bak n
    stamp=$(date +%Y%m%d%H%M%S)
    for name in "${todo[@]}"; do
        out="$target/$name"
        if [[ -e $out ]]; then
            bak="$out.bak-$stamp"
            n=0
            while [[ -e $bak ]]; do n=$((n + 1)); bak="$out.bak-$stamp-$n"; done
            run mv -- "$out" "$bak" || return $?
        fi
        run cp -- "$src/$name" "$out" || return $?
    done
    if ((DRY_RUN)); then printf '\nVorschau abgeschlossen.\n'; fi
}
